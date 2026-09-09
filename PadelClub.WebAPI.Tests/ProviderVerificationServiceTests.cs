using System.Net.Http;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using PadelClub.Model.Requests;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Notifications;
using PadelClub.WebAPI.Payments;
using PadelClub.WebAPI.ProviderVerification;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public sealed class ProviderVerificationServiceTests
{
    [Fact]
    public async Task Disabled_or_unconfirmed_verification_never_calls_a_gateway_or_creates_evidence()
    {
        await using var db = CreateDb();
        var gateway = new FakeGateway();
        var disabled = CreateService(db, gateway, verification: new ProviderVerificationOptions());

        await Assert.ThrowsAsync<ProviderVerificationPreconditionException>(() => disabled.VerifyAsync(
            1, "smtp", new ProviderVerificationRequest { ConfirmExternalCall = true }));
        Assert.Empty(gateway.Calls);
        Assert.Empty(db.ProviderVerificationAttempts);

        var enabled = CreateService(
            db,
            gateway,
            verification: SmtpVerificationOptions(),
            notifications: SmtpNotificationOptions());
        await Assert.ThrowsAsync<ProviderVerificationPreconditionException>(() => enabled.VerifyAsync(
            1, "smtp", new ProviderVerificationRequest { ConfirmExternalCall = false }));
        Assert.Empty(gateway.Calls);
        Assert.Empty(db.ProviderVerificationAttempts);
    }

    [Fact]
    public async Task Successful_fixed_smtp_rehearsal_persists_only_safe_acceptance_evidence()
    {
        await using var db = CreateDb();
        var gateway = new FakeGateway();
        var service = CreateService(
            db,
            gateway,
            verification: SmtpVerificationOptions(),
            notifications: SmtpNotificationOptions());

        var response = await service.VerifyAsync(
            1, "SMTP", new ProviderVerificationRequest { ConfirmExternalCall = true });

        Assert.Equal(["smtp"], gateway.Calls);
        Assert.Equal("Succeeded", response.Status);
        Assert.Equal("SmtpAccepted", response.OutcomeCategory);
        Assert.NotEqual(Guid.Empty, response.CorrelationId);
        Assert.NotNull(response.CompletedAtUtc);
        var persisted = Assert.Single(db.ProviderVerificationAttempts);
        Assert.Equal(response.CorrelationId, persisted.CorrelationId);
        Assert.Equal("smtp", persisted.Provider);
        Assert.Equal("SendFixedCorrelationMessage", persisted.VerificationKind);
        Assert.DoesNotContain("exam-recipient@example.test", JsonSerializer.Serialize(response));
        Assert.DoesNotContain("smtp.example.test", JsonSerializer.Serialize(response));
    }

    [Fact]
    public async Task Transport_failure_is_durable_but_does_not_expose_raw_provider_details()
    {
        await using var db = CreateDb();
        var gateway = new FakeGateway
        {
            Error = new HttpRequestException("smtp password=secret and recipient=exam-recipient@example.test")
        };
        var service = CreateService(
            db,
            gateway,
            verification: SmtpVerificationOptions(),
            notifications: SmtpNotificationOptions());

        var response = await service.VerifyAsync(
            1, "smtp", new ProviderVerificationRequest { ConfirmExternalCall = true });

        Assert.Equal("Failed", response.Status);
        Assert.Equal("TransportFailure", response.OutcomeCategory);
        Assert.NotNull(response.CompletedAtUtc);
        var persisted = Assert.Single(db.ProviderVerificationAttempts);
        Assert.Equal("TransportFailure", persisted.OutcomeCategory);
        var serialized = JsonSerializer.Serialize(response);
        Assert.DoesNotContain("secret", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("exam-recipient@example.test", serialized, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Stripe_live_mode_is_rejected_before_any_outbound_call()
    {
        await using var db = CreateDb();
        var gateway = new FakeGateway();
        var service = CreateService(
            db,
            gateway,
            verification: new ProviderVerificationOptions
            {
                Enabled = true,
                AllowStripeTestRead = true,
                StripeTestPaymentIntentId = "pi_test_fixed"
            },
            stripe: new StripeOptions { SecretKey = "sk_live_not_allowed", Currency = "bam" });

        await Assert.ThrowsAsync<ProviderVerificationPreconditionException>(() => service.VerifyAsync(
            1, "stripe", new ProviderVerificationRequest { ConfirmExternalCall = true }));

        Assert.Empty(gateway.Calls);
        Assert.Empty(db.ProviderVerificationAttempts);
    }

    [Fact]
    public async Task Local_mailpit_is_rejected_as_third_party_smtp_evidence_before_any_outbound_call()
    {
        await using var db = CreateDb();
        var gateway = new FakeGateway();
        var service = CreateService(
            db,
            gateway,
            verification: SmtpVerificationOptions(),
            notifications: new NotificationDeliveryOptions
            {
                Smtp = new SmtpOptions { Host = "padelclub-mailpit", Port = 1025 }
            });

        await Assert.ThrowsAsync<ProviderVerificationPreconditionException>(() => service.VerifyAsync(
            1, "smtp", new ProviderVerificationRequest { ConfirmExternalCall = true }));

        Assert.Empty(gateway.Calls);
        Assert.Empty(db.ProviderVerificationAttempts);
    }

    [Fact]
    public async Task Smtp_sender_with_no_host_does_not_log_or_claim_development_delivery()
    {
        var sender = new SmtpEmailSender(
            Options.Create(new NotificationDeliveryOptions()),
            NullLogger<SmtpEmailSender>.Instance);

        await Assert.ThrowsAsync<EmailDeliveryUnavailableException>(() => sender.SendAsync(
            "recipient@example.test", "Subject", "reset-token-should-not-be-logged", CancellationToken.None));
    }

    private static PadelClubContext CreateDb()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        return new PadelClubContext(options);
    }

    private static ProviderVerificationService CreateService(
        PadelClubContext db,
        IProviderVerificationGateway gateway,
        ProviderVerificationOptions verification,
        NotificationDeliveryOptions? notifications = null,
        StripeOptions? stripe = null) => new(
        db,
        Options.Create(verification),
        Options.Create(stripe ?? new StripeOptions { Currency = "bam" }),
        Options.Create(notifications ?? new NotificationDeliveryOptions()),
        gateway);

    private static ProviderVerificationOptions SmtpVerificationOptions() => new()
    {
        Enabled = true,
        AllowSmtp = true,
        SmtpRecipient = "exam-recipient@example.test",
        MinimumIntervalMinutes = 15
    };

    private static NotificationDeliveryOptions SmtpNotificationOptions() => new()
    {
        Smtp = new SmtpOptions { Host = "smtp.example.test", Port = 587 }
    };

    private sealed class FakeGateway : IProviderVerificationGateway
    {
        public List<string> Calls { get; } = [];

        public Exception? Error { get; init; }

        public Task VerifyStripeTestReadAsync(string paymentIntentId, CancellationToken cancellationToken) => InvokeAsync("stripe");

        public Task VerifySmtpAsync(string recipient, Guid correlationId, CancellationToken cancellationToken) => InvokeAsync("smtp");

        public Task VerifyFirebaseAsync(string installationId, Guid correlationId, CancellationToken cancellationToken) => InvokeAsync("firebase");

        private Task InvokeAsync(string provider)
        {
            Calls.Add(provider);
            return Error is null ? Task.CompletedTask : Task.FromException(Error);
        }
    }
}
