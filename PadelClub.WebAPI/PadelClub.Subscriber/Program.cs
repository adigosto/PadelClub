using EasyNetQ;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using PadelClub.Subscriber;
using PadelClub.Services.Database;
using PadelClub.Services.Outbox;

var builder = Host.CreateApplicationBuilder(args);
var rabbitMqConnectionString = builder.Configuration.GetConnectionString("RabbitMq")
    ?? throw new InvalidOperationException("ConnectionStrings:RabbitMq must be configured.");
var databaseConnectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection must be configured.");

builder.Services.AddEasyNetQ(rabbitMqConnectionString);
builder.Services.AddDbContext<PadelClubContext>(options => options.UseSqlServer(databaseConnectionString));
builder.Services.AddScoped<IInboxDeduplicationService, InboxDeduplicationService>();
builder.Services.AddHostedService<ProductUpdatedSubscriber>();

await builder.Build().RunAsync();
