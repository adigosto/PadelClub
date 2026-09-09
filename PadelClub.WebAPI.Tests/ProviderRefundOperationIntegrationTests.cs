using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Payments;
using PadelClub.WebAPI.Tests.Infrastructure;
using Xunit;

namespace PadelClub.WebAPI.Tests;

[Collection(SqlServerIntegrationCollection.Name)]
public sealed class ProviderRefundOperationIntegrationTests(SqlServerIntegrationFixture fixture)
{
    private readonly SqlServerIntegrationFixture _fixture = fixture;

    [Fact]
    public async Task Admin_refund_is_queued_once_and_receives_a_recoverable_sql_lease()
    {
        var paymentId = await AddCompletedStripePaymentAsync();
        using var client = _fixture.Api.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            _fixture.AdminSession.AccessToken);
        var request = new StripeRefundRequest
        {
            Amount = 12.50m,
            Reason = "Integration durable refund",
            IdempotencyKey = "integration-refund-001"
        };

        var queuedResponse = await client.PostAsJsonAsync($"/StripePayments/{paymentId}/refund", request);
        Assert.Equal(HttpStatusCode.Accepted, queuedResponse.StatusCode);
        var queued = await queuedResponse.Content.ReadFromJsonAsync<ProviderRefundOperationResponse>();
        Assert.NotNull(queued);
        Assert.Equal(paymentId, queued.PaymentId);
        Assert.Equal(12.50m, queued.Amount);
        Assert.Equal("Pending", queued.Status);
        Assert.Null(queued.ProviderRefundId);

        var retryResponse = await client.PostAsJsonAsync($"/StripePayments/{paymentId}/refund", request);
        Assert.Equal(HttpStatusCode.Accepted, retryResponse.StatusCode);
        var retry = await retryResponse.Content.ReadFromJsonAsync<ProviderRefundOperationResponse>();
        Assert.NotNull(retry);
        Assert.Equal(queued.Id, retry.Id);

        await using (var claimScope = _fixture.Api.Services.CreateAsyncScope())
        {
            var leases = claimScope.ServiceProvider.GetRequiredService<IProviderRefundOperationLeaseService>();
            var lease = await leases.ClaimDueAsync(10, TimeSpan.FromMinutes(1));
            var claimed = Assert.Single(lease.Operations, operation => operation.Id == queued.Id);
            Assert.True(await leases.RenewLeaseAsync(claimed.Id, lease.LeaseId, TimeSpan.FromMinutes(1)));
            Assert.True(await leases.RecordFailureAsync(
                claimed.Id,
                lease.LeaseId,
                DateTime.UtcNow.AddMinutes(1),
                "integration temporary provider outage"));
        }

        await using var verificationScope = _fixture.Api.Services.CreateAsyncScope();
        var database = verificationScope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var operation = await database.ProviderRefundOperations.SingleAsync(candidate => candidate.Id == queued.Id);
        Assert.Equal(1, operation.AttemptCount);
        Assert.Null(operation.LeaseId);
        Assert.Null(operation.LeaseExpiresAtUtc);
        Assert.Equal("integration temporary provider outage", operation.LastError);
        Assert.Equal(12.50m, operation.ExpectedRefundedAmount);
        Assert.Equal(1, await database.ProviderRefundOperations.CountAsync(candidate => candidate.PaymentId == paymentId));
    }

    [Fact]
    public async Task Stripe_return_approval_commits_refund_pending_before_provider_io_or_restock()
    {
        PendingReturnScenario scenario = null!;
        await using (var setupScope = _fixture.Api.Services.CreateAsyncScope())
        {
            var database = setupScope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var product = await database.Products.SingleAsync(product => product.Id == _fixture.Api.Seed.OwnedProductId);
            var order = new Order
            {
                UserId = _fixture.Api.Seed.PlayerUserId,
                OrderNumber = "IT-RETURN-PENDING-" + Guid.NewGuid().ToString("N")[..10],
                Status = "Delivered",
                RecipientName = "Integration Player",
                PhoneNumber = "+38760000000",
                ShippingAddress = "Integration Street 1",
                City = "Sarajevo",
                PostalCode = "71000",
                TotalAmount = 20m,
                SubtotalAmount = 20m,
                DeliveredAt = DateTime.UtcNow.AddDays(-1)
            };
            var item = new OrderItem
            {
                Order = order,
                ProductId = product.Id,
                Quantity = 1,
                UnitPrice = 20m,
                TotalPrice = 20m
            };
            order.OrderItems.Add(item);
            var payment = new Payment
            {
                UserId = _fixture.Api.Seed.PlayerUserId,
                Order = order,
                PaymentType = "Product",
                Amount = 20m,
                PaymentMethod = "Stripe",
                Provider = "Stripe",
                Currency = "bam",
                TransactionId = "pi_return_pending_" + Guid.NewGuid().ToString("N"),
                Status = "Completed"
            };
            order.Payment = payment;
            var returnRequest = new ReturnRequest
            {
                Order = order,
                UserId = _fixture.Api.Seed.PlayerUserId,
                Reason = "Integration durable return approval",
                Status = "Requested",
                RefundAmount = 20m,
                Items = [new ReturnRequestItem { OrderItem = item, Quantity = 1, RefundAmount = 20m }]
            };
            database.AddRange(order, payment, returnRequest);
            await database.SaveChangesAsync();
            scenario = new PendingReturnScenario(returnRequest.Id, product.Id, product.StockQuantity);
        }

        using var client = _fixture.Api.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            _fixture.AdminSession.AccessToken);
        var response = await client.PutAsJsonAsync(
            $"/Commerce/returns/{scenario.ReturnRequestId}/resolve",
            new { approve = true, adminNotes = "Queue durable provider refund." });
        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);

        await using var verificationScope = _fixture.Api.Services.CreateAsyncScope();
        var verificationDatabase = verificationScope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var persistedReturn = await verificationDatabase.ReturnRequests
            .Include(candidate => candidate.Items)
            .SingleAsync(candidate => candidate.Id == scenario.ReturnRequestId);
        var operation = await verificationDatabase.ProviderRefundOperations
            .SingleAsync(candidate => candidate.ReturnRequestId == scenario.ReturnRequestId);
        var productAfterQueue = await verificationDatabase.Products
            .SingleAsync(candidate => candidate.Id == scenario.ProductId);
        var movements = await verificationDatabase.InventoryMovements
            .Where(candidate => candidate.ReferenceType == "Return" && candidate.ReferenceId == scenario.ReturnRequestId)
            .ToListAsync();
        Assert.Equal("RefundPending", persistedReturn.Status);
        Assert.Null(persistedReturn.ResolvedAt);
        Assert.False(persistedReturn.Items.Single().Restocked);
        Assert.Equal(scenario.StartingStock, productAfterQueue.StockQuantity);
        Assert.Empty(movements);
        Assert.Equal("Pending", operation.Status);
        Assert.Equal(20m, operation.ExpectedRefundedAmount);
    }

    [Fact]
    public async Task Sql_settlement_reconciles_provider_acceptance_before_restocking_the_return()
    {
        await using var scope = _fixture.Api.Services.CreateAsyncScope();
        var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var product = await database.Products.SingleAsync(product => product.Id == _fixture.Api.Seed.OwnedProductId);
        var originalStock = product.StockQuantity;
        var order = new Order
        {
            UserId = _fixture.Api.Seed.PlayerUserId,
            OrderNumber = "IT-REFUND-" + Guid.NewGuid().ToString("N")[..10],
            Status = "Delivered",
            RecipientName = "Integration Player",
            PhoneNumber = "+38760000000",
            ShippingAddress = "Integration Street 1",
            City = "Sarajevo",
            PostalCode = "71000",
            TotalAmount = 20m,
            SubtotalAmount = 20m,
            DeliveredAt = DateTime.UtcNow.AddDays(-1)
        };
        var item = new OrderItem
        {
            Order = order,
            ProductId = product.Id,
            Quantity = 1,
            UnitPrice = 20m,
            TotalPrice = 20m
        };
        order.OrderItems.Add(item);
        var payment = new Payment
        {
            UserId = _fixture.Api.Seed.PlayerUserId,
            Order = order,
            PaymentType = "Product",
            Amount = 20m,
            PaymentMethod = "Stripe",
            Provider = "Stripe",
            Currency = "bam",
            TransactionId = "pi_settlement_" + Guid.NewGuid().ToString("N"),
            Status = "Completed"
        };
        order.Payment = payment;
        var returnRequest = new ReturnRequest
        {
            Order = order,
            UserId = _fixture.Api.Seed.PlayerUserId,
            Reason = "Integration settlement return",
            Status = "RefundPending",
            RefundAmount = 20m,
            Items = [new ReturnRequestItem { OrderItem = item, Quantity = 1, RefundAmount = 20m }]
        };
        database.AddRange(order, payment, returnRequest);
        await database.SaveChangesAsync();

        var leaseId = Guid.NewGuid();
        var operation = new ProviderRefundOperation
        {
            PaymentId = payment.Id,
            ReturnRequestId = returnRequest.Id,
            RequestedByUserId = _fixture.Api.Seed.AdminUserId,
            Provider = "Stripe",
            Currency = "bam",
            PaymentIntentId = payment.TransactionId!,
            Amount = 20m,
            ExpectedRefundedAmount = 20m,
            Reason = "Integration return refund",
            IdempotencyKey = "return-refund-v1:" + returnRequest.Id,
            Status = ProviderRefundOperationStatuses.Pending,
            LeaseId = leaseId,
            LeaseExpiresAtUtc = DateTime.UtcNow.AddMinutes(1),
            NextAttemptAtUtc = DateTime.UtcNow
        };
        database.ProviderRefundOperations.Add(operation);
        await database.SaveChangesAsync();

        var processor = new ProviderRefundOperationProcessor(
            database,
            new SuccessfulGateway("re_sql_settlement", 20m),
            notifications: null,
            NullLogger<ProviderRefundOperationProcessor>.Instance);
        var result = await processor.ProcessAsync(operation, leaseId, CancellationToken.None);

        Assert.True(result.Settled);
        database.ChangeTracker.Clear();
        var persisted = await database.ProviderRefundOperations.SingleAsync(candidate => candidate.Id == operation.Id);
        var settledPayment = await database.Payments.SingleAsync(candidate => candidate.Id == payment.Id);
        var settledReturn = await database.ReturnRequests
            .Include(candidate => candidate.Items)
            .SingleAsync(candidate => candidate.Id == returnRequest.Id);
        var settledProduct = await database.Products.SingleAsync(candidate => candidate.Id == product.Id);
        Assert.Equal("Succeeded", persisted.Status);
        Assert.Equal("re_sql_settlement", persisted.ProviderRefundId);
        Assert.Equal("Refunded", settledPayment.Status);
        Assert.Equal(20m, settledPayment.RefundedAmount);
        Assert.Equal("Refunded", settledReturn.Status);
        Assert.True(settledReturn.Items.Single().Restocked);
        Assert.Equal(originalStock + 1, settledProduct.StockQuantity);
    }

    private async Task<int> AddCompletedStripePaymentAsync()
    {
        await using var scope = _fixture.Api.Services.CreateAsyncScope();
        var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var payment = new Payment
        {
            UserId = _fixture.Api.Seed.PlayerUserId,
            PaymentType = "Product",
            Amount = 50m,
            PaymentMethod = "Stripe",
            Provider = "Stripe",
            Currency = "bam",
            TransactionId = "pi_integration_" + Guid.NewGuid().ToString("N"),
            Status = "Completed"
        };
        database.Payments.Add(payment);
        await database.SaveChangesAsync();
        return payment.Id;
    }

    private sealed class SuccessfulGateway(string refundId, decimal amount) : IStripeRefundGateway
    {
        public Task<StripeRefundGatewayResult> CreateOrReconcileAsync(
            ProviderRefundOperation operation,
            CancellationToken cancellationToken) =>
            Task.FromResult(new StripeRefundGatewayResult(refundId, amount, DateTime.UtcNow));
    }

    private sealed record PendingReturnScenario(int ReturnRequestId, int ProductId, int StartingStock);
}
