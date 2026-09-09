using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using PadelClub.Model.Requests;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Payments;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public sealed class ProviderRefundOperationTests
{
    [Fact]
    public async Task Direct_refund_is_durable_idempotent_and_reserves_pending_balance()
    {
        await using var database = NewDatabase();
        var payment = await AddCompletedStripePaymentAsync(database, amount: 100m);
        var service = new ProviderRefundOperationService(database);

        var first = await service.QueueDirectAsync(
            payment.Id,
            payment.UserId,
            new StripeRefundRequest { Amount = 60m, Reason = "First partial refund", IdempotencyKey = "admin-refund-0001" },
            CancellationToken.None);
        var retry = await service.QueueDirectAsync(
            payment.Id,
            payment.UserId,
            new StripeRefundRequest { Amount = 60m, Reason = "Retry must not duplicate", IdempotencyKey = "admin-refund-0001" },
            CancellationToken.None);

        Assert.Equal(first.Id, retry.Id);
        Assert.Equal("manual-refund-v1:" + payment.Id + ":admin-refund-0001", first.IdempotencyKey);
        Assert.Equal(60m, first.Amount);
        Assert.Equal(60m, first.ExpectedRefundedAmount);
        Assert.Equal(ProviderRefundOperationStatuses.Pending, first.Status);
        Assert.Single(database.ProviderRefundOperations);

        var oversubscribed = new StripeRefundRequest
        {
            Amount = 50m,
            IdempotencyKey = "admin-refund-0002"
        };
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.QueueDirectAsync(
            payment.Id,
            payment.UserId,
            oversubscribed,
            CancellationToken.None));
    }

    [Fact]
    public async Task Settling_a_reconciled_return_refund_updates_sql_and_restocks_once()
    {
        await using var database = NewDatabase();
        var user = new User
        {
            Username = "refund-user",
            Email = "refund-user@example.test",
            FirstName = "Refund",
            LastName = "User",
            PasswordHash = "hash",
            PasswordSalt = "salt"
        };
        var product = new Product { Name = "Refundable racket", Price = 20m, StockQuantity = 3, IsActive = true };
        var order = new Order
        {
            User = user,
            OrderNumber = "REFUND-ORDER-001",
            Status = "Delivered",
            RecipientName = "Refund User",
            PhoneNumber = "123",
            ShippingAddress = "Street 1",
            City = "Sarajevo",
            PostalCode = "71000",
            TotalAmount = 20m,
            SubtotalAmount = 20m,
            DeliveredAt = DateTime.UtcNow.AddDays(-1)
        };
        var orderItem = new OrderItem { Order = order, Product = product, Quantity = 1, UnitPrice = 20m, TotalPrice = 20m };
        order.OrderItems.Add(orderItem);
        var payment = new Payment
        {
            User = user,
            Order = order,
            PaymentType = "Product",
            Amount = 20m,
            PaymentMethod = "Stripe",
            Provider = "Stripe",
            Currency = "bam",
            TransactionId = "pi_refund_settlement",
            Status = "Completed"
        };
        order.Payment = payment;
        var returnRequest = new ReturnRequest
        {
            Order = order,
            UserId = 0, // populated after the user is saved below
            Reason = "Item is defective",
            Status = "RefundPending",
            RefundAmount = 20m,
            Items = [new ReturnRequestItem { OrderItem = orderItem, Quantity = 1, RefundAmount = 20m }]
        };

        database.AddRange(user, product, order, payment, returnRequest);
        await database.SaveChangesAsync();
        returnRequest.UserId = user.Id;
        var leaseId = Guid.NewGuid();
        var operation = new ProviderRefundOperation
        {
            PaymentId = payment.Id,
            ReturnRequestId = returnRequest.Id,
            RequestedByUserId = user.Id,
            Provider = "Stripe",
            Currency = "bam",
            PaymentIntentId = payment.TransactionId!,
            Amount = 20m,
            ExpectedRefundedAmount = 20m,
            Reason = "Approved merchandise return",
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
            new SuccessfulGateway("re_settlement_001", 20m),
            notifications: null,
            NullLogger<ProviderRefundOperationProcessor>.Instance);
        var result = await processor.ProcessAsync(operation, leaseId, CancellationToken.None);

        Assert.True(result.Settled);
        Assert.False(result.AlreadySettled);
        Assert.Equal("Refunded", payment.Status);
        Assert.Equal(20m, payment.RefundedAmount);
        Assert.Equal("Refunded", returnRequest.Status);
        Assert.True(returnRequest.Items.Single().Restocked);
        Assert.Equal(4, product.StockQuantity);
        Assert.Single(database.InventoryMovements);
        Assert.Equal(ProviderRefundOperationStatuses.Succeeded, operation.Status);
        Assert.Equal("re_settlement_001", operation.ProviderRefundId);
        Assert.Null(operation.LeaseId);
    }

    private static PadelClubContext NewDatabase()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase("provider-refund-" + Guid.NewGuid().ToString("N"))
            .Options;
        return new PadelClubContext(options);
    }

    private static async Task<Payment> AddCompletedStripePaymentAsync(PadelClubContext database, decimal amount)
    {
        var user = new User
        {
            Username = "admin-refund-user",
            Email = "admin-refund@example.test",
            FirstName = "Admin",
            LastName = "Refund",
            PasswordHash = "hash",
            PasswordSalt = "salt"
        };
        var payment = new Payment
        {
            User = user,
            PaymentType = "Product",
            Amount = amount,
            PaymentMethod = "Stripe",
            Provider = "Stripe",
            Currency = "bam",
            TransactionId = "pi_direct_refund",
            Status = "Completed"
        };
        database.AddRange(user, payment);
        await database.SaveChangesAsync();
        return payment;
    }

    private sealed class SuccessfulGateway(string refundId, decimal amount) : IStripeRefundGateway
    {
        public Task<StripeRefundGatewayResult> CreateOrReconcileAsync(
            ProviderRefundOperation operation,
            CancellationToken cancellationToken) =>
            Task.FromResult(new StripeRefundGatewayResult(refundId, amount, DateTime.UtcNow));
    }
}
