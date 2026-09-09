using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;
using PadelClub.Services.Outbox;
using PadelClub.WebAPI.Tests.Infrastructure;
using Xunit;

namespace PadelClub.WebAPI.Tests;

[Collection(SqlServerIntegrationCollection.Name)]
public sealed class ApiIntegrationTests(SqlServerIntegrationFixture fixture)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly SqlServerIntegrationFixture _fixture = fixture;

    [Fact]
    public async Task Login_creates_a_usable_session_and_rejects_a_wrong_password()
    {
        using var client = CreateClient();

        var session = await LoginAsync(client, _fixture.Api.Seed.PlayerUsername);
        Assert.False(string.IsNullOrWhiteSpace(session.AccessToken));
        Assert.False(string.IsNullOrWhiteSpace(session.RefreshToken));

        Authorize(client, session);
        var me = await client.GetFromJsonAsync<UserResponse>("/Users/me", JsonOptions);
        Assert.NotNull(me);
        Assert.Equal(_fixture.Api.Seed.PlayerUsername, me.Username);

        var invalidLogin = await client.PostAsJsonAsync("/Users/login", new UserLoginRequest
        {
            Username = _fixture.Api.Seed.PlayerUsername,
            Password = "wrong-password"
        });
        Assert.Equal(HttpStatusCode.Unauthorized, invalidLogin.StatusCode);
    }

    [Fact]
    public async Task Tournament_mine_returns_only_the_authenticated_players_registration_state()
    {
        var start = DateTime.UtcNow.AddDays(21);
        int tournamentId;
        int unteamedTournamentId;
        using (var scope = _fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var partnerIdentifier = Guid.NewGuid().ToString("N");
            var partner = new PadelClub.Services.Database.User
            {
                Username = $"tournament-partner-{partnerIdentifier}",
                Email = $"tournament-partner-{partnerIdentifier}@integration.test",
                FirstName = "Tournament",
                LastName = "Partner",
                PasswordHash = "not-used-by-this-contract-test",
                PasswordSalt = string.Empty,
                IsActive = true,
                EmailVerifiedAt = DateTime.UtcNow,
                CreatedAt = DateTime.UtcNow
            };
            var tournament = new Tournament
            {
                Name = "Integration Player Hub Cup",
                Description = "Owner-scoped registration contract",
                StartDate = start,
                EndDate = start.AddDays(1),
                RegistrationDeadline = start.AddDays(-2),
                MaxParticipants = 16,
                EntryFee = 25m,
                Status = "Upcoming"
            };
            var unteamedTournament = new Tournament
            {
                Name = "Integration Legacy Registration Cup",
                Description = "Null team numbers must not imply a partner.",
                StartDate = start.AddDays(7),
                EndDate = start.AddDays(8),
                RegistrationDeadline = start.AddDays(5),
                MaxParticipants = 16,
                EntryFee = 25m,
                Status = "Upcoming"
            };
            database.AddRange(partner, tournament, unteamedTournament);
            await database.SaveChangesAsync();
            database.TournamentParticipants.AddRange(
                new TournamentParticipant
                {
                    TournamentId = tournament.Id,
                    UserId = _fixture.Api.Seed.PlayerUserId,
                    TeamNumber = 2,
                    Status = "Confirmed",
                    ConfirmedAt = DateTime.UtcNow
                },
                new TournamentParticipant
                {
                    TournamentId = tournament.Id,
                    UserId = partner.Id,
                    TeamNumber = 2,
                    Status = "Invited"
                },
                new TournamentParticipant
                {
                    TournamentId = unteamedTournament.Id,
                    UserId = _fixture.Api.Seed.PlayerUserId,
                    Status = "Confirmed",
                    ConfirmedAt = DateTime.UtcNow
                },
                new TournamentParticipant
                {
                    TournamentId = unteamedTournament.Id,
                    UserId = partner.Id,
                    Status = "Invited"
                });
            await database.SaveChangesAsync();
            tournamentId = tournament.Id;
            unteamedTournamentId = unteamedTournament.Id;
        }

        using var anonymousClient = CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymousClient.GetAsync("/Tournaments/mine")).StatusCode);

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        var response = await playerClient.GetAsync("/Tournaments/mine");
        response.EnsureSuccessStatusCode();
        var registrations = await response.Content.ReadFromJsonAsync<List<JsonElement>>(JsonOptions) ?? [];

        var registration = Assert.Single(registrations, item =>
            item.GetProperty("tournamentId").GetInt32() == tournamentId);
        Assert.Equal("Confirmed", registration.GetProperty("registrationStatus").GetString());
        Assert.Equal("Tournament Partner", registration.GetProperty("partnerName").GetString());

        var unteamedRegistration = Assert.Single(registrations, item =>
            item.GetProperty("tournamentId").GetInt32() == unteamedTournamentId);
        Assert.Null(unteamedRegistration.GetProperty("partnerName").GetString());
    }

    [Fact]
    public async Task Recommendations_require_a_real_session_and_ignore_test_history()
    {
        using var anonymousClient = CreateClient();
        var anonymousResponse = await anonymousClient.GetAsync("/Recommendations/products?limit=1");
        Assert.Equal(HttpStatusCode.Unauthorized, anonymousResponse.StatusCode);

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        var recommendations = await playerClient.GetFromJsonAsync<List<ProductRecommendationResponse>>(
            "/Recommendations/products?limit=1",
            JsonOptions);

        var recommendation = Assert.Single(recommendations!);
        Assert.Equal("new-arrivals-fallback", recommendation.Strategy);
        Assert.True(recommendation.IsFallback);
    }

    [Fact]
    public async Task Recommendation_exposure_records_owned_click_checkout_attribution_and_admin_funnel()
    {
        using var anonymousClient = CreateClient();
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await anonymousClient.GetAsync("/Operations/recommendations/impact")).StatusCode);

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        var recommendations = await playerClient.GetFromJsonAsync<List<ProductRecommendationResponse>>(
            "/Recommendations/products?limit=1",
            JsonOptions);
        var recommendation = Assert.Single(recommendations!);
        Assert.NotEqual(Guid.Empty, recommendation.ExposureId);

        Assert.Equal(
            HttpStatusCode.NoContent,
            (await playerClient.PostAsync(
                $"/Recommendations/products/{recommendation.ExposureId}/click",
                content: null)).StatusCode);

        // Opaque exposure IDs are scoped to their authenticated owner.
        using var adminClient = CreateClient();
        Authorize(adminClient, _fixture.AdminSession);
        Assert.Equal(
            HttpStatusCode.NotFound,
            (await adminClient.PostAsync(
                $"/Recommendations/products/{recommendation.ExposureId}/click",
                content: null)).StatusCode);

        var checkout = await playerClient.PostAsJsonAsync("/Orders/checkout", new CheckoutRequest
        {
            IdempotencyKey = "exposure-checkout-001",
            RecipientName = "Exposure Player",
            PhoneNumber = "+38761123456",
            ShippingAddress = "Impact Street 1",
            City = "Sarajevo",
            PostalCode = "71000",
            Items =
            [
                new CheckoutLineRequest
                {
                    ProductId = recommendation.Product.Id,
                    Quantity = 1,
                    RecommendationExposureId = recommendation.ExposureId
                }
            ]
        });
        checkout.EnsureSuccessStatusCode();
        var checkoutOrder = await checkout.Content.ReadFromJsonAsync<OrderResponse>(JsonOptions);
        Assert.NotNull(checkoutOrder);

        using (var scope = _fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var exposure = await database.RecommendationExposures
                .SingleAsync(item => item.Id == recommendation.ExposureId);
            Assert.Equal(_fixture.Api.Seed.PlayerUserId, exposure.UserId);
            Assert.Equal(recommendation.Product.Id, exposure.ProductId);
            Assert.NotNull(exposure.ClickedAtUtc);
            Assert.Equal(RecommendationTelemetrySource.IntegrationTest, exposure.TelemetrySource);
            Assert.Null(exposure.PurchasedOrderId);
        }

        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await playerClient.GetAsync("/Operations/recommendations/impact")).StatusCode);
        var impactResponse = await adminClient.GetAsync("/Operations/recommendations/impact");
        impactResponse.EnsureSuccessStatusCode();
        var impact = await impactResponse.Content.ReadFromJsonAsync<RecommendationImpactResponse>(JsonOptions);
        Assert.NotNull(impact);
        Assert.Equal(0, impact.Exposures);
        Assert.True(impact.ExcludedNonOperationalExposures >= 1);
        Assert.Equal(0, impact.ClickedExposures);
        Assert.Equal(0, impact.AttributedCheckouts);
        Assert.Equal("Collecting", impact.EvidenceTier);
        Assert.False(impact.IsMature);
        Assert.Contains(impact.Limitations, limitation =>
            limitation.Contains("not a randomized experiment", StringComparison.Ordinal));
    }

    [Fact]
    public async Task Admin_order_fulfillment_requires_a_linear_lifecycle_and_records_delivery_time()
    {
        var suffix = Guid.NewGuid().ToString("N");
        int orderId;
        using (var scope = _fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var order = new Order
            {
                UserId = _fixture.Api.Seed.PlayerUserId,
                OrderNumber = $"IT-FULFILLMENT-{suffix}",
                Status = "Pending",
                RecipientName = "Integration Fulfillment Customer",
                PhoneNumber = "+38760000000",
                ShippingAddress = "Integration Street 1",
                City = "Sarajevo",
                PostalCode = "71000",
                TotalAmount = 100m,
                SubtotalAmount = 100m,
                CreatedAt = DateTime.UtcNow,
                Origin = OrderOrigin.IntegrationTest
            };
            database.Orders.Add(order);
            await database.SaveChangesAsync();
            orderId = order.Id;
        }

        using var adminClient = CreateClient();
        Authorize(adminClient, _fixture.AdminSession);

        // Staff cannot skip dispatch directly to delivery.
        var skipped = await adminClient.PutAsJsonAsync(
            $"/Orders/{orderId}",
            FulfillmentUpdate($"IT-FULFILLMENT-{suffix}", "Delivered"));
        Assert.Equal(HttpStatusCode.Conflict, skipped.StatusCode);

        foreach (var status in new[] { "Processing", "Shipped", "Delivered" })
        {
            var response = await adminClient.PutAsJsonAsync(
                $"/Orders/{orderId}",
                FulfillmentUpdate($"IT-FULFILLMENT-{suffix}", status));
            response.EnsureSuccessStatusCode();
            var updated = await response.Content.ReadFromJsonAsync<OrderResponse>(JsonOptions);
            Assert.NotNull(updated);
            Assert.Equal(status, updated.Status);
            if (status == "Delivered")
                Assert.NotNull(updated.DeliveredAt);
        }

        // Delivered and cancelled orders are terminal; malformed values are
        // rejected by the same server-side workflow rather than trusting UI.
        Assert.Equal(
            HttpStatusCode.Conflict,
            (await adminClient.PutAsJsonAsync($"/Orders/{orderId}", FulfillmentUpdate($"IT-FULFILLMENT-{suffix}", "Processing"))).StatusCode);
        Assert.Equal(
            HttpStatusCode.Conflict,
            (await adminClient.PutAsJsonAsync($"/Orders/{orderId}", FulfillmentUpdate($"IT-FULFILLMENT-{suffix}", "At customs"))).StatusCode);

        using var verificationScope = _fixture.Api.Services.CreateScope();
        var verificationDatabase = verificationScope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var persisted = await verificationDatabase.Orders.SingleAsync(order => order.Id == orderId);
        Assert.Equal("Delivered", persisted.Status);
        Assert.NotNull(persisted.DeliveredAt);
        Assert.NotNull(persisted.UpdatedAt);
    }

    [Fact]
    public async Task Membership_lifecycle_keeps_player_reads_scoped_and_admin_actions_auditable()
    {
        var originalEnd = DateTime.UtcNow.AddDays(12);
        int playerMembershipId;
        int administratorMembershipId;
        using (var scope = _fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var playerMembership = new Membership
            {
                UserId = _fixture.Api.Seed.PlayerUserId,
                MembershipType = "Premium",
                StartDate = DateTime.UtcNow.AddMonths(-1),
                EndDate = originalEnd,
                Price = 75m,
                Status = "Active",
                IsActive = true,
                AutoRenew = true,
                Payment = new Payment
                {
                    UserId = _fixture.Api.Seed.PlayerUserId,
                    PaymentType = "Membership",
                    Amount = 225m,
                    Status = "Completed",
                    Provider = "Stripe",
                    PaymentMethod = "Stripe",
                    Currency = "bam",
                    TransactionId = $"it-membership-payment-{Guid.NewGuid():N}"
                }
            };
            var administratorMembership = new Membership
            {
                UserId = _fixture.Api.Seed.AdminUserId,
                MembershipType = "Basic",
                StartDate = DateTime.UtcNow.AddMonths(-1),
                EndDate = DateTime.UtcNow.AddDays(20),
                Price = 45m,
                Status = "Active",
                IsActive = true
            };
            database.Memberships.AddRange(playerMembership, administratorMembership);
            await database.SaveChangesAsync();
            playerMembershipId = playerMembership.Id;
            administratorMembershipId = administratorMembership.Id;
        }

        using var anonymousClient = CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymousClient.GetAsync("/Memberships/mine")).StatusCode);

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        var mineResponse = await playerClient.GetAsync("/Memberships/mine?PageSize=50&IncludeTotalCount=true");
        mineResponse.EnsureSuccessStatusCode();
        var mine = await mineResponse.Content.ReadFromJsonAsync<PagedResult<MembershipResponse>>(JsonOptions);
        Assert.NotNull(mine);
        Assert.Contains(mine.Items, membership => membership.Id == playerMembershipId);
        Assert.DoesNotContain(mine.Items, membership => membership.Id == administratorMembershipId);
        Assert.Equal(HttpStatusCode.Forbidden, (await playerClient.GetAsync("/Memberships")).StatusCode);
        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await playerClient.PutAsJsonAsync(
                $"/Memberships/{playerMembershipId}/status",
                new { Status = "Suspended", Notes = "Player must not perform a staff action." })).StatusCode);

        using var adminClient = CreateClient();
        Authorize(adminClient, _fixture.AdminSession);
        Assert.Equal(
            HttpStatusCode.BadRequest,
            (await adminClient.PostAsJsonAsync($"/Memberships/{playerMembershipId}/renew", new { Months = 0 })).StatusCode);
        Assert.Equal(
            HttpStatusCode.NoContent,
            (await adminClient.PutAsJsonAsync(
                $"/Memberships/{playerMembershipId}/status",
                new { Status = "Suspended", Notes = "Staff verification hold." })).StatusCode);
        Assert.Equal(
            HttpStatusCode.NoContent,
            (await adminClient.PostAsJsonAsync($"/Memberships/{playerMembershipId}/renew", new { Months = 3 })).StatusCode);

        var historyResponse = await playerClient.GetAsync($"/Memberships/{playerMembershipId}/history");
        historyResponse.EnsureSuccessStatusCode();
        var history = await historyResponse.Content.ReadFromJsonAsync<List<JsonElement>>(JsonOptions) ?? [];
        Assert.Contains(history, entry => entry.GetProperty("eventType").GetString() == "Suspended");
        Assert.Contains(history, entry => entry.GetProperty("eventType").GetString() == "Renewed");

        using var verificationScope = _fixture.Api.Services.CreateScope();
        var verificationDatabase = verificationScope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var persisted = await verificationDatabase.Memberships
            .Include(membership => membership.Events)
            .SingleAsync(membership => membership.Id == playerMembershipId);
        Assert.Equal("Active", persisted.Status);
        Assert.True(persisted.IsActive);
        Assert.Equal(originalEnd.AddMonths(3), persisted.EndDate);
        Assert.Null(persisted.SuspendedAt);
        Assert.Null(persisted.CancelledAt);
        Assert.Contains(persisted.Events, entry =>
            entry.EventType == "Suspended" && entry.ActorUserId == _fixture.Api.Seed.AdminUserId);
        Assert.Contains(persisted.Events, entry =>
            entry.EventType == "Renewed" && entry.ActorUserId == _fixture.Api.Seed.AdminUserId);
    }

    [Fact]
    public async Task Operations_audit_is_admin_only_and_filters_server_records()
    {
        var now = DateTime.UtcNow;
        var expectedCorrelationId = Guid.NewGuid().ToString("N");
        using (var scope = _fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            database.AuditLogs.AddRange(
                new AuditLog
                {
                    UserId = _fixture.Api.Seed.PlayerUserId,
                    Method = "PUT",
                    Path = "/Memberships/42/status",
                    StatusCode = StatusCodes.Status204NoContent,
                    IpAddress = "127.0.0.1",
                    CorrelationId = expectedCorrelationId,
                    DurationMs = 18,
                    CreatedAt = now
                },
                new AuditLog
                {
                    UserId = _fixture.Api.Seed.PlayerUserId,
                    Method = "POST",
                    Path = "/Orders/checkout",
                    StatusCode = StatusCodes.Status200OK,
                    IpAddress = "127.0.0.1",
                    CorrelationId = Guid.NewGuid().ToString("N"),
                    DurationMs = 31,
                    CreatedAt = now
                },
                new AuditLog
                {
                    UserId = _fixture.Api.Seed.AdminUserId,
                    Method = "PUT",
                    Path = "/Product/7",
                    StatusCode = StatusCodes.Status200OK,
                    IpAddress = "127.0.0.1",
                    CorrelationId = Guid.NewGuid().ToString("N"),
                    DurationMs = 22,
                    CreatedAt = now.AddDays(-2)
                });
            await database.SaveChangesAsync();
        }

        var from = Uri.EscapeDataString(now.AddMinutes(-1).ToString("O"));
        var auditUri = $"/Operations/audit?userId={_fixture.Api.Seed.PlayerUserId}&method=put&from={from}";

        using var anonymousClient = CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymousClient.GetAsync(auditUri)).StatusCode);

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        Assert.Equal(HttpStatusCode.Forbidden, (await playerClient.GetAsync(auditUri)).StatusCode);

        using var adminClient = CreateClient();
        Authorize(adminClient, _fixture.AdminSession);
        var response = await adminClient.GetAsync(auditUri);
        response.EnsureSuccessStatusCode();
        var records = await response.Content.ReadFromJsonAsync<List<JsonElement>>(JsonOptions) ?? [];
        Assert.All(records, item =>
        {
            Assert.Equal("PUT", item.GetProperty("method").GetString());
            Assert.Equal(_fixture.Api.Seed.PlayerUserId, item.GetProperty("userId").GetInt32());
        });
        var record = Assert.Single(records, item => item.GetProperty("correlationId").GetString() == expectedCorrelationId);
        Assert.Equal(_fixture.Api.Seed.PlayerUsername, record.GetProperty("userName").GetString());
        Assert.Equal(expectedCorrelationId, record.GetProperty("correlationId").GetString());
        Assert.Equal("PUT", record.GetProperty("method").GetString());
        Assert.Equal(_fixture.Api.Seed.PlayerUserId, record.GetProperty("userId").GetInt32());
        Assert.Equal("/Memberships/42/status", record.GetProperty("path").GetString());
        Assert.Equal(18, record.GetProperty("durationMs").GetInt64());
    }

    [Fact]
    public async Task Notification_delivery_diagnostics_are_admin_only_and_server_filtered()
    {
        long retryDeliveryId;
        using (var scope = _fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var notification = new Notification
            {
                Title = "Integration delivery diagnostics",
                Message = "Read-only queue contract",
                Type = "System",
                CreatedAt = DateTime.UtcNow
            };
            database.Notifications.Add(notification);
            await database.SaveChangesAsync();

            var retry = new NotificationDelivery
            {
                NotificationId = notification.Id,
                UserId = _fixture.Api.Seed.PlayerUserId,
                Channel = "Email",
                Status = "Retry",
                AttemptCount = 2,
                NextAttemptAt = DateTime.UtcNow.AddMinutes(5),
                LastError = "Integration SMTP timeout"
            };
            var sent = new NotificationDelivery
            {
                NotificationId = notification.Id,
                UserId = _fixture.Api.Seed.PlayerUserId,
                Channel = "Push",
                Status = "Sent",
                AttemptCount = 1,
                NextAttemptAt = DateTime.UtcNow,
                SentAt = DateTime.UtcNow
            };
            database.NotificationDeliveries.AddRange(retry, sent);
            await database.SaveChangesAsync();
            retryDeliveryId = retry.Id;
        }

        using var anonymousClient = CreateClient();
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await anonymousClient.GetAsync("/NotificationSettings/deliveries?status=Retry")).StatusCode);

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await playerClient.GetAsync("/NotificationSettings/deliveries?status=Retry")).StatusCode);

        using var adminClient = CreateClient();
        Authorize(adminClient, _fixture.AdminSession);
        var response = await adminClient.GetAsync("/NotificationSettings/deliveries?status=Retry");
        response.EnsureSuccessStatusCode();
        var records = await response.Content.ReadFromJsonAsync<List<JsonElement>>(JsonOptions) ?? [];
        var record = Assert.Single(records);
        Assert.Equal(retryDeliveryId, record.GetProperty("id").GetInt64());
        Assert.Equal("Email", record.GetProperty("channel").GetString());
        Assert.Equal("Retry", record.GetProperty("status").GetString());
        Assert.Equal(2, record.GetProperty("attemptCount").GetInt32());
        Assert.Equal("Integration SMTP timeout", record.GetProperty("lastError").GetString());
        Assert.Equal(JsonValueKind.Null, record.GetProperty("sentAt").ValueKind);
    }

    [Fact]
    public async Task Tournament_management_and_bracket_generation_are_admin_only_and_server_enforced()
    {
        var suffix = Guid.NewGuid().ToString("N");
        var start = DateTime.UtcNow.AddDays(14);
        var createRequest = new TournamentInsertRequest
        {
            Name = $"Integration lifecycle cup {suffix}",
            Description = "Administrator tournament workflow contract.",
            StartDate = start,
            EndDate = start.AddDays(1),
            RegistrationDeadline = start.AddDays(-3),
            MaxParticipants = 16,
            EntryFee = 30m,
            PrizeInfo = "Integration trophy"
        };

        using var anonymousClient = CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await anonymousClient.PostAsJsonAsync("/Tournament", createRequest)).StatusCode);

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await playerClient.PostAsJsonAsync("/Tournament", createRequest)).StatusCode);

        using var adminClient = CreateClient();
        Authorize(adminClient, _fixture.AdminSession);
        var create = await adminClient.PostAsJsonAsync("/Tournament", createRequest);
        create.EnsureSuccessStatusCode();
        var created = await create.Content.ReadFromJsonAsync<TournamentResponse>(JsonOptions);
        Assert.NotNull(created);
        var tournamentId = created!.Id;

        var updateRequest = new TournamentUpdateRequest
        {
            Name = $"Integration lifecycle cup updated {suffix}",
            Description = createRequest.Description,
            StartDate = createRequest.StartDate,
            EndDate = createRequest.EndDate,
            RegistrationDeadline = createRequest.RegistrationDeadline,
            MaxParticipants = createRequest.MaxParticipants,
            EntryFee = createRequest.EntryFee,
            PrizeInfo = createRequest.PrizeInfo
        };
        var update = await adminClient.PutAsJsonAsync($"/Tournament/{tournamentId}", updateRequest);
        update.EnsureSuccessStatusCode();
        var updated = await update.Content.ReadFromJsonAsync<TournamentResponse>(JsonOptions);
        Assert.NotNull(updated);
        Assert.Equal(updateRequest.Name, updated.Name);
        Assert.Equal("Upcoming", updated.Status);

        // The server, not the client, decides whether enough complete teams
        // exist. A newly created tournament cannot generate a bracket.
        Assert.Equal(HttpStatusCode.Conflict,
            (await adminClient.PostAsync($"/Tournaments/{tournamentId}/bracket/generate", content: null)).StatusCode);

        using (var scope = _fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var playerRoleId = await database.Roles
                .Where(role => role.Name == "Player")
                .Select(role => role.Id)
                .SingleAsync();
            var teammates = Enumerable.Range(1, 3)
                .Select(index => new PadelClub.Services.Database.User
                {
                    Username = $"bracket-player-{suffix}-{index}",
                    Email = $"bracket-player-{suffix}-{index}@integration.test",
                    FirstName = "Bracket",
                    LastName = $"Player {index}",
                    PasswordHash = "not-used-by-this-contract-test",
                    PasswordSalt = string.Empty,
                    IsActive = true,
                    EmailVerifiedAt = DateTime.UtcNow,
                    CreatedAt = DateTime.UtcNow
                })
                .ToList();
            database.Users.AddRange(teammates);
            database.Courts.Add(new Court
            {
                Name = $"Integration bracket court {suffix}",
                Description = "Active court required by the bracket generator.",
                IsActive = true,
                IsIndoor = true,
                HourlyRate = 40m,
                MaxPlayers = 4,
                CreatedAt = DateTime.UtcNow
            });
            await database.SaveChangesAsync();
            database.UserRoles.AddRange(teammates.Select(player => new UserRole
            {
                UserId = player.Id,
                RoleId = playerRoleId,
                DateAssigned = DateTime.UtcNow
            }));
            database.TournamentParticipants.AddRange(
                new TournamentParticipant
                {
                    TournamentId = tournamentId,
                    UserId = _fixture.Api.Seed.PlayerUserId,
                    TeamNumber = 1,
                    Status = "Confirmed",
                    ConfirmedAt = DateTime.UtcNow
                },
                new TournamentParticipant
                {
                    TournamentId = tournamentId,
                    UserId = teammates[0].Id,
                    TeamNumber = 1,
                    Status = "Confirmed",
                    ConfirmedAt = DateTime.UtcNow
                },
                new TournamentParticipant
                {
                    TournamentId = tournamentId,
                    UserId = teammates[1].Id,
                    TeamNumber = 2,
                    Status = "Confirmed",
                    ConfirmedAt = DateTime.UtcNow
                },
                new TournamentParticipant
                {
                    TournamentId = tournamentId,
                    UserId = teammates[2].Id,
                    TeamNumber = 2,
                    Status = "Confirmed",
                    ConfirmedAt = DateTime.UtcNow
                });
            await database.SaveChangesAsync();
        }

        var generated = await adminClient.PostAsync($"/Tournaments/{tournamentId}/bracket/generate", content: null);
        Assert.Equal(HttpStatusCode.NoContent, generated.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict,
            (await adminClient.PostAsync($"/Tournaments/{tournamentId}/bracket/generate", content: null)).StatusCode);

        var bracket = await adminClient.GetFromJsonAsync<List<JsonElement>>(
            $"/Tournaments/{tournamentId}/bracket", JsonOptions);
        var firstRound = Assert.Single(bracket!);
        Assert.Equal(1, firstRound.GetProperty("round").GetInt32());
        Assert.Equal("Scheduled", firstRound.GetProperty("status").GetString());
        Assert.False(firstRound.GetProperty("isBye").GetBoolean());
        Assert.Equal(2, firstRound.GetProperty("teamOne").GetArrayLength());
        Assert.Equal(2, firstRound.GetProperty("teamTwo").GetArrayLength());

        var deletable = await adminClient.PostAsJsonAsync("/Tournament", new TournamentInsertRequest
        {
            Name = $"Integration deletable cup {suffix}",
            Description = "No registrations or bracket.",
            StartDate = start.AddDays(30),
            EndDate = start.AddDays(31),
            RegistrationDeadline = start.AddDays(27),
            MaxParticipants = 8,
            EntryFee = 0m
        });
        deletable.EnsureSuccessStatusCode();
        var deletableTournament = await deletable.Content.ReadFromJsonAsync<TournamentResponse>(JsonOptions);
        Assert.NotNull(deletableTournament);
        var delete = await adminClient.DeleteAsync($"/Tournament/{deletableTournament!.Id}");
        delete.EnsureSuccessStatusCode();
        Assert.True(await delete.Content.ReadFromJsonAsync<bool>(JsonOptions));
    }

    [Fact]
    public async Task Payment_history_is_authenticated_and_owner_scoped()
    {
        int playerPaymentId;
        int administratorPaymentId;
        var paidAt = DateTime.UtcNow.AddMinutes(-10);
        using (var scope = _fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var playerPayment = new Payment
            {
                UserId = _fixture.Api.Seed.PlayerUserId,
                PaymentType = "Membership",
                Amount = 42.50m,
                PaymentMethod = "Cash",
                Status = "Completed",
                TransactionId = "IT-PAYMENT-PLAYER",
                PaymentDate = paidAt,
                CreatedAt = paidAt,
                Provider = "Manual",
                Currency = "BAM",
                RefundedAmount = 0m
            };
            var administratorPayment = new Payment
            {
                UserId = _fixture.Api.Seed.AdminUserId,
                PaymentType = "Order",
                Amount = 99.99m,
                PaymentMethod = "Card",
                Status = "Completed",
                TransactionId = "IT-PAYMENT-ADMIN",
                PaymentDate = paidAt,
                CreatedAt = paidAt,
                Provider = "Manual",
                Currency = "BAM",
                RefundedAmount = 0m
            };
            database.Payments.AddRange(playerPayment, administratorPayment);
            await database.SaveChangesAsync();
            playerPaymentId = playerPayment.Id;
            administratorPaymentId = administratorPayment.Id;
        }

        using var anonymousClient = CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await anonymousClient.GetAsync("/Payments/mine")).StatusCode);

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await playerClient.GetAsync("/Payments")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await playerClient.GetAsync($"/Payments/{administratorPaymentId}")).StatusCode);

        // A supplied user ID cannot widen an owner-scoped history request.
        var response = await playerClient.GetAsync(
            $"/Payments/mine?PageSize=200&IncludeTotalCount=true&UserId={_fixture.Api.Seed.AdminUserId}");
        response.EnsureSuccessStatusCode();
        using var history = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var items = history.RootElement.GetProperty("items").EnumerateArray().ToList();
        var record = Assert.Single(items, item => item.GetProperty("id").GetInt32() == playerPaymentId);
        Assert.DoesNotContain(items, item => item.GetProperty("id").GetInt32() == administratorPaymentId);
        Assert.Equal(_fixture.Api.Seed.PlayerUserId, record.GetProperty("userId").GetInt32());
        Assert.Equal("Membership", record.GetProperty("paymentType").GetString());
        Assert.Equal(42.50m, record.GetProperty("amount").GetDecimal());
        Assert.Equal("Completed", record.GetProperty("status").GetString());
        Assert.Equal("Manual", record.GetProperty("provider").GetString());
        Assert.Equal("BAM", record.GetProperty("currency").GetString());
    }

    [Fact]
    public async Task Recommendation_evaluator_enforces_roles_and_reports_demo_provenance()
    {
        var evaluationUri = EvaluationUri(k: 3);

        using var anonymousClient = CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymousClient.GetAsync(evaluationUri)).StatusCode);

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        Assert.Equal(HttpStatusCode.Forbidden, (await playerClient.GetAsync(evaluationUri)).StatusCode);

        using var adminClient = CreateClient();
        Authorize(adminClient, _fixture.AdminSession);
        var response = await adminClient.GetAsync(evaluationUri);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var evaluation = await response.Content.ReadFromJsonAsync<RecommendationEvaluationResponse>(JsonOptions);
        Assert.NotNull(evaluation);
        Assert.False(evaluation.IsAvailable);
        Assert.Equal(0, evaluation.Cohort.DeliveredOrders);
        Assert.Equal(1, evaluation.Cohort.ExcludedSeededDemoOrders);
        Assert.Null(evaluation.CollaborativeFiltering.PrecisionAtK);
        Assert.Null(evaluation.PopularityBaseline.PrecisionAtK);
    }

    [Fact]
    public async Task Recommendation_evaluator_rejects_missing_invalid_and_future_windows()
    {
        using var client = CreateClient();
        Authorize(client, _fixture.AdminSession);

        Assert.Equal(HttpStatusCode.BadRequest,
            (await client.GetAsync("/Operations/recommendations/evaluation")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await client.GetAsync(EvaluationUri(k: 13))).StatusCode);

        var futureCutoff = DateTimeOffset.UtcNow.AddDays(-1).ToString("O");
        var futureEnd = DateTimeOffset.UtcNow.AddDays(1).ToString("O");
        var futureUri = "/Operations/recommendations/evaluation?cutoffUtc=" + Uri.EscapeDataString(futureCutoff) +
                        "&endUtc=" + Uri.EscapeDataString(futureEnd) + "&k=3";
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync(futureUri)).StatusCode);
    }

    [Fact]
    public async Task Administrator_can_persist_and_retrieve_an_immutable_operational_evaluation_snapshot()
    {
        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        var request = new RecommendationEvaluationRequest
        {
            CutoffUtc = _fixture.Api.Seed.EvaluationCutoffUtc,
            EndUtc = _fixture.Api.Seed.EvaluationEndUtc,
            K = 3
        };
        Assert.Equal(HttpStatusCode.Forbidden,
            (await playerClient.PostAsJsonAsync("/Operations/recommendations/evaluation/runs", request)).StatusCode);

        using var adminClient = CreateClient();
        Authorize(adminClient, _fixture.AdminSession);
        var create = await adminClient.PostAsJsonAsync(
            "/Operations/recommendations/evaluation/runs",
            request);
        Assert.Equal(HttpStatusCode.Created, create.StatusCode);

        var run = await create.Content.ReadFromJsonAsync<RecommendationEvaluationRunResponse>(JsonOptions);
        Assert.NotNull(run);
        Assert.NotEqual(Guid.Empty, run.RunId);
        Assert.Equal(_fixture.Api.Seed.AdminUserId, run.ExecutedByUserId);
        Assert.Equal("Operational", run.EvidenceSource);
        Assert.Equal("Unavailable", run.EvidenceTier);
        Assert.Equal(run.InputFingerprintSha256, run.Report.InputFingerprintSha256);
        Assert.Equal(run.ConfigurationSha256, run.Report.ConfigurationSha256);
        Assert.Equal(0, run.Report.Cohort.DeliveredOrders);

        var byId = await adminClient.GetFromJsonAsync<RecommendationEvaluationRunResponse>(
            $"/Operations/recommendations/evaluation/runs/{run.RunId}",
            JsonOptions);
        var latest = await adminClient.GetFromJsonAsync<RecommendationEvaluationRunResponse>(
            "/Operations/recommendations/evaluation/runs/latest",
            JsonOptions);
        Assert.NotNull(byId);
        Assert.NotNull(latest);
        Assert.Equal(run.RunId, byId.RunId);
        Assert.Equal(run.RunId, latest.RunId);

        using var scope = _fixture.Api.Services.CreateScope();
        var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var stored = await database.RecommendationEvaluationRuns.SingleAsync(item => item.RunId == run.RunId);
        stored.EvidenceTier = "Qualified";
        await Assert.ThrowsAsync<InvalidOperationException>(() => database.SaveChangesAsync());
    }

    [Fact]
    public async Task Inventory_adjustment_requires_an_admin_and_persists_a_transactional_audit_row()
    {
        var endpoint = $"/Commerce/inventory/{_fixture.Api.Seed.InventoryProductId}/adjust";
        var adjustment = new { quantityChange = 3, reason = "Exam stock correction" };

        int stockBeforeAdjustment;
        using (var initialScope = _fixture.Api.Services.CreateScope())
        {
            var initialDatabase = initialScope.ServiceProvider.GetRequiredService<PadelClubContext>();
            stockBeforeAdjustment = await initialDatabase.Products
                .Where(product => product.Id == _fixture.Api.Seed.InventoryProductId)
                .Select(product => product.StockQuantity)
                .SingleAsync();
        }

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await playerClient.PostAsJsonAsync(endpoint, adjustment)).StatusCode);

        using var adminClient = CreateClient();
        Authorize(adminClient, _fixture.AdminSession);
        Assert.Equal(HttpStatusCode.NoContent,
            (await adminClient.PostAsJsonAsync(endpoint, adjustment)).StatusCode);

        using var scope = _fixture.Api.Services.CreateScope();
        var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var product = await database.Products.SingleAsync(x => x.Id == _fixture.Api.Seed.InventoryProductId);
        var movement = await database.InventoryMovements.SingleAsync(x =>
            x.ProductId == _fixture.Api.Seed.InventoryProductId && x.ReferenceType == "Adjustment");

        Assert.Equal(stockBeforeAdjustment + 3, product.StockQuantity);
        Assert.Equal(3, movement.QuantityChange);
        Assert.Equal(product.StockQuantity, movement.BalanceAfter);
        Assert.Equal(_fixture.Api.Seed.AdminUserId, movement.ActorUserId);
        Assert.Equal("Exam stock correction", movement.Reason);
    }

    [Fact]
    public async Task Return_eligible_orders_are_owner_scoped_windowed_and_subtract_non_rejected_quantities()
    {
        var suffix = Guid.NewGuid().ToString("N");
        var now = DateTime.UtcNow;
        var deliveredAt = now.AddDays(-2);
        var otherUsername = $"return-other-{suffix}";
        int ownEligibleOrderId;
        int ownOldOrderId;
        int ownFullyReservedOrderId;
        int otherEligibleOrderId;
        int partiallyReturnableLineId;
        int oldLineId;

        using (var scope = _fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var otherUser = new PadelClub.Services.Database.User
            {
                Username = otherUsername,
                Email = $"{otherUsername}@integration.test",
                FirstName = "Other",
                LastName = "Return Customer",
                PasswordHash = new PadelClub.Services.PasswordHasher().HashPassword(_fixture.Api.Seed.Password),
                PasswordSalt = string.Empty,
                IsActive = true,
                EmailVerifiedAt = now,
                CreatedAt = now
            };
            var ownEligibleOrder = DeliveredOrderForReturnTest(
                _fixture.Api.Seed.PlayerUserId,
                $"IT-RETURN-OWN-{suffix}",
                deliveredAt,
                totalAmount: 500m);
            var ownOldOrder = DeliveredOrderForReturnTest(
                _fixture.Api.Seed.PlayerUserId,
                $"IT-RETURN-OLD-{suffix}",
                now.AddDays(-31),
                totalAmount: 100m);
            var ownFullyReservedOrder = DeliveredOrderForReturnTest(
                _fixture.Api.Seed.PlayerUserId,
                $"IT-RETURN-FULL-{suffix}",
                deliveredAt,
                totalAmount: 100m);
            var otherEligibleOrder = DeliveredOrderForReturnTest(
                userId: 0,
                orderNumber: $"IT-RETURN-OTHER-{suffix}",
                deliveredAt: deliveredAt,
                totalAmount: 100m);

            database.AddRange(otherUser, ownEligibleOrder, ownOldOrder, ownFullyReservedOrder);
            await database.SaveChangesAsync();
            otherEligibleOrder.UserId = otherUser.Id;
            database.Orders.Add(otherEligibleOrder);
            await database.SaveChangesAsync();

            var partiallyReturnableLine = ReturnTestOrderItem(
                ownEligibleOrder.Id,
                _fixture.Api.Seed.OwnedProductId,
                quantity: 5,
                unitPrice: 100m);
            var oldLine = ReturnTestOrderItem(
                ownOldOrder.Id,
                _fixture.Api.Seed.OwnedProductId,
                quantity: 1,
                unitPrice: 100m);
            var fullyReservedLine = ReturnTestOrderItem(
                ownFullyReservedOrder.Id,
                _fixture.Api.Seed.OwnedProductId,
                quantity: 1,
                unitPrice: 100m);
            var otherLine = ReturnTestOrderItem(
                otherEligibleOrder.Id,
                _fixture.Api.Seed.OwnedProductId,
                quantity: 1,
                unitPrice: 100m);
            database.OrderItems.AddRange(partiallyReturnableLine, oldLine, fullyReservedLine, otherLine);
            await database.SaveChangesAsync();

            var requested = new ReturnRequest
            {
                OrderId = ownEligibleOrder.Id,
                UserId = _fixture.Api.Seed.PlayerUserId,
                Reason = "Two items are the wrong size.",
                Status = "Requested",
                RefundAmount = 200m,
                CreatedAt = now
            };
            var approved = new ReturnRequest
            {
                OrderId = ownEligibleOrder.Id,
                UserId = _fixture.Api.Seed.PlayerUserId,
                Reason = "One item arrived damaged.",
                Status = "Approved",
                RefundAmount = 100m,
                CreatedAt = now,
                ResolvedAt = now
            };
            var rejected = new ReturnRequest
            {
                OrderId = ownEligibleOrder.Id,
                UserId = _fixture.Api.Seed.PlayerUserId,
                Reason = "Rejected requests restore the available quantity.",
                Status = "Rejected",
                RefundAmount = 100m,
                CreatedAt = now,
                ResolvedAt = now
            };
            var fullyReserved = new ReturnRequest
            {
                OrderId = ownFullyReservedOrder.Id,
                UserId = _fixture.Api.Seed.PlayerUserId,
                Reason = "This line is already covered by a pending return.",
                Status = "Requested",
                RefundAmount = 100m,
                CreatedAt = now
            };
            database.ReturnRequests.AddRange(requested, approved, rejected, fullyReserved);
            await database.SaveChangesAsync();
            database.ReturnRequestItems.AddRange(
                new ReturnRequestItem { ReturnRequestId = requested.Id, OrderItemId = partiallyReturnableLine.Id, Quantity = 2, RefundAmount = 200m },
                new ReturnRequestItem { ReturnRequestId = approved.Id, OrderItemId = partiallyReturnableLine.Id, Quantity = 1, RefundAmount = 100m },
                new ReturnRequestItem { ReturnRequestId = rejected.Id, OrderItemId = partiallyReturnableLine.Id, Quantity = 1, RefundAmount = 100m },
                new ReturnRequestItem { ReturnRequestId = fullyReserved.Id, OrderItemId = fullyReservedLine.Id, Quantity = 1, RefundAmount = 100m });
            await database.SaveChangesAsync();

            ownEligibleOrderId = ownEligibleOrder.Id;
            ownOldOrderId = ownOldOrder.Id;
            ownFullyReservedOrderId = ownFullyReservedOrder.Id;
            otherEligibleOrderId = otherEligibleOrder.Id;
            partiallyReturnableLineId = partiallyReturnableLine.Id;
            oldLineId = oldLine.Id;
        }

        using var anonymousClient = CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await anonymousClient.GetAsync("/Commerce/returns/eligible-orders/mine")).StatusCode);

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        var playerOrders = await playerClient.GetFromJsonAsync<List<EligibleReturnOrderResponse>>(
            "/Commerce/returns/eligible-orders/mine",
            JsonOptions);
        Assert.NotNull(playerOrders);

        var ownOrder = Assert.Single(playerOrders!, order => order.OrderId == ownEligibleOrderId);
        var ownLine = Assert.Single(ownOrder.Items);
        Assert.Equal(partiallyReturnableLineId, ownLine.OrderItemId);
        Assert.Equal("Integration Control Racket", ownLine.ProductName);
        Assert.Equal(5, ownLine.Quantity);
        Assert.Equal(2, ownLine.RemainingReturnableQuantity);
        Assert.Equal(100m, ownLine.UnitPrice);
        Assert.Equal(500m, ownLine.LineTotal);
        Assert.Equal(ownOrder.DeliveredAt.AddDays(30), ownOrder.ReturnWindowEndsAt);
        Assert.DoesNotContain(playerOrders, order => order.OrderId == ownOldOrderId);
        Assert.DoesNotContain(playerOrders, order => order.OrderId == ownFullyReservedOrderId);
        Assert.DoesNotContain(playerOrders, order => order.OrderId == otherEligibleOrderId);

        using var otherClient = CreateClient();
        Authorize(otherClient, await LoginAsync(otherClient, otherUsername));
        var otherOrders = await otherClient.GetFromJsonAsync<List<EligibleReturnOrderResponse>>(
            "/Commerce/returns/eligible-orders/mine",
            JsonOptions);
        Assert.NotNull(otherOrders);
        Assert.Contains(otherOrders!, order => order.OrderId == otherEligibleOrderId);
        Assert.DoesNotContain(otherOrders!, order => order.OrderId == ownEligibleOrderId);

        var oldReturnAttempt = await playerClient.PostAsJsonAsync("/Commerce/returns", new
        {
            orderId = ownOldOrderId,
            reason = "This delivered order is outside the shared return window.",
            items = new[] { new { orderItemId = oldLineId, quantity = 1 } }
        });
        Assert.Equal(HttpStatusCode.Conflict, oldReturnAttempt.StatusCode);
    }

    [Fact]
    public async Task Return_requests_serialize_line_reservations_and_reject_overflowed_quantities()
    {
        var suffix = Guid.NewGuid().ToString("N");
        int orderId;
        int lineId;

        using (var scope = _fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var order = DeliveredOrderForReturnTest(
                _fixture.Api.Seed.PlayerUserId,
                $"IT-RETURN-RACE-{suffix}",
                DateTime.UtcNow.AddMinutes(-5),
                totalAmount: 1m);
            database.Orders.Add(order);
            await database.SaveChangesAsync();

            var line = ReturnTestOrderItem(order.Id, _fixture.Api.Seed.OwnedProductId, quantity: 1, unitPrice: 1m);
            database.OrderItems.Add(line);
            await database.SaveChangesAsync();
            orderId = order.Id;
            lineId = line.Id;
        }

        using var firstClient = CreateClient();
        using var secondClient = CreateClient();
        Authorize(firstClient, _fixture.PlayerSession);
        Authorize(secondClient, _fixture.PlayerSession);
        var request = new
        {
            orderId,
            reason = "Concurrent reservation integrity check.",
            items = new[] { new { orderItemId = lineId, quantity = 1 } }
        };

        var responses = await Task.WhenAll(
            firstClient.PostAsJsonAsync("/Commerce/returns", request),
            secondClient.PostAsJsonAsync("/Commerce/returns", request));

        Assert.Single(responses, response => response.StatusCode == HttpStatusCode.OK);
        Assert.Single(responses, response => response.StatusCode == HttpStatusCode.BadRequest);

        var overflow = await firstClient.PostAsJsonAsync("/Commerce/returns", new
        {
            orderId,
            reason = "Overflowed duplicate quantities must be rejected safely.",
            items = new[]
            {
                new { orderItemId = lineId, quantity = int.MaxValue },
                new { orderItemId = lineId, quantity = int.MaxValue }
            }
        });
        Assert.Equal(HttpStatusCode.BadRequest, overflow.StatusCode);

        using var verificationScope = _fixture.Api.Services.CreateScope();
        var verificationDatabase = verificationScope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var requests = await verificationDatabase.ReturnRequests
            .Include(returnRequest => returnRequest.Items)
            .Where(returnRequest => returnRequest.OrderId == orderId)
            .ToListAsync();
        var saved = Assert.Single(requests);
        Assert.Equal(1, Assert.Single(saved.Items).Quantity);
    }

    [Fact]
    public async Task Concurrent_admin_return_approvals_claim_one_requested_return_and_restock_once()
    {
        var suffix = Guid.NewGuid().ToString("N");
        const int returnedQuantity = 2;
        int returnRequestId;
        int productId;
        int startingStock;

        using (var scope = _fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var product = await database.Products.SingleAsync(x => x.Id == _fixture.Api.Seed.OwnedProductId);
            productId = product.Id;
            startingStock = product.StockQuantity;

            var order = DeliveredOrderForReturnTest(
                _fixture.Api.Seed.PlayerUserId,
                $"IT-RETURN-RESOLVE-RACE-{suffix}",
                DateTime.UtcNow.AddMinutes(-5),
                totalAmount: 200m);
            database.Orders.Add(order);
            await database.SaveChangesAsync();

            var line = ReturnTestOrderItem(order.Id, productId, returnedQuantity, unitPrice: 100m);
            database.OrderItems.Add(line);
            await database.SaveChangesAsync();

            var returnRequest = new ReturnRequest
            {
                OrderId = order.Id,
                UserId = _fixture.Api.Seed.PlayerUserId,
                Reason = "Concurrent administrators must only approve this return once.",
                Status = "Requested",
                RefundAmount = 200m,
                CreatedAt = DateTime.UtcNow
            };
            database.ReturnRequests.Add(returnRequest);
            await database.SaveChangesAsync();
            database.ReturnRequestItems.Add(new ReturnRequestItem
            {
                ReturnRequestId = returnRequest.Id,
                OrderItemId = line.Id,
                Quantity = returnedQuantity,
                RefundAmount = 200m
            });
            await database.SaveChangesAsync();
            returnRequestId = returnRequest.Id;
        }

        using var firstAdminClient = CreateClient();
        using var secondAdminClient = CreateClient();
        Authorize(firstAdminClient, _fixture.AdminSession);
        Authorize(secondAdminClient, _fixture.AdminSession);
        var request = new
        {
            approve = true,
            adminNotes = "Concurrent approval integrity test."
        };

        var responses = await Task.WhenAll(
            firstAdminClient.PutAsJsonAsync($"/Commerce/returns/{returnRequestId}/resolve", request),
            secondAdminClient.PutAsJsonAsync($"/Commerce/returns/{returnRequestId}/resolve", request));

        Assert.Single(responses, response => response.StatusCode == HttpStatusCode.NoContent);
        Assert.Single(responses, response => response.StatusCode == HttpStatusCode.Conflict);

        using var verificationScope = _fixture.Api.Services.CreateScope();
        var verificationDatabase = verificationScope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var savedReturn = await verificationDatabase.ReturnRequests
            .Include(returnRequest => returnRequest.Items)
            .SingleAsync(returnRequest => returnRequest.Id == returnRequestId);
        var productAfterApproval = await verificationDatabase.Products.SingleAsync(product => product.Id == productId);
        var movements = await verificationDatabase.InventoryMovements
            .Where(movement => movement.ReferenceType == "Return" && movement.ReferenceId == returnRequestId)
            .ToListAsync();

        Assert.Equal("Approved", savedReturn.Status);
        Assert.NotNull(savedReturn.ResolvedAt);
        Assert.True(Assert.Single(savedReturn.Items).Restocked);
        Assert.Equal(startingStock + returnedQuantity, productAfterApproval.StockQuantity);
        var movement = Assert.Single(movements);
        Assert.Equal(returnedQuantity, movement.QuantityChange);
        Assert.Equal(productAfterApproval.StockQuantity, movement.BalanceAfter);
    }

    [Fact]
    public async Task Return_requests_exclude_future_deliveries_and_allocate_fractional_refunds_without_overrun()
    {
        var suffix = Guid.NewGuid().ToString("N");
        int futureOrderId;
        int futureLineId;
        int fractionalOrderId;
        int fractionalLineId;

        using (var scope = _fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var futureOrder = DeliveredOrderForReturnTest(
                _fixture.Api.Seed.PlayerUserId,
                $"IT-RETURN-FUTURE-{suffix}",
                DateTime.UtcNow.AddHours(1),
                totalAmount: 1m);
            var fractionalOrder = DeliveredOrderForReturnTest(
                _fixture.Api.Seed.PlayerUserId,
                $"IT-RETURN-CENTS-{suffix}",
                DateTime.UtcNow.AddMinutes(-5),
                totalAmount: 0.02m);
            fractionalOrder.SubtotalAmount = 0.03m;
            database.Orders.AddRange(futureOrder, fractionalOrder);
            await database.SaveChangesAsync();

            var futureLine = ReturnTestOrderItem(futureOrder.Id, _fixture.Api.Seed.OwnedProductId, quantity: 1, unitPrice: 1m);
            var fractionalLine = ReturnTestOrderItem(fractionalOrder.Id, _fixture.Api.Seed.OwnedProductId, quantity: 3, unitPrice: 0.01m);
            database.OrderItems.AddRange(futureLine, fractionalLine);
            await database.SaveChangesAsync();
            futureOrderId = futureOrder.Id;
            futureLineId = futureLine.Id;
            fractionalOrderId = fractionalOrder.Id;
            fractionalLineId = fractionalLine.Id;
        }

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);

        var eligibleOrders = await playerClient.GetFromJsonAsync<List<EligibleReturnOrderResponse>>(
            "/Commerce/returns/eligible-orders/mine",
            JsonOptions);
        Assert.NotNull(eligibleOrders);
        Assert.DoesNotContain(eligibleOrders!, order => order.OrderId == futureOrderId);

        var futureReturn = await playerClient.PostAsJsonAsync("/Commerce/returns", new
        {
            orderId = futureOrderId,
            reason = "Future delivery timestamps cannot be returned yet.",
            items = new[] { new { orderItemId = futureLineId, quantity = 1 } }
        });
        Assert.Equal(HttpStatusCode.Conflict, futureReturn.StatusCode);

        for (var attempt = 0; attempt < 3; attempt++)
        {
            var response = await playerClient.PostAsJsonAsync("/Commerce/returns", new
            {
                orderId = fractionalOrderId,
                reason = $"Fractional refund request number {attempt + 1}.",
                items = new[] { new { orderItemId = fractionalLineId, quantity = 1 } }
            });
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }

        using var verificationScope = _fixture.Api.Services.CreateScope();
        var verificationDatabase = verificationScope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var savedRequests = await verificationDatabase.ReturnRequests
            .Include(returnRequest => returnRequest.Items)
            .Where(returnRequest => returnRequest.OrderId == fractionalOrderId)
            .OrderBy(returnRequest => returnRequest.Id)
            .ToListAsync();

        Assert.Equal(3, savedRequests.Count);
        Assert.Equal(0.02m, savedRequests.Sum(returnRequest => returnRequest.RefundAmount));
        Assert.Equal(0.02m, savedRequests.SelectMany(returnRequest => returnRequest.Items).Sum(item => item.RefundAmount));
        Assert.Equal(new[] { 0.01m, 0.01m, 0m }, savedRequests.Select(returnRequest => returnRequest.RefundAmount).ToArray());
    }

    [Fact]
    public async Task Player_profile_requires_a_reference_city_and_returns_its_name()
    {
        using var client = CreateClient();
        Authorize(client, _fixture.PlayerSession);
        using var cities = JsonDocument.Parse(await client.GetStringAsync("/PlayerExperience/cities"));
        var city = cities.RootElement.EnumerateArray().First();
        var request = new PlayerProfileRequest("Beginner", "Either", city.GetProperty("id").GetInt32(), "", "", true);
        var invalid = await client.PutAsJsonAsync("/PlayerExperience/profile/mine", request with { CityId = int.MaxValue });
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
        var saved = await client.PutAsJsonAsync("/PlayerExperience/profile/mine", request);
        saved.EnsureSuccessStatusCode();
        using var profile = JsonDocument.Parse(await saved.Content.ReadAsStringAsync());
        Assert.Equal(city.GetProperty("name").GetString(), profile.RootElement.GetProperty("city").GetString());
        Assert.Equal(request.CityId, profile.RootElement.GetProperty("cityId").GetInt32());
    }

    [Fact]
    public async Task Concurrent_checkout_returns_one_order_and_decrements_stock_once()
    {
        using var client = CreateClient();
        Authorize(client, _fixture.PlayerSession);
        using var scope = _fixture.Api.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var productId = _fixture.Api.Seed.OwnedProductId;
        var stockBefore = await db.Products.Where(x => x.Id == productId).Select(x => x.StockQuantity).SingleAsync();
        var request = new CheckoutRequest
        {
            IdempotencyKey = Guid.NewGuid().ToString("N"),
            RecipientName = "Concurrent customer", PhoneNumber = "+38761123456",
            ShippingAddress = "Test street 12", City = "Sarajevo", PostalCode = "71000",
            Items = [new CheckoutLineRequest { ProductId = productId, Quantity = 1 }]
        };
        var responses = await Task.WhenAll(Enumerable.Range(0, 8)
            .Select(_ => client.PostAsJsonAsync("/Orders/checkout", request)));
        var orderIds = new List<int>();
        foreach (var response in responses)
        {
            response.EnsureSuccessStatusCode();
            orderIds.Add((await response.Content.ReadFromJsonAsync<OrderResponse>(JsonOptions))!.Id);
            response.Dispose();
        }
        var orderId = Assert.Single(orderIds.Distinct());
        Assert.Equal(1, await db.Orders.CountAsync(x => x.IdempotencyKey == request.IdempotencyKey));
        Assert.Equal(stockBefore - 1, await db.Products.Where(x => x.Id == productId).Select(x => x.StockQuantity).SingleAsync());
        Assert.Equal(1, await db.InventoryMovements.CountAsync(x => x.ReferenceType == "Order" && x.ReferenceId == orderId));
    }

    [Fact]
    public async Task Player_checkout_is_tagged_as_customer_checkout_evidence_at_write_time()
    {
        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        var checkout = await playerClient.PostAsJsonAsync("/Orders/checkout", new CheckoutRequest
        {
            IdempotencyKey = "evidence-checkout-001",
            RecipientName = "Šaćir Čengić",
            PhoneNumber = "+38761123456",
            ShippingAddress = "Ulica Žrtava fašizma 12, Đačka zgrada",
            City = "Čapljina",
            PostalCode = "71000",
            Notes = "Sačuvajte račun. Pozvonite kod Đurić: č ć š ž đ Č Ć Š Ž Đ.",
            Items =
            [
                new CheckoutLineRequest
                {
                    ProductId = _fixture.Api.Seed.OwnedProductId,
                    Quantity = 1
                }
            ]
        });
        checkout.EnsureSuccessStatusCode();

        var response = await checkout.Content.ReadFromJsonAsync<OrderResponse>(JsonOptions);
        Assert.NotNull(response);
        using var scope = _fixture.Api.Services.CreateScope();
        var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var persisted = await database.Orders
            .Include(order => order.OrderItems)
            .SingleAsync(order => order.OrderNumber == response.OrderNumber);

        Assert.Equal(OrderOrigin.CustomerCheckout, persisted.Origin);
        Assert.False(persisted.IsSeededForDemo);
        Assert.Equal(_fixture.Api.Seed.PlayerUserId, persisted.UserId);
        Assert.Single(persisted.OrderItems);
        Assert.Equal("Šaćir Čengić", persisted.RecipientName);
        Assert.Equal("Ulica Žrtava fašizma 12, Đačka zgrada", persisted.ShippingAddress);
        Assert.Equal("Čapljina", persisted.City);
        Assert.Equal("Sačuvajte račun. Pozvonite kod Đurić: č ć š ž đ Č Ć Š Ž Đ.", persisted.Notes);
        Assert.Equal(persisted.RecipientName, response.RecipientName);
        Assert.Equal(persisted.ShippingAddress, response.ShippingAddress);
        Assert.Equal(persisted.City, response.City);
        Assert.Equal(persisted.Notes, response.Notes);
    }

    [Fact]
    public async Task Checkout_reports_clear_errors_for_each_missing_delivery_field()
    {
        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession);
        var response = await playerClient.PostAsJsonAsync("/Orders/checkout", new CheckoutRequest());
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var errors = json.RootElement.GetProperty("errors");
        Assert.Contains("Enter the recipient name.", errors.GetProperty("RecipientName").EnumerateArray().Select(x => x.GetString()));
        Assert.Contains("Enter a phone number.", errors.GetProperty("PhoneNumber").EnumerateArray().Select(x => x.GetString()));
        Assert.Contains("Enter the street address.", errors.GetProperty("ShippingAddress").EnumerateArray().Select(x => x.GetString()));
        Assert.Contains("Enter the city.", errors.GetProperty("City").EnumerateArray().Select(x => x.GetString()));
        Assert.Contains("Enter the postal code.", errors.GetProperty("PostalCode").EnumerateArray().Select(x => x.GetString()));
    }

    [Fact]
    public async Task Draft_product_update_persists_a_pending_outbox_message_in_the_same_database()
    {
        using var adminClient = CreateClient();
        Authorize(adminClient, _fixture.AdminSession);
        var request = new ProductUpdateRequest
        {
            Name = "Integration Draft Racket Updated",
            Description = "Outbox HTTP integration proof",
            Price = 111m,
            StockQuantity = 9
        };

        var update = await adminClient.PutAsJsonAsync(
            $"/Product/{_fixture.Api.Seed.DraftProductId}",
            request);
        update.EnsureSuccessStatusCode();

        using var scope = _fixture.Api.Services.CreateScope();
        var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var product = await database.Products.SingleAsync(product => product.Id == _fixture.Api.Seed.DraftProductId);
        var outbox = await database.OutboxMessages.SingleAsync(message =>
            message.Type == OutboxMessageTypes.ProductUpdated);
        Assert.Equal("Integration Draft Racket Updated", product.Name);
        Assert.Null(outbox.PublishedAtUtc);
        Assert.Equal(0, outbox.AttemptCount);
        Assert.Contains("Integration Draft Racket Updated", outbox.Payload, StringComparison.Ordinal);
    }

    private HttpClient CreateClient() => _fixture.Api.CreateClient(new WebApplicationFactoryClientOptions
    {
        BaseAddress = new Uri("https://localhost")
    });

    private async Task<AuthResponse> LoginAsync(HttpClient client, string username)
    {
        var response = await client.PostAsJsonAsync("/Users/login", new UserLoginRequest
        {
            Username = username,
            Password = _fixture.Api.Seed.Password
        });
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<AuthResponse>(JsonOptions))!;
    }

    private string EvaluationUri(int k)
    {
        var cutoff = Uri.EscapeDataString(_fixture.Api.Seed.EvaluationCutoffUtc.ToString("O"));
        var end = Uri.EscapeDataString(_fixture.Api.Seed.EvaluationEndUtc.ToString("O"));
        return $"/Operations/recommendations/evaluation?cutoffUtc={cutoff}&endUtc={end}&k={k}";
    }

    private static void Authorize(HttpClient client, AuthResponse session) =>
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);

    private OrderUpdateRequest FulfillmentUpdate(string orderNumber, string status) => new()
    {
        UserId = _fixture.Api.Seed.PlayerUserId,
        OrderNumber = orderNumber,
        TotalAmount = 100m,
        Status = status,
        ShippingAddress = "Integration Street 1",
        Notes = "Order lifecycle integration test"
    };

    private static Order DeliveredOrderForReturnTest(int userId, string orderNumber, DateTime deliveredAt, decimal totalAmount) => new()
    {
        UserId = userId,
        OrderNumber = orderNumber,
        Status = "Delivered",
        RecipientName = "Integration Return Customer",
        PhoneNumber = "+38760000000",
        ShippingAddress = "Integration Street 1",
        City = "Sarajevo",
        PostalCode = "71000",
        TotalAmount = totalAmount,
        SubtotalAmount = totalAmount,
        CreatedAt = deliveredAt,
        DeliveredAt = deliveredAt,
        Origin = OrderOrigin.IntegrationTest
    };

    private static OrderItem ReturnTestOrderItem(int orderId, int productId, int quantity, decimal unitPrice) => new()
    {
        OrderId = orderId,
        ProductId = productId,
        Quantity = quantity,
        UnitPrice = unitPrice,
        TotalPrice = unitPrice * quantity,
        CreatedAt = DateTime.UtcNow
    };
}
