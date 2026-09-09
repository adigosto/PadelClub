using PadelClub.WebAPI.Outbox;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public sealed class OutboxPublisherDeadlineTests
{
    [Fact]
    public async Task Publish_deadline_times_out_even_if_the_broker_ignores_cancellation()
    {
        var brokerObservedCancellation = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        var stalledBrokerPublish = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        var exception = await Assert.ThrowsAsync<TimeoutException>(() =>
            OutboxPublisherWorker.PublishWithinDeadlineAsync(
                brokerCancellationToken =>
                {
                    brokerCancellationToken.Register(() => brokerObservedCancellation.TrySetResult(true));
                    return stalledBrokerPublish.Task;
                },
                TimeSpan.FromMilliseconds(25),
                CancellationToken.None));

        Assert.Contains("deadline", exception.Message, StringComparison.OrdinalIgnoreCase);
        Assert.True(await brokerObservedCancellation.Task.WaitAsync(TimeSpan.FromSeconds(1)));
    }

    [Fact]
    public async Task Host_cancellation_is_not_reclassified_as_a_publish_timeout()
    {
        using var stopping = new CancellationTokenSource();
        var brokerObservedCancellation = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);

        var publishing = OutboxPublisherWorker.PublishWithinDeadlineAsync(
            async brokerCancellationToken =>
            {
                try
                {
                    await Task.Delay(Timeout.InfiniteTimeSpan, brokerCancellationToken);
                }
                catch (OperationCanceledException)
                {
                    brokerObservedCancellation.TrySetResult(true);
                    throw;
                }
            },
            TimeSpan.FromSeconds(1),
            stopping.Token);

        stopping.Cancel();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => publishing);
        Assert.True(await brokerObservedCancellation.Task.WaitAsync(TimeSpan.FromSeconds(1)));
    }
}
