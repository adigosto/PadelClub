using Microsoft.EntityFrameworkCore;

namespace PadelClub.Services.Database
{
    public class PadelClubContext : DbContext
    {
        public PadelClubContext(DbContextOptions<PadelClubContext> options) : base(options)
        {
        }

        // Core Entities
        public DbSet<User> Users { get; set; } = null!;
        public DbSet<Role> Roles { get; set; } = null!;
        public DbSet<UserRole> UserRoles { get; set; } = null!;
        public DbSet<Court> Courts { get; set; } = null!;
        public DbSet<Reservation> Reservations { get; set; } = null!;
        public DbSet<Product> Products { get; set; } = null!;
        public DbSet<Membership> Memberships { get; set; } = null!;
        public DbSet<MembershipTypeReference> MembershipTypeReferences { get; set; } = null!;
        public DbSet<Payment> Payments { get; set; } = null!;
        public DbSet<Tournament> Tournaments { get; set; } = null!;
        public DbSet<Match> Matches { get; set; } = null!;
        public DbSet<MatchParticipant> MatchParticipants { get; set; } = null!;
        public DbSet<TournamentParticipant> TournamentParticipants { get; set; } = null!;
        public DbSet<Order> Orders { get; set; } = null!;
        public DbSet<OrderItem> OrderItems { get; set; } = null!;
        public DbSet<Asset> Assets { get; set; } = null!;
        public DbSet<ProductCategory> ProductCategories { get; set; } = null!;
        public DbSet<ProductType> ProductTypes { get; set; } = null!;
        public DbSet<Notification> Notifications { get; set; } = null!;
        public DbSet<NotificationRecipient> NotificationRecipients { get; set; } = null!;
        public DbSet<ClubReview> ClubReviews { get; set; } = null!;
        public DbSet<AuthToken> AuthTokens { get; set; } = null!;
        public DbSet<MaintenanceBlock> MaintenanceBlocks { get; set; } = null!;
        public DbSet<WaitlistEntry> WaitlistEntries { get; set; } = null!;
        public DbSet<AccountCredit> AccountCredits { get; set; } = null!;
        public DbSet<StripeWebhookEvent> StripeWebhookEvents { get; set; } = null!;
        public DbSet<ProviderRefundOperation> ProviderRefundOperations { get; set; } = null!;
        public DbSet<NotificationPreference> NotificationPreferences { get; set; } = null!;
        public DbSet<PushDevice> PushDevices { get; set; } = null!;
        public DbSet<NotificationDelivery> NotificationDeliveries { get; set; } = null!;
        public DbSet<PlayerProfile> PlayerProfiles { get; set; } = null!;
        public DbSet<City> Cities { get; set; } = null!;
        public DbSet<PartnerInvitation> PartnerInvitations { get; set; } = null!;
        public DbSet<MembershipEvent> MembershipEvents { get; set; } = null!;
        public DbSet<InventoryMovement> InventoryMovements { get; set; } = null!;
        public DbSet<Coupon> Coupons { get; set; } = null!;
        public DbSet<CouponRedemption> CouponRedemptions { get; set; } = null!;
        public DbSet<ReturnRequest> ReturnRequests { get; set; } = null!;
        public DbSet<ReturnRequestItem> ReturnRequestItems { get; set; } = null!;
        public DbSet<AuditLog> AuditLogs { get; set; } = null!;
        public DbSet<PrivacyRequest> PrivacyRequests { get; set; } = null!;
        public DbSet<RecommendationEvaluationRun> RecommendationEvaluationRuns { get; set; } = null!;
        public DbSet<RecommendationAnalyticsConsent> RecommendationAnalyticsConsents { get; set; } = null!;
        public DbSet<RecommendationExperiment> RecommendationExperiments { get; set; } = null!;
        public DbSet<RecommendationExperimentAssignment> RecommendationExperimentAssignments { get; set; } = null!;
        public DbSet<RecommendationExperimentAnalysisRun> RecommendationExperimentAnalysisRuns { get; set; } = null!;
        public DbSet<RecommendationExposure> RecommendationExposures { get; set; } = null!;
        public DbSet<ProviderVerificationAttempt> ProviderVerificationAttempts { get; set; } = null!;
        public DbSet<OutboxMessage> OutboxMessages { get; set; } = null!;
        public DbSet<InboxMessage> InboxMessages { get; set; } = null!;

        public override int SaveChanges(bool acceptAllChangesOnSuccess)
        {
            EnsureRecommendationEvidenceIsAppendOnly();
            return base.SaveChanges(acceptAllChangesOnSuccess);
        }

        public override Task<int> SaveChangesAsync(
            bool acceptAllChangesOnSuccess,
            CancellationToken cancellationToken = default)
        {
            EnsureRecommendationEvidenceIsAppendOnly();
            return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            ConfigureUser(modelBuilder);
            ConfigureRole(modelBuilder);
            ConfigureUserRole(modelBuilder);
            ConfigureCourt(modelBuilder);
            ConfigureReservation(modelBuilder);
            ConfigureProduct(modelBuilder);
            ConfigureMembership(modelBuilder);
            ConfigurePayment(modelBuilder);
            ConfigureTournament(modelBuilder);
            ConfigureMatch(modelBuilder);
            ConfigureMatchParticipant(modelBuilder);
            ConfigureTournamentParticipant(modelBuilder);
            ConfigureOrder(modelBuilder);
            ConfigureOrderItem(modelBuilder);
            ConfigureAsset(modelBuilder);
            ConfigureProductCategory(modelBuilder);
            ConfigureProductType(modelBuilder);
            ConfigureNotification(modelBuilder);
            ConfigureNotificationRecipient(modelBuilder);
            ConfigureClubReview(modelBuilder);
            ConfigureAuthToken(modelBuilder);
            ConfigureBookingLifecycle(modelBuilder);
            ConfigureStripePayments(modelBuilder);
            ConfigureProviderRefundOperations(modelBuilder);
            ConfigureNotificationDelivery(modelBuilder);
            ConfigurePlayerExperience(modelBuilder);
            ConfigureTournamentAndMembershipLifecycle(modelBuilder);
            ConfigureCommerceOperations(modelBuilder);
            ConfigurePrivacy(modelBuilder);
            ConfigureRecommendationEvidence(modelBuilder);
            ConfigureRecommendationExperiments(modelBuilder);
            ConfigureRecommendationImpact(modelBuilder);
            ConfigureProviderVerificationAttempts(modelBuilder);
            ConfigureOutbox(modelBuilder);
            ConfigureInbox(modelBuilder);
        }

        private void EnsureRecommendationEvidenceIsAppendOnly()
        {
            var alteredEvidence = ChangeTracker.Entries<RecommendationEvaluationRun>()
                .FirstOrDefault(entry =>
                    entry.State is EntityState.Modified or EntityState.Deleted);
            if (alteredEvidence is not null)
            {
                throw new InvalidOperationException(
                    "Recommendation evaluation evidence is append-only and cannot be changed or deleted through the application.");
            }

            var alteredExposureSource = ChangeTracker.Entries<RecommendationExposure>()
                .FirstOrDefault(entry =>
                    entry.State == EntityState.Modified &&
                    entry.Property(exposure => exposure.TelemetrySource).IsModified);
            if (alteredExposureSource is not null)
            {
                throw new InvalidOperationException(
                    "Recommendation exposure telemetry source is server-stamped at serving time and cannot be changed through the application.");
            }

            var alteredExposureAssignment = ChangeTracker.Entries<RecommendationExposure>()
                .FirstOrDefault(entry =>
                    entry.State == EntityState.Modified &&
                    entry.Property(exposure => exposure.ExperimentAssignmentId).IsModified);
            if (alteredExposureAssignment is not null)
            {
                throw new InvalidOperationException(
                    "Recommendation exposure experiment assignment is fixed at serving time and cannot be changed through the application.");
            }

            var alteredExperiment = ChangeTracker.Entries<RecommendationExperiment>()
                .FirstOrDefault(entry =>
                    entry.State == EntityState.Deleted ||
                    (entry.State == EntityState.Modified && entry.Properties.Any(property =>
                        property.IsModified &&
                        property.Metadata.Name is not nameof(RecommendationExperiment.Status) and
                            not nameof(RecommendationExperiment.StartedAtUtc) and
                            not nameof(RecommendationExperiment.ClosedAtUtc))));
            if (alteredExperiment is not null)
            {
                throw new InvalidOperationException(
                    "Recommendation experiment protocol is immutable; only its lifecycle may progress through the application.");
            }

            var alteredAssignment = ChangeTracker.Entries<RecommendationExperimentAssignment>()
                .FirstOrDefault(entry => entry.State is EntityState.Modified or EntityState.Deleted);
            if (alteredAssignment is not null)
            {
                throw new InvalidOperationException(
                    "Recommendation experiment assignments are append-only and cannot be changed or deleted through the application.");
            }

            var alteredExperimentRun = ChangeTracker.Entries<RecommendationExperimentAnalysisRun>()
                .FirstOrDefault(entry => entry.State is EntityState.Modified or EntityState.Deleted);
            if (alteredExperimentRun is not null)
            {
                throw new InvalidOperationException(
                    "Recommendation experiment analysis evidence is append-only and cannot be changed or deleted through the application.");
            }

            var alteredProviderVerificationAttempt = ChangeTracker.Entries<ProviderVerificationAttempt>()
                .FirstOrDefault(entry =>
                    entry.State == EntityState.Deleted ||
                    (entry.State == EntityState.Modified && !IsAllowedProviderVerificationCompletion(entry)));
            if (alteredProviderVerificationAttempt is not null)
            {
                throw new InvalidOperationException(
                    "Provider verification evidence is immutable apart from one terminal outcome recorded after a started attempt.");
            }
        }

        private static bool IsAllowedProviderVerificationCompletion(
            Microsoft.EntityFrameworkCore.ChangeTracking.EntityEntry<ProviderVerificationAttempt> entry)
        {
            if (entry.OriginalValues.GetValue<string>(nameof(ProviderVerificationAttempt.Status)) !=
                ProviderVerificationAttemptStatuses.Started)
            {
                return false;
            }

            if (entry.Entity.Status is not ProviderVerificationAttemptStatuses.Succeeded and
                not ProviderVerificationAttemptStatuses.Failed ||
                entry.Entity.CompletedAtUtc is null)
            {
                return false;
            }

            return entry.Properties
                .Where(property => property.IsModified)
                .All(property => property.Metadata.Name is nameof(ProviderVerificationAttempt.Status) or
                    nameof(ProviderVerificationAttempt.OutcomeCategory) or
                    nameof(ProviderVerificationAttempt.CompletedAtUtc));
        }

        private static void ConfigureRecommendationEvidence(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<RecommendationEvaluationRun>(entity =>
            {
                entity.Property(x => x.EvidenceSource).IsRequired().HasMaxLength(40);
                entity.Property(x => x.EvidenceTier).IsRequired().HasMaxLength(20);
                entity.Property(x => x.Protocol).IsRequired().HasMaxLength(120);
                entity.Property(x => x.AlgorithmVersion).IsRequired().HasMaxLength(120);
                entity.Property(x => x.ConfigurationSha256).IsRequired().HasMaxLength(64);
                entity.Property(x => x.InputFingerprintSha256).IsRequired().HasMaxLength(64);
                entity.Property(x => x.ReportJson).IsRequired();
                entity.HasIndex(x => x.RunId).IsUnique();
                entity.HasIndex(x => x.ExecutedAtUtc);
                entity.HasIndex(x => new { x.EvidenceSource, x.ExecutedAtUtc });
                entity.HasOne(x => x.ExecutedByUser)
                    .WithMany()
                    .HasForeignKey(x => x.ExecutedByUserId)
                    .OnDelete(DeleteBehavior.Restrict);
            });
        }

        private static void ConfigureOutbox(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<OutboxMessage>(entity =>
            {
                entity.Property(x => x.Type).IsRequired().HasMaxLength(120);
                entity.Property(x => x.Payload).IsRequired();
                entity.Property(x => x.LastError).HasMaxLength(2000);
                entity.HasIndex(x => new { x.PublishedAtUtc, x.NextAttemptAtUtc });
                entity.HasIndex(x => new { x.PublishedAtUtc, x.NextAttemptAtUtc, x.LeaseExpiresAtUtc });
                entity.HasIndex(x => x.OccurredAtUtc);
            });
        }

        private static void ConfigureInbox(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<InboxMessage>(entity =>
            {
                entity.Property(x => x.Consumer).IsRequired().HasMaxLength(120);
                entity.Property(x => x.MessageType).IsRequired().HasMaxLength(120);
                entity.Property(x => x.ReceivedAtUtc).HasDefaultValueSql("SYSUTCDATETIME()");
                entity.HasIndex(x => new { x.Consumer, x.EventId }).IsUnique();
                entity.HasIndex(x => x.ReceivedAtUtc);
            });
        }

        private static void ConfigureRecommendationImpact(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<RecommendationExposure>(entity =>
            {
                entity.Property(x => x.AlgorithmVersion).IsRequired().HasMaxLength(120);
                entity.Property(x => x.Strategy).IsRequired().HasMaxLength(80);
                entity.Property(x => x.TelemetrySource)
                    .HasDefaultValue(RecommendationTelemetrySource.Unverified);
                entity.HasIndex(x => new { x.UserId, x.ServedAtUtc });
                entity.HasIndex(x => new { x.ProductId, x.ServedAtUtc });
                entity.HasIndex(x => new { x.TelemetrySource, x.ServedAtUtc });
                entity.HasIndex(x => new { x.ExperimentAssignmentId, x.ServedAtUtc });
                entity.HasOne(x => x.User)
                    .WithMany()
                    .HasForeignKey(x => x.UserId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(x => x.Product)
                    .WithMany()
                    .HasForeignKey(x => x.ProductId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(x => x.PurchasedOrder)
                    .WithMany()
                    .HasForeignKey(x => x.PurchasedOrderId)
                    .OnDelete(DeleteBehavior.NoAction);
                entity.HasOne(x => x.ExperimentAssignment)
                    .WithMany(x => x.Exposures)
                    .HasForeignKey(x => x.ExperimentAssignmentId)
                    .OnDelete(DeleteBehavior.NoAction);
            });
        }

        private static void ConfigureRecommendationExperiments(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<RecommendationAnalyticsConsent>(entity =>
            {
                entity.HasKey(x => x.UserId);
                entity.Property(x => x.PolicyVersion).IsRequired().HasMaxLength(120);
                entity.Property(x => x.UpdatedAtUtc).HasDefaultValueSql("SYSUTCDATETIME()");
                entity.HasOne(x => x.User)
                    .WithOne(x => x.RecommendationAnalyticsConsent)
                    .HasForeignKey<RecommendationAnalyticsConsent>(x => x.UserId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            modelBuilder.Entity<RecommendationExperiment>(entity =>
            {
                entity.HasKey(x => x.Id);
                entity.Property(x => x.ExperimentKey).IsRequired().HasMaxLength(120);
                entity.Property(x => x.Status).IsRequired().HasMaxLength(20);
                entity.Property(x => x.Protocol).IsRequired().HasMaxLength(120);
                entity.Property(x => x.TreatmentAlgorithmVersion).IsRequired().HasMaxLength(120);
                entity.Property(x => x.ControlAlgorithmVersion).IsRequired().HasMaxLength(120);
                entity.Property(x => x.TreatmentStrategy).IsRequired().HasMaxLength(80);
                entity.Property(x => x.ControlStrategy).IsRequired().HasMaxLength(80);
                entity.Property(x => x.ConfigurationSha256).IsRequired().HasMaxLength(64);
                entity.HasIndex(x => x.ExperimentKey).IsUnique();
                entity.HasIndex(x => x.Status)
                    .HasFilter("[Status] = N'Running'")
                    .IsUnique();
                entity.HasOne(x => x.CreatedByUser)
                    .WithMany()
                    .HasForeignKey(x => x.CreatedByUserId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<RecommendationExperimentAssignment>(entity =>
            {
                entity.HasKey(x => x.Id);
                entity.HasIndex(x => new { x.ExperimentId, x.UserId }).IsUnique();
                entity.HasIndex(x => new { x.ExperimentId, x.Variant, x.AssignedAtUtc });
                entity.HasOne(x => x.Experiment)
                    .WithMany(x => x.Assignments)
                    .HasForeignKey(x => x.ExperimentId)
                    .OnDelete(DeleteBehavior.NoAction);
                entity.HasOne(x => x.User)
                    .WithMany(x => x.RecommendationExperimentAssignments)
                    .HasForeignKey(x => x.UserId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            modelBuilder.Entity<RecommendationExperimentAnalysisRun>(entity =>
            {
                entity.HasKey(x => x.Id);
                entity.Property(x => x.EvidenceTier).IsRequired().HasMaxLength(30);
                entity.Property(x => x.Protocol).IsRequired().HasMaxLength(120);
                entity.Property(x => x.ConfigurationSha256).IsRequired().HasMaxLength(64);
                entity.Property(x => x.InputFingerprintSha256).IsRequired().HasMaxLength(64);
                entity.Property(x => x.ReportJson).IsRequired();
                entity.HasIndex(x => x.RunId).IsUnique();
                entity.HasIndex(x => new { x.ExperimentId, x.ExecutedAtUtc });
                entity.HasOne(x => x.Experiment)
                    .WithMany(x => x.AnalysisRuns)
                    .HasForeignKey(x => x.ExperimentId)
                    .OnDelete(DeleteBehavior.NoAction);
                entity.HasOne(x => x.ExecutedByUser)
                    .WithMany()
                    .HasForeignKey(x => x.ExecutedByUserId)
                    .OnDelete(DeleteBehavior.Restrict);
            });
        }

        private static void ConfigureProviderVerificationAttempts(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<ProviderVerificationAttempt>(entity =>
            {
                entity.Property(x => x.Provider).IsRequired().HasMaxLength(20);
                entity.Property(x => x.VerificationKind).IsRequired().HasMaxLength(120);
                entity.Property(x => x.Status).IsRequired().HasMaxLength(20);
                entity.Property(x => x.OutcomeCategory).IsRequired().HasMaxLength(60);
                entity.HasIndex(x => x.CorrelationId).IsUnique();
                entity.HasIndex(x => new { x.Provider, x.StartedAtUtc });
                entity.HasOne(x => x.RequestedByUser)
                    .WithMany()
                    .HasForeignKey(x => x.RequestedByUserId)
                    .OnDelete(DeleteBehavior.Restrict);
            });
        }

        private static void ConfigurePrivacy(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<PrivacyRequest>(entity =>
            {
                entity.Property(x => x.RequestType).IsRequired().HasMaxLength(20);
                entity.Property(x => x.Status).IsRequired().HasMaxLength(20);
                entity.HasIndex(x => new { x.UserId, x.Status });
                entity.HasIndex(x => new { x.Status, x.ScheduledFor });
                entity.HasOne(x => x.User).WithMany(x => x.PrivacyRequests).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
            });
        }

        private static void ConfigureCommerceOperations(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<InventoryMovement>(entity =>
            {
                entity.Property(x => x.Reason).IsRequired().HasMaxLength(200);
                entity.Property(x => x.ReferenceType).IsRequired().HasMaxLength(30);
                entity.HasIndex(x => new { x.ProductId, x.CreatedAt });
                entity.HasOne(x => x.Product).WithMany(x => x.InventoryMovements).HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.NoAction);
            });
            modelBuilder.Entity<Coupon>(entity =>
            {
                entity.Property(x => x.Code).IsRequired().HasMaxLength(40);
                entity.Property(x => x.DiscountType).IsRequired().HasMaxLength(20);
                entity.Property(x => x.Value).HasColumnType("decimal(18,2)");
                entity.Property(x => x.MinimumOrderAmount).HasColumnType("decimal(18,2)");
                entity.Property(x => x.MaximumDiscount).HasColumnType("decimal(18,2)");
                entity.HasIndex(x => x.Code).IsUnique();
            });
            modelBuilder.Entity<CouponRedemption>(entity =>
            {
                entity.Property(x => x.DiscountAmount).HasColumnType("decimal(18,2)");
                entity.HasIndex(x => new { x.CouponId, x.UserId });
                entity.HasIndex(x => x.OrderId).IsUnique();
                entity.HasOne(x => x.Coupon).WithMany(x => x.Redemptions).HasForeignKey(x => x.CouponId).OnDelete(DeleteBehavior.NoAction);
            });
            modelBuilder.Entity<ReturnRequest>(entity =>
            {
                entity.Property(x => x.Reason).IsRequired().HasMaxLength(1000);
                entity.Property(x => x.Status).IsRequired().HasMaxLength(30);
                entity.Property(x => x.RefundAmount).HasColumnType("decimal(18,2)");
                entity.Property(x => x.AdminNotes).HasMaxLength(1000);
                entity.HasIndex(x => new { x.UserId, x.Status });
                entity.HasOne(x => x.Order).WithMany(x => x.ReturnRequests).HasForeignKey(x => x.OrderId).OnDelete(DeleteBehavior.NoAction);
            });
            modelBuilder.Entity<ReturnRequestItem>(entity =>
            {
                entity.Property(x => x.RefundAmount).HasColumnType("decimal(18,2)");
                entity.HasIndex(x => new { x.ReturnRequestId, x.OrderItemId }).IsUnique();
                entity.HasOne(x => x.ReturnRequest).WithMany(x => x.Items).HasForeignKey(x => x.ReturnRequestId).OnDelete(DeleteBehavior.Cascade);
                entity.HasOne(x => x.OrderItem).WithMany().HasForeignKey(x => x.OrderItemId).OnDelete(DeleteBehavior.NoAction);
            });
            modelBuilder.Entity<AuditLog>(entity =>
            {
                entity.Property(x => x.Method).IsRequired().HasMaxLength(10);
                entity.Property(x => x.Path).IsRequired().HasMaxLength(500);
                entity.Property(x => x.IpAddress).IsRequired().HasMaxLength(100);
                entity.Property(x => x.CorrelationId).IsRequired().HasMaxLength(100);
                entity.Property(x => x.EntityType).HasMaxLength(100);
                entity.Property(x => x.Action).HasMaxLength(100);
                entity.Property(x => x.PreviousState).HasMaxLength(50);
                entity.Property(x => x.NewState).HasMaxLength(50);
                entity.Property(x => x.Reason).HasMaxLength(1000);
                entity.HasIndex(x => x.CreatedAt);
                entity.HasIndex(x => x.UserId);
                entity.HasIndex(x => new { x.EntityType, x.EntityId, x.CreatedAt });
            });
            modelBuilder.Entity<Order>(entity =>
            {
                entity.Property(x => x.SubtotalAmount).HasColumnType("decimal(18,2)");
                entity.Property(x => x.DiscountAmount).HasColumnType("decimal(18,2)");
                entity.Property(x => x.CouponCode).HasMaxLength(40);
                entity.Property(x => x.IdempotencyKey).HasMaxLength(100);
                entity.HasIndex(x => new { x.UserId, x.IdempotencyKey })
                    .IsUnique()
                    .HasFilter("[IdempotencyKey] IS NOT NULL");
            });
        }

        private static void ConfigureTournamentAndMembershipLifecycle(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<TournamentParticipant>(entity =>
            {
                entity.HasIndex(x => new { x.TournamentId, x.TeamNumber });
            });
            modelBuilder.Entity<Match>(entity =>
            {
                entity.HasIndex(x => new { x.TournamentId, x.BracketRound, x.BracketPosition }).IsUnique()
                    .HasFilter("[BracketRound] IS NOT NULL AND [BracketPosition] IS NOT NULL");
                entity.HasOne(x => x.NextMatch).WithMany(x => x.PreviousMatches).HasForeignKey(x => x.NextMatchId).OnDelete(DeleteBehavior.NoAction);
            });
            modelBuilder.Entity<Membership>(entity =>
            {
                entity.Property(x => x.Status).IsRequired().HasMaxLength(30).HasDefaultValue("Active");
                entity.HasIndex(x => new { x.Status, x.EndDate });
            });
            modelBuilder.Entity<MembershipEvent>(entity =>
            {
                entity.Property(x => x.EventType).IsRequired().HasMaxLength(40);
                entity.Property(x => x.Notes).IsRequired().HasMaxLength(500);
                entity.HasIndex(x => new { x.MembershipId, x.CreatedAt });
                entity.HasOne(x => x.Membership).WithMany(x => x.Events).HasForeignKey(x => x.MembershipId).OnDelete(DeleteBehavior.Cascade);
            });
        }

        private static void ConfigurePlayerExperience(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<City>(entity =>
            {
                entity.Property(x => x.Name).IsRequired().HasMaxLength(100);
                entity.HasIndex(x => x.Name).IsUnique();
                entity.HasData(
                    new City { Id = 1, Name = "Sarajevo" },
                    new City { Id = 2, Name = "Mostar" },
                    new City { Id = 3, Name = "Tuzla" },
                    new City { Id = 4, Name = "Zenica" },
                    new City { Id = 5, Name = "Banja Luka" },
                    new City { Id = 6, Name = "Bihać" },
                    new City { Id = 7, Name = "Čapljina" });
            });
            modelBuilder.Entity<PlayerProfile>(entity =>
            {
                entity.Property(x => x.SkillLevel).IsRequired().HasMaxLength(30);
                entity.Property(x => x.PreferredSide).IsRequired().HasMaxLength(20);
                entity.HasOne(x => x.City).WithMany().HasForeignKey(x => x.CityId).OnDelete(DeleteBehavior.Restrict);
                entity.Property(x => x.Bio).IsRequired().HasMaxLength(500);
                entity.Property(x => x.Availability).IsRequired().HasMaxLength(300);
                entity.HasIndex(x => x.UserId).IsUnique();
                entity.HasIndex(x => new { x.IsDiscoverable, x.SkillLevel, x.CityId });
                entity.HasOne(x => x.User).WithOne(x => x.PlayerProfile)
                    .HasForeignKey<PlayerProfile>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            });
            modelBuilder.Entity<PartnerInvitation>(entity =>
            {
                entity.Property(x => x.Message).IsRequired().HasMaxLength(500);
                entity.Property(x => x.Status).IsRequired().HasMaxLength(20);
                entity.HasIndex(x => new { x.SenderUserId, x.RecipientUserId, x.Status });
                entity.HasOne(x => x.Sender).WithMany(x => x.SentPartnerInvitations).HasForeignKey(x => x.SenderUserId).OnDelete(DeleteBehavior.NoAction);
                entity.HasOne(x => x.Recipient).WithMany(x => x.ReceivedPartnerInvitations).HasForeignKey(x => x.RecipientUserId).OnDelete(DeleteBehavior.NoAction);
            });
            modelBuilder.Entity<Match>(entity =>
            {
                entity.Property(x => x.ResultStatus).IsRequired().HasMaxLength(30);
                entity.Property(x => x.ProposedScore).HasMaxLength(100);
            });
        }

        private static void ConfigureNotificationDelivery(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<NotificationPreference>(entity =>
            {
                entity.HasIndex(x => x.UserId).IsUnique();
                entity.HasOne(x => x.User).WithOne(x => x.NotificationPreference)
                    .HasForeignKey<NotificationPreference>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            });
            modelBuilder.Entity<PushDevice>(entity =>
            {
                entity.Property(x => x.InstallationId).IsRequired().HasMaxLength(500);
                entity.Property(x => x.Platform).IsRequired().HasMaxLength(30);
                entity.HasIndex(x => x.InstallationId).IsUnique();
                entity.HasIndex(x => new { x.UserId, x.IsActive });
                entity.HasOne(x => x.User).WithMany(x => x.PushDevices).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            });
            modelBuilder.Entity<NotificationDelivery>(entity =>
            {
                entity.Property(x => x.Channel).IsRequired().HasMaxLength(20);
                entity.Property(x => x.Status).IsRequired().HasMaxLength(20);
                entity.Property(x => x.ProviderMessageId).HasMaxLength(500);
                entity.Property(x => x.LastError).HasMaxLength(2000);
                entity.HasIndex(x => new { x.NotificationId, x.UserId, x.Channel }).IsUnique();
                entity.HasIndex(x => new { x.Status, x.NextAttemptAt });
                entity.HasOne(x => x.Notification).WithMany(x => x.Deliveries).HasForeignKey(x => x.NotificationId).OnDelete(DeleteBehavior.Cascade);
                entity.HasOne(x => x.User).WithMany(x => x.NotificationDeliveries).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
            });
        }

        private void ConfigureStripePayments(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Payment>(entity =>
            {
                entity.Property(x => x.Provider).IsRequired().HasMaxLength(30);
                entity.Property(x => x.Currency).IsRequired().HasMaxLength(3);
                entity.Property(x => x.IdempotencyKey).HasMaxLength(100);
                entity.Property(x => x.RefundedAmount).HasColumnType("decimal(18,2)");
                entity.Property(x => x.ReceiptUrl).HasMaxLength(1000);
                entity.Property(x => x.FailureMessage).HasMaxLength(1000);
                entity.HasIndex(x => x.IdempotencyKey).IsUnique().HasFilter("[IdempotencyKey] IS NOT NULL");
            });
            modelBuilder.Entity<StripeWebhookEvent>(entity =>
            {
                entity.Property(x => x.StripeEventId).IsRequired().HasMaxLength(100);
                entity.Property(x => x.EventType).IsRequired().HasMaxLength(100);
                entity.Property(x => x.ProcessingError).HasMaxLength(2000);
                entity.HasIndex(x => x.StripeEventId).IsUnique();
            });
        }

        private static void ConfigureProviderRefundOperations(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<ProviderRefundOperation>(entity =>
            {
                entity.Property(x => x.Provider).IsRequired().HasMaxLength(30);
                entity.Property(x => x.Currency).IsRequired().HasMaxLength(3);
                entity.Property(x => x.PaymentIntentId).IsRequired().HasMaxLength(200);
                entity.Property(x => x.Amount).HasColumnType("decimal(18,2)");
                entity.Property(x => x.ExpectedRefundedAmount).HasColumnType("decimal(18,2)");
                entity.Property(x => x.Reason).IsRequired().HasMaxLength(1000);
                entity.Property(x => x.IdempotencyKey).IsRequired().HasMaxLength(255);
                entity.Property(x => x.Status).IsRequired().HasMaxLength(30).HasDefaultValue("Pending");
                entity.Property(x => x.ProviderRefundId).HasMaxLength(255);
                entity.Property(x => x.LastError).HasMaxLength(2000);
                entity.Property(x => x.AttemptCount).HasDefaultValue(0);
                entity.Property(x => x.NextAttemptAtUtc).HasDefaultValueSql("SYSUTCDATETIME()");
                entity.Property(x => x.CreatedAtUtc).HasDefaultValueSql("SYSUTCDATETIME()");

                entity.HasIndex(x => x.IdempotencyKey).IsUnique();
                entity.HasIndex(x => x.ReturnRequestId).IsUnique().HasFilter("[ReturnRequestId] IS NOT NULL");
                entity.HasIndex(x => new { x.Status, x.NextAttemptAtUtc, x.LeaseExpiresAtUtc });
                entity.HasIndex(x => new { x.PaymentId, x.Status });

                entity.HasOne(x => x.Payment)
                    .WithMany(x => x.ProviderRefundOperations)
                    .HasForeignKey(x => x.PaymentId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(x => x.ReturnRequest)
                    .WithMany(x => x.ProviderRefundOperations)
                    .HasForeignKey(x => x.ReturnRequestId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(x => x.RequestedByUser)
                    .WithMany(x => x.RequestedProviderRefundOperations)
                    .HasForeignKey(x => x.RequestedByUserId)
                    .OnDelete(DeleteBehavior.Restrict);
            });
        }

        private void ConfigureBookingLifecycle(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<MaintenanceBlock>(entity =>
            {
                entity.Property(x => x.Reason).IsRequired().HasMaxLength(500);
                entity.HasIndex(x => new { x.CourtId, x.StartTimeUtc, x.EndTimeUtc });
                entity.HasOne(x => x.Court).WithMany(x => x.MaintenanceBlocks).HasForeignKey(x => x.CourtId).OnDelete(DeleteBehavior.Cascade);
            });
            modelBuilder.Entity<WaitlistEntry>(entity =>
            {
                entity.Property(x => x.Status).IsRequired().HasMaxLength(30);
                entity.HasIndex(x => new { x.CourtId, x.StartTimeUtc, x.EndTimeUtc, x.Status });
                entity.HasIndex(x => new { x.UserId, x.CourtId, x.StartTimeUtc, x.EndTimeUtc }).IsUnique();
                entity.HasOne(x => x.Court).WithMany(x => x.WaitlistEntries).HasForeignKey(x => x.CourtId).OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(x => x.User).WithMany(x => x.WaitlistEntries).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            });
            modelBuilder.Entity<AccountCredit>(entity =>
            {
                entity.Property(x => x.Amount).HasColumnType("decimal(18,2)");
                entity.Property(x => x.Reason).IsRequired().HasMaxLength(300);
                entity.HasIndex(x => x.ReservationId)
                    .IsUnique()
                    .HasFilter("[ReservationId] IS NOT NULL");
                entity.HasOne(x => x.User).WithMany(x => x.AccountCredits).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
                entity.HasOne(x => x.Reservation).WithMany(x => x.Credits).HasForeignKey(x => x.ReservationId).OnDelete(DeleteBehavior.SetNull);
            });
            modelBuilder.Entity<Reservation>().HasIndex(x => x.SeriesId);
        }

        private void ConfigureAuthToken(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<AuthToken>(entity =>
            {
                entity.ToTable("AuthTokens");
                entity.HasKey(x => x.Id);
                entity.Property(x => x.TokenHash).IsRequired().HasMaxLength(64);
                entity.Property(x => x.Purpose).IsRequired().HasMaxLength(32);
                entity.Property(x => x.FamilyId).HasMaxLength(32);
                entity.HasIndex(x => x.TokenHash).IsUnique();
                entity.HasIndex(x => new { x.UserId, x.Purpose, x.ExpiresAt });
                entity.HasIndex(x => x.FamilyId);
                entity.HasOne(x => x.User).WithMany(x => x.AuthTokens)
                    .HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            });
        }

        private void ConfigureClubReview(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<ClubReview>(entity =>
            {
                entity.ToTable("ClubReviews");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Comment).IsRequired().HasMaxLength(600);
                entity.Property(e => e.IsPublished).HasDefaultValue(true);
                entity.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
                entity.HasOne(e => e.User).WithMany(e => e.ClubReviews)
                    .HasForeignKey(e => e.UserId).OnDelete(DeleteBehavior.Cascade);
                entity.HasIndex(e => new { e.IsPublished, e.CreatedAt });
                entity.ToTable(t => t.HasCheckConstraint("CK_ClubReviews_Rating", "[Rating] >= 1 AND [Rating] <= 5"));
            });
        }

        private void ConfigureUser(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<User>(entity =>
            {
                entity.ToTable("Users");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Username)
                    .IsRequired()
                    .HasMaxLength(100);

                entity.HasIndex(e => e.Username)
                    .IsUnique();

                entity.Property(e => e.Email)
                    .IsRequired()
                    .HasMaxLength(255);

                entity.HasIndex(e => e.Email)
                    .IsUnique();

                entity.Property(e => e.FirstName)
                    .IsRequired()
                    .HasMaxLength(100);

                entity.Property(e => e.LastName)
                    .IsRequired()
                    .HasMaxLength(100);

                entity.Property(e => e.PhoneNumber)
                    .HasMaxLength(30);

                entity.Property(e => e.PasswordHash)
                    .IsRequired();

                entity.Property(e => e.PasswordSalt)
                    .IsRequired();

                entity.Property(e => e.IsActive)
                    .HasDefaultValue(true);

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

            });
        }

        private void ConfigureRole(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Role>(entity =>
            {
                entity.ToTable("Roles");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Name)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.Property(e => e.Description)
                    .HasMaxLength(200);

                entity.Property(e => e.IsActive)
                    .HasDefaultValue(true);

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasIndex(e => e.Name)
                    .IsUnique();
            });
        }

        private void ConfigureUserRole(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<UserRole>(entity =>
            {
                entity.ToTable("UserRoles");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.DateAssigned)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasOne(e => e.User)
                    .WithMany(u => u.UserRoles)
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.Role)
                    .WithMany(r => r.UserRoles)
                    .HasForeignKey(e => e.RoleId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => new { e.UserId, e.RoleId })
                    .IsUnique();
            });
        }

        private void ConfigureCourt(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Court>(entity =>
            {
                entity.ToTable("Courts");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Name)
                    .IsRequired()
                    .HasMaxLength(100);

                entity.Property(e => e.Description)
                    .HasMaxLength(500);

                entity.Property(e => e.HourlyRate)
                    .HasColumnType("decimal(18,2)");

                entity.Property(e => e.IsActive)
                    .HasDefaultValue(true);

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasIndex(e => e.Name);
            });
        }

        private void ConfigureReservation(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Reservation>(entity =>
            {
                entity.ToTable("Reservations");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Status)
                    .IsRequired()
                    .HasMaxLength(50)
                    .HasDefaultValue("Pending");

                entity.Property(e => e.TotalPrice)
                    .HasColumnType("decimal(18,2)");

                entity.Property(e => e.Notes)
                    .HasMaxLength(1000);

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasOne(e => e.Court)
                    .WithMany(c => c.Reservations)
                    .HasForeignKey(e => e.CourtId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(e => e.User)
                    .WithMany(u => u.Reservations)
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => new { e.CourtId, e.StartTime, e.EndTime });
                entity.HasIndex(e => e.UserId);
                entity.HasIndex(e => e.Status);
            });
        }

        private void ConfigureProduct(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Product>(entity =>
            {
                entity.ToTable("Products");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Name)
                    .IsRequired()
                    .HasMaxLength(200);

                entity.Property(e => e.Description)
                    .HasMaxLength(1000);

                entity.Property(e => e.Price)
                    .HasColumnType("decimal(18,2)");

                entity.Property(e => e.ImageUrl)
                    .HasMaxLength(500);

                entity.Property(e => e.IsActive)
                    .HasDefaultValue(true);

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasOne(e => e.ProductCategory)
                    .WithMany(c => c.Products)
                    .HasForeignKey(e => e.ProductCategoryId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(e => e.ProductType)
                    .WithMany(t => t.Products)
                    .HasForeignKey(e => e.ProductTypeId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => e.ProductCategoryId);
                entity.HasIndex(e => e.ProductTypeId);
                entity.HasIndex(e => e.Name);
            });
        }

        private void ConfigureMembership(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Membership>(entity =>
            {
                entity.ToTable("Memberships");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.MembershipType)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.HasOne(e => e.MembershipTypeReference)
                    .WithMany()
                    .HasForeignKey(e => e.MembershipTypeReferenceId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.Property(e => e.Price)
                    .HasColumnType("decimal(18,2)");

                entity.Property(e => e.IsActive)
                    .HasDefaultValue(true);

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasOne(e => e.User)
                    .WithMany(u => u.Memberships)
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => e.UserId);
                entity.HasIndex(e => new { e.UserId, e.IsActive });
                entity.HasIndex(e => e.MembershipTypeReferenceId);
            });

            modelBuilder.Entity<MembershipTypeReference>(entity =>
            {
                entity.ToTable("MembershipTypeReferences");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Name).IsRequired().HasMaxLength(50);
                entity.HasIndex(e => e.Name).IsUnique();
                entity.HasData(
                    new MembershipTypeReference { Id = 1, Name = "Basic" },
                    new MembershipTypeReference { Id = 2, Name = "Premium" },
                    new MembershipTypeReference { Id = 3, Name = "VIP" });
            });
        }

        private void ConfigurePayment(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Payment>(entity =>
            {
                entity.ToTable("Payments");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.PaymentType)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.Property(e => e.PaymentMethod)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.Property(e => e.Status)
                    .IsRequired()
                    .HasMaxLength(50)
                    .HasDefaultValue("Pending");

                entity.Property(e => e.Amount)
                    .HasColumnType("decimal(18,2)");

                entity.Property(e => e.TransactionId)
                    .HasMaxLength(200);

                entity.Property(e => e.PaymentDate)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasOne(e => e.User)
                    .WithMany(u => u.Payments)
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(e => e.Reservation)
                    .WithOne(r => r.Payment)
                    .HasForeignKey<Payment>(e => e.ReservationId)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.HasOne(e => e.Membership)
                    .WithOne(m => m.Payment)
                    .HasForeignKey<Payment>(e => e.MembershipId)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.HasOne(e => e.Order)
                    .WithOne(o => o.Payment)
                    .HasForeignKey<Payment>(e => e.OrderId)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.HasIndex(e => e.UserId);
                entity.HasIndex(e => e.Status);
                entity.HasIndex(e => e.TransactionId);
            });
        }

        private void ConfigureTournament(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Tournament>(entity =>
            {
                entity.ToTable("Tournaments");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Name)
                    .IsRequired()
                    .HasMaxLength(200);

                entity.Property(e => e.Description)
                    .HasMaxLength(2000);

                entity.Property(e => e.Status)
                    .IsRequired()
                    .HasMaxLength(50)
                    .HasDefaultValue("Upcoming");

                entity.Property(e => e.EntryFee)
                    .HasColumnType("decimal(18,2)");

                entity.Property(e => e.PrizeInfo)
                    .HasMaxLength(1000);

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasIndex(e => e.Status);
                entity.HasIndex(e => e.StartDate);
            });
        }

        private void ConfigureMatch(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Match>(entity =>
            {
                entity.ToTable("Matches");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Status)
                    .IsRequired()
                    .HasMaxLength(50)
                    .HasDefaultValue("Scheduled");

                entity.Property(e => e.Score)
                    .HasMaxLength(100);

                entity.Property(e => e.Notes)
                    .HasMaxLength(1000);

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasOne(e => e.Tournament)
                    .WithMany(t => t.Matches)
                    .HasForeignKey(e => e.TournamentId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(e => e.Court)
                    .WithMany()
                    .HasForeignKey(e => e.CourtId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => e.TournamentId);
                entity.HasIndex(e => e.CourtId);
                entity.HasIndex(e => e.ScheduledTime);
            });
        }

        private void ConfigureMatchParticipant(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<MatchParticipant>(entity =>
            {
                entity.ToTable("MatchParticipants");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Role)
                    .IsRequired()
                    .HasMaxLength(50)
                    .HasDefaultValue("Player");

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasOne(e => e.Match)
                    .WithMany(m => m.Participants)
                    .HasForeignKey(e => e.MatchId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.User)
                    .WithMany(u => u.MatchParticipants)
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => new { e.MatchId, e.UserId }).IsUnique();
            });
        }

        private void ConfigureTournamentParticipant(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<TournamentParticipant>(entity =>
            {
                entity.ToTable("TournamentParticipants");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Status)
                    .IsRequired()
                    .HasMaxLength(50)
                    .HasDefaultValue("Registered");

                entity.Property(e => e.RegisteredAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasOne(e => e.Tournament)
                    .WithMany(t => t.Participants)
                    .HasForeignKey(e => e.TournamentId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(e => e.User)
                    .WithMany(u => u.TournamentParticipants)
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => new { e.TournamentId, e.UserId }).IsUnique();
            });
        }

        private void ConfigureOrder(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Order>(entity =>
            {
                entity.ToTable("Orders");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.OrderNumber)
                    .IsRequired()
                    .HasMaxLength(100);

                entity.Property(e => e.TotalAmount)
                    .HasColumnType("decimal(18,2)");

                entity.Property(e => e.Status)
                    .IsRequired()
                    .HasMaxLength(50)
                    .HasDefaultValue("Pending");

                entity.Property(e => e.ShippingAddress)
                    .IsRequired()
                    .HasMaxLength(500);

                entity.Property(e => e.RecipientName)
                    .IsRequired()
                    .HasMaxLength(150);

                entity.Property(e => e.PhoneNumber)
                    .IsRequired()
                    .HasMaxLength(30);

                entity.Property(e => e.City)
                    .IsRequired()
                    .HasMaxLength(100);

                entity.Property(e => e.PostalCode)
                    .IsRequired()
                    .HasMaxLength(20);

                entity.Property(e => e.Notes)
                    .HasMaxLength(1000);

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.Property(e => e.IsSeededForDemo)
                    .HasDefaultValue(false);

                entity.Property(e => e.Origin)
                    .HasDefaultValue(OrderOrigin.UnverifiedLegacy);

                entity.HasOne(e => e.User)
                    .WithMany(u => u.Orders)
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => e.OrderNumber).IsUnique();
                entity.HasIndex(e => e.UserId);
                entity.HasIndex(e => e.Status);
                entity.HasIndex(e => new { e.Status, e.IsSeededForDemo, e.DeliveredAt });
                entity.HasIndex(e => new { e.Status, e.Origin, e.DeliveredAt });
            });
        }

        private void ConfigureOrderItem(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<OrderItem>(entity =>
            {
                entity.ToTable("OrderItems");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.UnitPrice)
                    .HasColumnType("decimal(18,2)");

                entity.Property(e => e.TotalPrice)
                    .HasColumnType("decimal(18,2)");

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasOne(e => e.Order)
                    .WithMany(o => o.OrderItems)
                    .HasForeignKey(e => e.OrderId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.Product)
                    .WithMany(p => p.OrderItems)
                    .HasForeignKey(e => e.ProductId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => e.OrderId);
            });
        }

        private void ConfigureAsset(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Asset>(entity =>
            {
                entity.ToTable("Assets");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Base64Image)
                    .IsRequired();

                entity.Property(e => e.DisplayOrder)
                    .HasDefaultValue(0);

                entity.Property(e => e.IsPrimary)
                    .HasDefaultValue(false);

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasOne(e => e.Product)
                    .WithMany(p => p.Assets)
                    .HasForeignKey(e => e.ProductId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasIndex(e => e.ProductId);
                entity.HasIndex(e => new { e.ProductId, e.DisplayOrder });
            });
        }

        private void ConfigureProductCategory(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<ProductCategory>(entity =>
            {
                entity.ToTable("ProductCategories");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Name)
                    .IsRequired()
                    .HasMaxLength(100);

                entity.Property(e => e.Description)
                    .HasMaxLength(500);

                entity.Property(e => e.IsActive)
                    .HasDefaultValue(true);

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasIndex(e => e.Name);
            });
        }

        private void ConfigureProductType(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<ProductType>(entity =>
            {
                entity.ToTable("ProductTypes");
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Name)
                    .IsRequired()
                    .HasMaxLength(100);

                entity.Property(e => e.Description)
                    .HasMaxLength(500);

                entity.Property(e => e.IsActive)
                    .HasDefaultValue(true);

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("GETUTCDATE()");

                entity.HasIndex(e => e.Name);
            });
        }

        private void ConfigureNotification(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Notification>(entity =>
            {
                entity.ToTable("Notifications");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Title).IsRequired().HasMaxLength(200);
                entity.Property(e => e.Message).IsRequired().HasMaxLength(2000);
                entity.Property(e => e.Type).IsRequired().HasMaxLength(50).HasDefaultValue("System");
                entity.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
                entity.HasIndex(e => e.Type);
                entity.HasIndex(e => e.CreatedAt);
            });
        }

        private void ConfigureNotificationRecipient(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<NotificationRecipient>(entity =>
            {
                entity.ToTable("NotificationRecipients");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.IsRead).HasDefaultValue(false);
                entity.HasOne(e => e.Notification)
                    .WithMany(n => n.Recipients)
                    .HasForeignKey(e => e.NotificationId)
                    .OnDelete(DeleteBehavior.Cascade);
                entity.HasOne(e => e.User)
                    .WithMany(u => u.NotificationRecipients)
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Cascade);
                entity.HasIndex(e => new { e.NotificationId, e.UserId }).IsUnique();
                entity.HasIndex(e => new { e.UserId, e.IsRead });
            });
        }
    }
}
