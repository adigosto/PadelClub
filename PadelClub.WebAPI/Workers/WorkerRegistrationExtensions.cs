using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using PadelClub.Services;
using PadelClub.Services.Outbox;
using PadelClub.WebAPI.Memberships;
using PadelClub.WebAPI.Notifications;
using PadelClub.WebAPI.Outbox;
using PadelClub.WebAPI.Payments;
using PadelClub.WebAPI.Privacy;

namespace PadelClub.WebAPI.Workers;

public static class WorkerRegistrationExtensions
{
    public static IServiceCollection AddPadelClubWorkers(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<StripeOptions>().Bind(configuration.GetSection(StripeOptions.SectionName)).ValidateOnStart();
        services.AddOptions<NotificationDeliveryOptions>().Bind(configuration.GetSection(NotificationDeliveryOptions.SectionName)).ValidateOnStart();
        services.AddScoped<IProviderRefundOperationLeaseService, SqlServerProviderRefundOperationLeaseService>();
        services.AddScoped<IProviderRefundOperationProcessor, ProviderRefundOperationProcessor>();
        services.AddScoped<IStripeRefundGateway, StripeRefundGateway>();
        services.AddScoped<SmtpEmailSender>();
        services.AddScoped<IEmailSender>(provider => provider.GetRequiredService<SmtpEmailSender>());
        services.AddSingleton<IPushSender, FirebasePushSender>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<IOutboxLeaseService, SqlServerOutboxLeaseService>();
        services.AddHostedService<ProviderRefundOperationWorker>();
        services.AddHostedService<NotificationDeliveryWorker>();
        services.AddHostedService<MembershipLifecycleWorker>();
        services.AddHostedService<PrivacyDeletionWorker>();
        services.AddHostedService<OutboxPublisherWorker>();
        return services;
    }
}