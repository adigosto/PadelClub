using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using PadelClub.Model.Responses;
using PadelClub.WebAPI.Controllers;
using PadelClub.WebAPI.Notifications;
using PadelClub.WebAPI.Payments;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public sealed class ProviderReadinessContractTests
{
    [Fact]
    public void Readiness_endpoint_is_administrator_only()
    {
        var policy = Assert.Single(
            typeof(ProviderReadinessController)
                .GetCustomAttributes(typeof(AuthorizeAttribute), true)
                .Cast<AuthorizeAttribute>());

        Assert.Equal("AdminOnly", policy.Policy);
    }

    [Fact]
    public void Default_local_configuration_is_reported_without_provider_calls()
    {
        var response = Read(
            new StripeOptions { Currency = "bam" },
            new NotificationDeliveryOptions
            {
                Smtp = new SmtpOptions
                {
                    Host = "padelclub-mailpit",
                    Port = 1025,
                    FromAddress = "noreply@padelclub.local"
                }
            });

        Assert.Equal("ConfigurationOnly", response.Assessment);
        Assert.Equal("Unconfigured", response.Stripe.Mode);
        Assert.Equal("Disabled", response.Stripe.IntentState);
        Assert.Equal("Disabled", response.Stripe.WebhookState);
        Assert.Equal("Mailpit", response.Smtp.State);
        Assert.Equal("Disabled", response.Firebase.State);
        Assert.Contains("does not contact", response.Caveat, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Readiness_distinguishes_configuration_shapes_and_never_serializes_secrets()
    {
        const string stripeSecret = "sk_test_not-for-output";
        const string webhookSecret = "whsec_not-for-output";
        const string firebasePrivateKey = "-----BEGIN PRIVATE KEY-----never-output-----END PRIVATE KEY-----";
        var response = Read(
            new StripeOptions
            {
                SecretKey = stripeSecret,
                WebhookSecret = webhookSecret,
                Currency = "bam"
            },
            new NotificationDeliveryOptions
            {
                FirebaseProjectId = "padelclub-test",
                FirebaseServiceAccountJson = JsonSerializer.Serialize(new
                {
                    type = "service_account",
                    project_id = "padelclub-test",
                    client_email = "service@padelclub-test.iam.gserviceaccount.com",
                    private_key = firebasePrivateKey
                }),
                Smtp = new SmtpOptions
                {
                    Host = "smtp.example.test",
                    Port = 587,
                    FromAddress = "noreply@example.test"
                }
            });

        Assert.Equal("Test", response.Stripe.Mode);
        Assert.Equal("Configured", response.Stripe.IntentState);
        Assert.Equal("Configured", response.Stripe.WebhookState);
        Assert.Equal("Configured", response.Smtp.State);
        Assert.Equal("ServiceAccount", response.Firebase.State);

        var payload = JsonSerializer.Serialize(response);
        Assert.DoesNotContain(stripeSecret, payload, StringComparison.Ordinal);
        Assert.DoesNotContain(webhookSecret, payload, StringComparison.Ordinal);
        Assert.DoesNotContain(firebasePrivateKey, payload, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("", "", "Disabled")]
    [InlineData("padelclub-test", "{", "Misconfigured")]
    [InlineData("padelclub-test", "", "AdcRequested")]
    public void Firebase_state_is_explicit_for_disabled_invalid_and_adc_requested_configuration(
        string projectId,
        string serviceAccountJson,
        string expectedState)
    {
        var response = Read(
            new StripeOptions { Currency = "bam" },
            new NotificationDeliveryOptions
            {
                FirebaseProjectId = projectId,
                FirebaseServiceAccountJson = serviceAccountJson,
                Smtp = new SmtpOptions { Host = string.Empty }
            });

        Assert.Equal(expectedState, response.Firebase.State);
    }

    private static ProviderReadinessResponse Read(
        StripeOptions stripe,
        NotificationDeliveryOptions notifications)
    {
        var controller = new ProviderReadinessController(
            Options.Create(stripe),
            Options.Create(notifications));
        var result = Assert.IsType<OkObjectResult>(controller.Get().Result);
        return Assert.IsType<ProviderReadinessResponse>(result.Value);
    }
}
