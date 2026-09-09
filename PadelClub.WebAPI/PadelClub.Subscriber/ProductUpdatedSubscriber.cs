using EasyNetQ;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PadelClub.Model.Messages;
using PadelClub.Services.Outbox;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace PadelClub.Subscriber;

public sealed class ProductUpdatedSubscriber(
    IConnectionFactory connectionFactory,
    IConventions conventions,
    ISerializer serializer,
    IServiceScopeFactory scopeFactory,
    ILogger<ProductUpdatedSubscriber> logger) : BackgroundService
{
    private const string SubscriptionId = "padelclub.product-update-worker.v1";
    private static readonly TimeSpan InitialRetryDelay = TimeSpan.FromSeconds(1);
    private static readonly TimeSpan MaximumRetryDelay = TimeSpan.FromSeconds(10);
    private readonly IServiceScopeFactory _scopeFactory = scopeFactory;
    private readonly ILogger<ProductUpdatedSubscriber> _logger = logger;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var retryDelay = InitialRetryDelay;
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var connection = await connectionFactory.CreateConnectionAsync(stoppingToken);
                await using var channel = await connection.CreateChannelAsync(
                    new CreateChannelOptions(publisherConfirmationsEnabled: true, publisherConfirmationTrackingEnabled: true), stoppingToken);
                // Retain EasyNetQ routing and serialization so existing publishers
                // and queued deliveries remain compatible with this native consumer.
                var exchange = conventions.ExchangeNamingConvention(typeof(ProductUpdated));
                var queue = conventions.QueueNamingConvention(typeof(ProductUpdated), SubscriptionId);
                var errorQueue = queue + ".failed";
                await channel.ExchangeDeclareAsync(exchange, RabbitMQ.Client.ExchangeType.Topic, durable: true, autoDelete: false, cancellationToken: stoppingToken);
                await channel.QueueDeclareAsync(queue, durable: true, exclusive: false, autoDelete: false, cancellationToken: stoppingToken);
                await channel.QueueBindAsync(queue, exchange, "#", cancellationToken: stoppingToken);
                await channel.QueueDeclareAsync(errorQueue, durable: true, exclusive: false, autoDelete: false, cancellationToken: stoppingToken);
                await channel.BasicQosAsync(0, 1, false, stoppingToken);
                var consumer = new AsyncEventingBasicConsumer(channel);
                consumer.ReceivedAsync += async (_, delivery) =>
                {
                    try
                    {
                        // Deserialize while the RabbitMQ-owned memory is valid.
                        var message = (ProductUpdated)serializer.BytesToMessage(typeof(ProductUpdated), delivery.Body);
                        if (message is null || message.EventId == Guid.Empty || message.Product is null)
                            throw new InvalidDataException("Product update is missing its event identity or product.");
                        await HandleAsync(message, stoppingToken);
                        await channel.BasicAckAsync(delivery.DeliveryTag, false, stoppingToken);
                    }
                    catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                    {
                        // Closing the channel requeues the unacknowledged delivery.
                    }
                    catch (Exception exception)
                    {
                        _logger.LogError(exception, "Product update delivery failed; preserving it in {ErrorQueue}.", errorQueue);
                        try
                        {
                            // Publisher confirms complete before the source is acknowledged.
                            await channel.BasicPublishAsync("", errorQueue, mandatory: true,
                                new BasicProperties { Persistent = true, ContentType = delivery.BasicProperties.ContentType },
                                delivery.Body, stoppingToken);
                            await channel.BasicAckAsync(delivery.DeliveryTag, false, stoppingToken);
                        }
                        catch (Exception) when (!stoppingToken.IsCancellationRequested)
                        {
                            await channel.BasicNackAsync(delivery.DeliveryTag, false, requeue: true, stoppingToken);
                        }
                    }
                };
                var tag = await channel.BasicConsumeAsync(queue, autoAck: false, consumer, stoppingToken);
                _logger.LogInformation("Subscribed with AsyncEventingBasicConsumer to {Queue}.", queue);
                retryDelay = InitialRetryDelay;
                // Rebuild a channel after a protocol error; connection recovery
                // alone does not recover channels closed by protocol exceptions.
                while (channel.IsOpen && !stoppingToken.IsCancellationRequested)
                    await Task.Delay(TimeSpan.FromSeconds(1), stoppingToken);
                if (channel.IsOpen)
                    await channel.BasicCancelAsync(tag, cancellationToken: stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                _logger.LogWarning(exception, "Product consumer disconnected; retrying in {Delay}.", retryDelay);
            }
            try { await Task.Delay(retryDelay, stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { return; }
            retryDelay = TimeSpan.FromSeconds(Math.Min(retryDelay.TotalSeconds * 2, MaximumRetryDelay.TotalSeconds));
        }
    }

    private async Task HandleAsync(ProductUpdated message, CancellationToken cancellationToken)
    {
        var retryDelay = InitialRetryDelay;
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                await using var scope = _scopeFactory.CreateAsyncScope();
                var inbox = scope.ServiceProvider.GetRequiredService<IInboxDeduplicationService>();
                var receipt = await inbox.RecordReceiptAsync(
                    SubscriptionId,
                    message.EventId,
                    OutboxMessageTypes.ProductUpdated,
                    cancellationToken);

                if (!receipt.IsFirstDelivery)
                {
                    _logger.LogInformation("Ignored duplicate product update event {EventId} for consumer {SubscriptionId}.", message.EventId, SubscriptionId);
                    return;
                }

                _logger.LogInformation("Received product update event {EventId} for product {ProductId} ({ProductName}).", message.EventId, message.Product.Id, message.Product.Name);
                return;
            }
            catch (Exception exception) when (exception is not OperationCanceledException || !cancellationToken.IsCancellationRequested)
            {
                if (attempt >= 3) throw;
                _logger.LogWarning(exception, "Product update event {EventId} failed on attempt {Attempt}; retrying in {RetryDelaySeconds} seconds.", message.EventId, attempt, retryDelay.TotalSeconds);
                await Task.Delay(retryDelay, cancellationToken);
                retryDelay = TimeSpan.FromSeconds(Math.Min(retryDelay.TotalSeconds * 2, MaximumRetryDelay.TotalSeconds));
            }
        }
    }
}
