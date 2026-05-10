using EasyNetQ;
using Microsoft.Extensions.Hosting;
using PadelClub.Model.Messages;

public class ProductUpdatedSubscriber : IHostedService
{
    private readonly IBus _bus;

    public ProductUpdatedSubscriber(IBus bus)
    {
        _bus = bus;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        await _bus.PubSub.SubscribeAsync<ProductUpdated>(
            "console_printer",
            async message =>
            {
                Console.WriteLine($"Product updated: {message.Product.Name}");
                await Task.CompletedTask;
            }
        );
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }
}
