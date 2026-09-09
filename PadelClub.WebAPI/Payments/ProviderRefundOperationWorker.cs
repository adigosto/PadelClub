namespace PadelClub.WebAPI.Payments;

/// <summary>
/// Submits committed provider refund operations and reconciles accepted Stripe
/// results into SQL. The durable lease permits a later API replica to resume
/// safely after a process crash or temporary provider/database outage.
/// </summary>
public sealed class ProviderRefundOperationWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<ProviderRefundOperationWorker> logger) : BackgroundService
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(5);
    private static readonly TimeSpan LeaseDuration = TimeSpan.FromMinutes(2);
    private const int BatchSize = 10;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessDueOperationsAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                logger.LogError(exception, "Provider refund processing cycle failed; durable operations remain pending for retry.");
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

    private async Task ProcessDueOperationsAsync(CancellationToken cancellationToken)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var leases = scope.ServiceProvider.GetRequiredService<IProviderRefundOperationLeaseService>();
        var processor = scope.ServiceProvider.GetRequiredService<IProviderRefundOperationProcessor>();
        var lease = await leases.ClaimDueAsync(BatchSize, LeaseDuration, cancellationToken);

        foreach (var operation in lease.Operations)
        {
            if (!await leases.RenewLeaseAsync(operation.Id, lease.LeaseId, LeaseDuration, cancellationToken))
            {
                logger.LogWarning("Skipped provider refund operation {ProviderRefundOperationId} because its worker lease was lost before provider I/O.", operation.Id);
                continue;
            }

            var attemptCount = operation.AttemptCount + 1;
            try
            {
                // Do not apply a separate WaitAsync timeout around the whole
                // processor: it performs SQL settlement after provider I/O,
                // and letting it continue after a timeout would race two uses
                // of the scoped DbContext. The Stripe SDK receives the host
                // cancellation token; a crashed/slow replica is instead made
                // recoverable by the expiring SQL lease and provider
                // idempotency/reconciliation on the next attempt.
                var result = await processor.ProcessAsync(operation, lease.LeaseId, cancellationToken);
                if (result.AlreadySettled)
                {
                    logger.LogInformation("Provider refund operation {ProviderRefundOperationId} was already settled.", operation.Id);
                }
                else if (result.Settled)
                {
                    logger.LogInformation("Settled provider refund operation {ProviderRefundOperationId} after {AttemptCount} attempt(s).", operation.Id, attemptCount);
                }
            }
            catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
            {
                var retryAtUtc = DateTime.UtcNow.Add(BackoffFor(attemptCount));
                if (await leases.RecordFailureAsync(operation.Id, lease.LeaseId, retryAtUtc, TrimError(exception.Message), cancellationToken))
                {
                    logger.LogWarning(exception, "Could not process provider refund operation {ProviderRefundOperationId}; retrying at {RetryAtUtc}.", operation.Id, retryAtUtc);
                }
                else
                {
                    logger.LogWarning(exception, "Could not process provider refund operation {ProviderRefundOperationId}, but its worker lease was lost before recording the retry.", operation.Id);
                }
            }
        }
    }

    private static TimeSpan BackoffFor(int attemptCount) => TimeSpan.FromSeconds(
        Math.Min(Math.Pow(2, Math.Min(attemptCount, 8)), 300));

    private static string TrimError(string error) => error.Length <= 2_000 ? error : error[..2_000];
}
