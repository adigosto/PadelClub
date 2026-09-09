using System.Text.Json;
using EasyNetQ;
using PadelClub.Model.Messages;
using PadelClub.Services.Database;
using PadelClub.Services.Outbox;

namespace PadelClub.WebAPI.Outbox;

/// <summary>
/// Publishes committed outbox records with at-least-once delivery semantics.
/// If RabbitMQ is unavailable, the source-of-truth SQL row remains pending and
/// is retried with bounded exponential backoff after the API recovers.
/// </summary>
public sealed class OutboxPublisherWorker(
    IServiceScopeFactory scopeFactory,
    IBus bus,
    ILogger<OutboxPublisherWorker> logger) : BackgroundService
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(3);
    private static readonly TimeSpan LeaseDuration = TimeSpan.FromMinutes(2);
    // Leave time to persist a controlled retry before the two-minute lease can
    // be reclaimed by another replica. The independent WaitAsync deadline also
    // protects us if a broker implementation ignores its cancellation token.
    private static readonly TimeSpan PublishTimeout = TimeSpan.FromSeconds(90);
    private const int BatchSize = 25;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await PublishDueMessagesAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                logger.LogError(exception, "Outbox publish cycle failed; pending messages remain durable for retry.");
            }

            try
            {
                await Task.Delay(PollInterval, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
        }
    }

    private async Task PublishDueMessagesAsync(CancellationToken cancellationToken)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var leases = scope.ServiceProvider.GetRequiredService<IOutboxLeaseService>();
        var lease = await leases.ClaimDueAsync(BatchSize, LeaseDuration, cancellationToken);

        foreach (var message in lease.Messages)
        {
            // Renew immediately before network I/O. If a prior owner died and
            // this lease was reclaimed, do not start a competing publication.
            if (!await leases.RenewLeaseAsync(message.Id, lease.LeaseId, LeaseDuration, cancellationToken))
            {
                logger.LogWarning(
                    "Skipped outbox message {OutboxMessageId} because its publisher lease was lost before publication.",
                    message.Id);
                continue;
            }

            var attemptCount = message.AttemptCount + 1;
            try
            {
                await PublishAsync(message, cancellationToken);
                if (await leases.MarkPublishedAsync(message.Id, lease.LeaseId, cancellationToken))
                {
                    logger.LogInformation(
                        "Published outbox message {OutboxMessageId} of type {OutboxMessageType} after {AttemptCount} attempt(s).",
                        message.Id,
                        message.Type,
                        attemptCount);
                }
                else
                {
                    // The broker may have received the event just before this
                    // replica's lease expired. It remains pending for a later
                    // retry, and the stable EventId lets the inbox deduplicate.
                    logger.LogWarning(
                        "Outbox message {OutboxMessageId} was published but its lease was no longer owned when acknowledging it. It may be delivered again.",
                        message.Id);
                }
            }
            catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
            {
                var retryAtUtc = DateTime.UtcNow.Add(BackoffFor(attemptCount));
                if (await leases.RecordFailureAsync(
                        message.Id,
                        lease.LeaseId,
                        retryAtUtc,
                        TrimError(exception.Message),
                        cancellationToken))
                {
                    logger.LogWarning(
                        exception,
                        "Could not publish outbox message {OutboxMessageId} of type {OutboxMessageType}; retrying at {RetryAtUtc}.",
                        message.Id,
                        message.Type,
                        retryAtUtc);
                }
                else
                {
                    logger.LogWarning(
                        exception,
                        "Could not publish outbox message {OutboxMessageId}, but its publisher lease was lost before recording the failure.",
                        message.Id);
                }
            }
        }
    }

    private async Task PublishAsync(OutboxMessage message, CancellationToken cancellationToken)
    {
        if (message.Type != OutboxMessageTypes.ProductUpdated)
            throw new InvalidOperationException($"Unsupported outbox message type '{message.Type}'.");

        var payload = JsonSerializer.Deserialize<ProductUpdated>(message.Payload)
            ?? throw new InvalidOperationException("Product-update outbox payload is invalid.");
        if (payload.EventId != message.Id)
            throw new InvalidOperationException("Product-update outbox payload does not match its durable message identifier.");

        await PublishWithinDeadlineAsync(
            brokerCancellationToken => bus.PubSub.PublishAsync(payload, cancellationToken: brokerCancellationToken),
            PublishTimeout,
            cancellationToken);
    }

    /// <summary>
    /// Bounds a broker operation independently of the broker's cancellation-token support.
    /// A late broker completion can still produce a duplicate delivery after the durable
    /// message is retried, which is intentional at-least-once behavior; subscribers use
    /// the stable event identifier and inbox receipt to deduplicate it.
    /// </summary>
    internal static async Task PublishWithinDeadlineAsync(
        Func<CancellationToken, Task> publish,
        TimeSpan deadline,
        CancellationToken stoppingToken)
    {
        ArgumentNullException.ThrowIfNull(publish);
        if (deadline <= TimeSpan.Zero)
            throw new ArgumentOutOfRangeException(nameof(deadline), "The broker publish deadline must be greater than zero.");

        using var deadlineCancellation = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
        deadlineCancellation.CancelAfter(deadline);

        var publishTask = publish(deadlineCancellation.Token);
        try
        {
            // WaitAsync enforces the deadline even if the broker ignores the
            // cancellation token supplied above.
            await publishTask.WaitAsync(deadline, stoppingToken);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Waiting can observe the host token before the linked-token
            // callback reaches the broker task. Cancel it explicitly so a
            // graceful host shutdown never leaves that operation running.
            deadlineCancellation.Cancel();
            throw;
        }
        catch (TimeoutException exception) when (!stoppingToken.IsCancellationRequested)
        {
            deadlineCancellation.Cancel();
            ObserveLateFault(publishTask);
            throw new TimeoutException(
                $"Outbox broker publish exceeded its {deadline.TotalSeconds:0}-second deadline.",
                exception);
        }
        catch (OperationCanceledException exception)
            when (!stoppingToken.IsCancellationRequested && deadlineCancellation.IsCancellationRequested)
        {
            // Some broker clients complete their task with cancellation as soon
            // as the linked deadline token fires. Treat that the same as a
            // WaitAsync timeout so the row records a retry rather than exiting
            // the worker as if the host were stopping.
            ObserveLateFault(publishTask);
            throw new TimeoutException(
                $"Outbox broker publish exceeded its {deadline.TotalSeconds:0}-second deadline.",
                exception);
        }
    }

    private static void ObserveLateFault(Task publishTask)
    {
        _ = publishTask.ContinueWith(
            static completed => _ = completed.Exception,
            CancellationToken.None,
            TaskContinuationOptions.OnlyOnFaulted | TaskContinuationOptions.ExecuteSynchronously,
            TaskScheduler.Default);
    }

    private static TimeSpan BackoffFor(int attemptCount) => TimeSpan.FromSeconds(
        Math.Min(Math.Pow(2, Math.Min(attemptCount, 8)), 300));

    private static string TrimError(string error) =>
        error.Length <= 2_000 ? error : error[..2_000];
}
