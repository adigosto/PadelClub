using System.Collections.Concurrent;
using System.Text;
using DotNet.Testcontainers.Builders;
using EasyNetQ;
using Microsoft.Extensions.DependencyInjection;
using PadelClub.Model.Messages;
using PadelClub.Services.Outbox;
using PadelClub.Subscriber;
using RabbitMQ.Client;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class NativeRabbitConsumerTests
{
    [Fact]
    public async Task Native_consumer_receives_EasyNetQ_messages_and_preserves_malformed_deliveries()
    {
        await using var rabbit = new ContainerBuilder("rabbitmq:3.13-management")
            .WithPortBinding(5672, true)
            .WithWaitStrategy(Wait.ForUnixContainer().UntilInternalTcpPortIsAvailable(5672)).Build();
        await rabbit.StartAsync();
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddEasyNetQ($"host={rabbit.Hostname};port={rabbit.GetMappedPublicPort(5672)};username=guest;password=guest");
        var inbox = new MemoryInbox();
        services.AddSingleton<IInboxDeduplicationService>(inbox);
        services.AddSingleton<ProductUpdatedSubscriber>();
        await using var provider = services.BuildServiceProvider();
        var worker = provider.GetRequiredService<ProductUpdatedSubscriber>();
        var factory = provider.GetRequiredService<IConnectionFactory>();
        await using var connection = await factory.CreateConnectionAsync();
        await using var channel = await connection.CreateChannelAsync();
        var conventions = provider.GetRequiredService<IConventions>();
        var queue = conventions.QueueNamingConvention(typeof(ProductUpdated), "padelclub.product-update-worker.v1");
        await worker.StartAsync(CancellationToken.None);
        try
        {
            await Until(async () =>
            {
                var status = await channel.QueueDeclareAsync(queue, true, false, false);
                return status.ConsumerCount == 1;
            });
            var message = new ProductUpdated { EventId = Guid.NewGuid() };
            var bus = provider.GetRequiredService<IBus>();
            await bus.PubSub.PublishAsync(message);
            await bus.PubSub.PublishAsync(message);
            await Until(() => Task.FromResult(inbox.Deliveries >= 2));
            Assert.Single(inbox.Events);
            await channel.BasicPublishAsync("", queue, Encoding.UTF8.GetBytes("invalid-json"));
            await Until(async () => (await channel.QueueDeclareAsync(queue + ".failed", true, false, false)).MessageCount == 1);
            var failed = await channel.BasicGetAsync(queue + ".failed", true);
            Assert.Equal("invalid-json", Encoding.UTF8.GetString(failed!.Body.Span));
        }
        finally { await worker.StopAsync(CancellationToken.None); }
    }

    private static async Task Until(Func<Task<bool>> condition)
    {
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        while (!await condition()) await Task.Delay(100, deadline.Token);
    }

    private sealed class MemoryInbox : IInboxDeduplicationService
    {
        public ConcurrentDictionary<Guid, byte> Events { get; } = new();
        public int Deliveries;
        public Task<InboxReceipt> RecordReceiptAsync(string consumer, Guid eventId, string messageType, CancellationToken cancellationToken = default)
        {
            var first = Events.TryAdd(eventId, 0);
            Interlocked.Increment(ref Deliveries);
            return Task.FromResult(new InboxReceipt(first, DateTime.UtcNow));
        }
    }
}
