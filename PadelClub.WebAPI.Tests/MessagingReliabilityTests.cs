using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PadelClub.Services.Database;
using PadelClub.Services.Outbox;
using PadelClub.WebAPI.Tests.Infrastructure;
using Xunit;

namespace PadelClub.WebAPI.Tests;

[Collection(SqlServerIntegrationCollection.Name)]
public sealed class MessagingReliabilityTests(SqlServerIntegrationFixture fixture)
{
    private readonly SqlServerIntegrationFixture _fixture = fixture;

    [Fact]
    public async Task Outbox_leases_are_exclusive_recoverable_and_owner_checked()
    {
        await ClearOutboxAsync();
        var messageIds = await AddDueMessagesAsync(4);

        using var firstScope = _fixture.Api.Services.CreateScope();
        using var secondScope = _fixture.Api.Services.CreateScope();
        var firstPublisher = firstScope.ServiceProvider.GetRequiredService<IOutboxLeaseService>();
        var secondPublisher = secondScope.ServiceProvider.GetRequiredService<IOutboxLeaseService>();

        var claims = await Task.WhenAll(
            firstPublisher.ClaimDueAsync(2, TimeSpan.FromMinutes(5)),
            secondPublisher.ClaimDueAsync(2, TimeSpan.FromMinutes(5)));

        var claimed = claims.SelectMany(claim => claim.Messages).ToArray();
        Assert.Equal(4, claimed.Length);
        Assert.Equal(4, claimed.Select(message => message.Id).Distinct().Count());
        Assert.Equal(messageIds.OrderBy(id => id), claimed.Select(message => message.Id).OrderBy(id => id));

        var firstClaim = claims[0];
        Assert.NotEmpty(firstClaim.Messages);
        var expiredMessageId = firstClaim.Messages[0].Id;
        await using (var expiryScope = _fixture.Api.Services.CreateAsyncScope())
        {
            var database = expiryScope.ServiceProvider.GetRequiredService<PadelClubContext>();
            await database.OutboxMessages
                .Where(message => message.Id == expiredMessageId)
                .ExecuteUpdateAsync(setters => setters.SetProperty(
                    message => message.LeaseExpiresAtUtc,
                    DateTime.UtcNow.AddMinutes(-1)));
        }

        using var recoveryScope = _fixture.Api.Services.CreateScope();
        var recoveryPublisher = recoveryScope.ServiceProvider.GetRequiredService<IOutboxLeaseService>();
        var recovered = await recoveryPublisher.ClaimDueAsync(1, TimeSpan.FromMinutes(5));
        var recoveredMessage = Assert.Single(recovered.Messages);
        Assert.Equal(expiredMessageId, recoveredMessage.Id);
        Assert.NotEqual(firstClaim.LeaseId, recovered.LeaseId);

        Assert.False(await recoveryPublisher.MarkPublishedAsync(
            recoveredMessage.Id,
            Guid.NewGuid()));
        Assert.True(await recoveryPublisher.MarkPublishedAsync(
            recoveredMessage.Id,
            recovered.LeaseId));

        await using var verificationScope = _fixture.Api.Services.CreateAsyncScope();
        var verificationDatabase = verificationScope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var persisted = await verificationDatabase.OutboxMessages.SingleAsync(message => message.Id == recoveredMessage.Id);
        Assert.NotNull(persisted.PublishedAtUtc);
        Assert.Null(persisted.LeaseId);
        Assert.Null(persisted.LeaseExpiresAtUtc);
        Assert.Equal(1, persisted.AttemptCount);
    }

    [Fact]
    public async Task Inbox_deduplicates_concurrent_delivery_by_consumer_and_event_id()
    {
        await using (var cleanupScope = _fixture.Api.Services.CreateAsyncScope())
        {
            var database = cleanupScope.ServiceProvider.GetRequiredService<PadelClubContext>();
            await database.InboxMessages.ExecuteDeleteAsync();
        }

        var eventId = Guid.NewGuid();
        const string consumer = "tests.product-update-worker.v1";

        using var firstScope = _fixture.Api.Services.CreateScope();
        using var secondScope = _fixture.Api.Services.CreateScope();
        var firstInbox = new InboxDeduplicationService(
            firstScope.ServiceProvider.GetRequiredService<PadelClubContext>());
        var secondInbox = new InboxDeduplicationService(
            secondScope.ServiceProvider.GetRequiredService<PadelClubContext>());

        var receipts = await Task.WhenAll(
            firstInbox.RecordReceiptAsync(consumer, eventId, OutboxMessageTypes.ProductUpdated),
            secondInbox.RecordReceiptAsync(consumer, eventId, OutboxMessageTypes.ProductUpdated));

        Assert.Equal(1, receipts.Count(receipt => receipt.IsFirstDelivery));
        Assert.Equal(1, receipts.Count(receipt => !receipt.IsFirstDelivery));

        await using var verificationScope = _fixture.Api.Services.CreateAsyncScope();
        var verificationDatabase = verificationScope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var stored = await verificationDatabase.InboxMessages
            .SingleAsync(message => message.Consumer == consumer && message.EventId == eventId);
        Assert.Equal(OutboxMessageTypes.ProductUpdated, stored.MessageType);
    }

    private async Task ClearOutboxAsync()
    {
        await using var scope = _fixture.Api.Services.CreateAsyncScope();
        var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
        await database.OutboxMessages.ExecuteDeleteAsync();
    }

    private async Task<Guid[]> AddDueMessagesAsync(int count)
    {
        var messages = Enumerable.Range(0, count)
            .Select(index => new OutboxMessage
            {
                Id = Guid.NewGuid(),
                Type = OutboxMessageTypes.ProductUpdated,
                Payload = "{}",
                OccurredAtUtc = DateTime.UtcNow.AddSeconds(index),
                NextAttemptAtUtc = DateTime.UtcNow.AddMinutes(-1)
            })
            .ToArray();

        await using var scope = _fixture.Api.Services.CreateAsyncScope();
        var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
        database.OutboxMessages.AddRange(messages);
        await database.SaveChangesAsync();
        return messages.Select(message => message.Id).ToArray();
    }
}
