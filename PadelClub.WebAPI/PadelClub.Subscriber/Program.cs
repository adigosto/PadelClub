using EasyNetQ;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using PadelClub.Model.Messages;
var builder = Host.CreateDefaultBuilder(args);

builder.ConfigureServices(services =>
{
    services.AddEasyNetQ("host=localhost");

    services.AddHostedService<ProductUpdatedSubscriber>();
});

await builder.RunConsoleAsync();