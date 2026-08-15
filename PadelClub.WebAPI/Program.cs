using System;
using System.Linq;
using System.Threading;
using EasyNetQ;
using Mapster;
using MapsterMapper;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using System.Threading.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi.Models;
using PadelClub.Model.Requests;
using PadelClub.Services;
using PadelClub.Services.Database;
using PadelClub.Services.ProductStateMachine;
using PadelClub.WebAPI.Filters;
using PadelClub.WebAPI.Authentication;
using PadelClub.WebAPI.Payments;
using PadelClub.WebAPI.Notifications;
using PadelClub.WebAPI.Tournaments;
using PadelClub.WebAPI.Memberships;
using PadelClub.WebAPI.Auditing;
using PadelClub.WebAPI.Monitoring;
using PadelClub.WebAPI.Privacy;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using System.Text.Json;

namespace PadelClub.WebAPI
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // The default Windows Event Log provider can throw for non-elevated local runs.
            // Console/debug logging is portable across desktop development and containers.
            builder.Logging.ClearProviders();
            builder.Logging.AddConsole();
            builder.Logging.AddDebug();

            // Add services to the container.
            builder.Services.AddSingleton<IPasswordHasher, PasswordHasher>();
            builder.Services.AddOptions<StripeOptions>().Bind(builder.Configuration.GetSection(StripeOptions.SectionName))
                .Validate(x => x.Currency.Length == 3, "Stripe currency must be a three-letter ISO code.").ValidateOnStart();
            builder.Services.AddScoped<IStripePaymentService, StripePaymentService>();
            builder.Services.AddOptions<NotificationDeliveryOptions>().Bind(builder.Configuration.GetSection(NotificationDeliveryOptions.SectionName))
                .Validate(x => x.PollSeconds >= 2 && x.MaxAttempts is >= 1 and <= 20, "Invalid notification delivery configuration.").ValidateOnStart();
            builder.Services.AddScoped<SmtpEmailSender>();
            builder.Services.AddScoped<IEmailSender>(sp => sp.GetRequiredService<SmtpEmailSender>());
            builder.Services.AddScoped<ITransactionalEmailSender>(sp => sp.GetRequiredService<SmtpEmailSender>());
            builder.Services.AddSingleton<IPushSender, FirebasePushSender>();
            builder.Services.AddHostedService<NotificationDeliveryWorker>();
            builder.Services.AddScoped<IBracketService, BracketService>();
            builder.Services.AddHostedService<MembershipLifecycleWorker>();
            builder.Services.AddHealthChecks().AddCheck<DatabaseHealthCheck>("database", tags: ["ready"]);
            builder.Services.AddHostedService<PrivacyDeletionWorker>();
            builder.Services.AddOptions<BookingOptions>().Bind(builder.Configuration.GetSection(BookingOptions.SectionName))
                .Validate(x => x.OpeningHour >= 0 && x.ClosingHour <= 24 && x.OpeningHour < x.ClosingHour && x.SlotMinutes > 0 && 60 % x.SlotMinutes == 0, "Invalid booking schedule configuration.").ValidateOnStart();
            builder.Services.AddTransient<IProductService, ProductService>();
            builder.Services.AddTransient<IUserService, UserService>();
            builder.Services.AddTransient<ICourtService, CourtService>();
            builder.Services.AddTransient<IReservationService, ReservationService>();
            builder.Services.AddTransient<ITournamentService, TournamentService>();
            builder.Services.AddTransient<ITournamentParticipantService, TournamentParticipantService>();
            builder.Services.AddTransient<IProductTypeService, ProductTypeService>();
            builder.Services.AddTransient<IProductCategoryService, ProductCategoryService>();
            builder.Services.AddTransient<IPaymentService, PaymentService>();
            builder.Services.AddTransient<IOrderService, OrderService>();
            builder.Services.AddTransient<IOrderItemService, OrderItemService>();
            builder.Services.AddTransient<IMembershipService, MembershipService>();
            builder.Services.AddTransient<IMatchParticipantService, MatchParticipantService>();
            builder.Services.AddTransient<IRoleService, RoleService>();
            builder.Services.AddTransient<INotificationService, NotificationService>();
            builder.Services.AddTransient<IClubReviewService, ClubReviewService>();
            builder.Services.AddTransient<BaseProductState>();
            builder.Services.AddTransient<InitialProductState>();
            builder.Services.AddTransient<DraftProductState>();
            builder.Services.AddTransient<ActiveProductState>();
            builder.Services.AddTransient<DeactivatedProductState>();



            // Register EasyNetQ
            builder.Services.AddEasyNetQ("host=localhost");


            var mapsterConfig = TypeAdapterConfig.GlobalSettings;
            mapsterConfig.Scan(typeof(Program).Assembly);
            builder.Services.AddSingleton(mapsterConfig);
            builder.Services.AddScoped<IMapper, ServiceMapper>();

            // Configure database services
            builder.Services.AddDatabaseServices(builder.Configuration);

            builder.Services.AddOptions<AuthOptions>().Bind(builder.Configuration.GetSection(AuthOptions.SectionName)).Validate(x => x.SigningKey.Length >= 32, "Authentication:SigningKey must be at least 32 characters.").ValidateOnStart();
            builder.Services.AddScoped<IAuthService, AuthService>();
            var auth = builder.Configuration.GetSection(AuthOptions.SectionName).Get<AuthOptions>() ?? new AuthOptions();
            builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true, ValidIssuer = auth.Issuer, ValidateAudience = true, ValidAudience = auth.Audience,
                    ValidateIssuerSigningKey = true, IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(auth.SigningKey)),
                    ValidateLifetime = true, ClockSkew = TimeSpan.FromSeconds(30)
                };
            });
            builder.Services.AddAuthorization(options =>
            {
                options.AddPolicy("AdminOnly", policy => policy.RequireRole("Administrator"));
                options.AddPolicy("VerifiedPlayer", policy => policy.RequireAuthenticatedUser().RequireClaim("email_verified", "true"));
            });
            builder.Services.AddRateLimiter(options =>
            {
                options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
                options.AddPolicy("Authentication", context => RateLimitPartition.GetFixedWindowLimiter(
                    context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                    _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
                options.AddPolicy("Recovery", context => RateLimitPartition.GetFixedWindowLimiter(
                    context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                    _ => new FixedWindowRateLimiterOptions { PermitLimit = 3, Window = TimeSpan.FromMinutes(15), QueueLimit = 0 }));
            });

            builder.Services.AddControllers(
                x =>
                {
                    x.Filters.Add<ExceptionFilter>(); // Global exception filter
                }
            )
                .AddJsonOptions(options =>
                {
                    // Handle circular references in navigation properties
                    options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
                });
            builder.Services.AddCors(options =>
            {
                options.AddPolicy("PadelClubClient", policy =>
                {
                    policy
                        .SetIsOriginAllowed(origin =>
                        {
                            if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri))
                                return false;

                            return uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
                                   uri.Host.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase);
                        })
                        .AllowAnyHeader()
                        .AllowAnyMethod();
                });
            });
            // Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen(c =>
            {
                c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
                {
                    Description = "JWT access token.",
                    Name = "Authorization",
                    In = ParameterLocation.Header,
                    Type = SecuritySchemeType.Http,
                    Scheme = "bearer",
                    BearerFormat = "JWT"
                });
                c.AddSecurityRequirement(new OpenApiSecurityRequirement
                {
                    {
                        new OpenApiSecurityScheme
                        {
                            Reference = new OpenApiReference
                            {
                                Type = ReferenceType.SecurityScheme,
                                Id = "Bearer"
                            }
                        },
                        new string[] { }
                    }
                });
            });

            var app = builder.Build();

            using (var scope = app.Services.CreateScope())
            {
                var db = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
                var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();

                try
                {
                    ApplyMigrationsWithRetry(db, logger);
                    SeedInitialData(db, logger);
                    if (app.Environment.IsDevelopment())
                    {
                        var verifiedAt = DateTime.UtcNow;
                        var updated = db.Users
                            .Where(x => x.Email.EndsWith("@padelclub.local") && x.EmailVerifiedAt == null)
                            .ExecuteUpdate(x => x.SetProperty(user => user.EmailVerifiedAt, verifiedAt));
                        if (updated > 0) logger.LogInformation("Marked {Count} local demo accounts as email verified.", updated);
                    }
                }
                catch (Exception ex) when (app.Environment.IsDevelopment())
                {
                    logger.LogWarning(
                        ex,
                        "Skipping database bootstrap because SQL Server is unavailable. The API will start, but database-backed endpoints may fail until the database is online.");
                }
            }

            // Configure the HTTP request pipeline.
            if (app.Environment.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
                app.UseSwagger();
                app.UseSwaggerUI(c =>
                {
                    c.SwaggerEndpoint("/swagger/v1/swagger.json", "PadelClub API v1");
                });
            }
            else
            {
                app.UseExceptionHandler("/Error");
            }

            if (!app.Environment.IsDevelopment()) app.UseHttpsRedirection();

            app.UseCors("PadelClubClient");
            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();
            app.UseMiddleware<AuditMiddleware>();

            // Redirect root to Swagger in development
            if (app.Environment.IsDevelopment())
            {
                app.MapGet("/", () => Results.Redirect("/swagger")).ExcludeFromDescription();
            }

            app.MapControllers();
            app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false });
            app.MapHealthChecks("/health/ready", new HealthCheckOptions
            {
                Predicate = check => check.Tags.Contains("ready"),
                ResponseWriter = async (context, report) =>
                {
                    context.Response.ContentType = "application/json";
                    await context.Response.WriteAsync(JsonSerializer.Serialize(new { status = report.Status.ToString(), durationMs = report.TotalDuration.TotalMilliseconds,
                        checks = report.Entries.Select(x => new { name = x.Key, status = x.Value.Status.ToString(), durationMs = x.Value.Duration.TotalMilliseconds, description = x.Value.Description }) }));
                }
            });

            app.Run();
        }

        private static void SeedInitialData(PadelClubContext db, ILogger logger)
        {
            try
            {
                var passwordHasher = new PasswordHasher();

                // Product categories
                if (!db.ProductCategories.Any())
                {
                    db.ProductCategories.AddRange(new[]
                    {
                        new ProductCategory { Name = "Equipment", Description = "Padel equipment and gear" },
                        new ProductCategory { Name = "Merchandise", Description = "Club merchandise" },
                        new ProductCategory { Name = "Accessories", Description = "Padel accessories" },
                    });
                    db.SaveChanges();
                    logger.LogInformation("Seeded ProductCategories.");
                }

                // Product types
                if (!db.ProductTypes.Any())
                {
                    db.ProductTypes.AddRange(new[]
                    {
                        new ProductType { Name = "Rackets", Description = "Padel rackets" },
                        new ProductType { Name = "Balls", Description = "Padel balls" },
                        new ProductType { Name = "Apparel", Description = "Clothing and apparel" },
                        new ProductType { Name = "Shoes", Description = "Padel shoes" }
                    });
                    db.SaveChanges();
                    logger.LogInformation("Seeded ProductTypes.");
                }

                // Courts
                if (!db.Courts.Any())
                {
                    db.Courts.AddRange(new[]
                    {
                        new Court
                        {
                            Name = "Court Central",
                            Description = "Main indoor/outdoor court.",
                            IsIndoor = false,
                            IsActive = true,
                            HourlyRate = 25m,
                            MaxPlayers = 4
                        },
                        new Court
                        {
                            Name = "Court North",
                            Description = "Extra training court.",
                            IsIndoor = true,
                            IsActive = true,
                            HourlyRate = 30m,
                            MaxPlayers = 4
                        }
                    });
                    db.SaveChanges();
                    logger.LogInformation("Seeded Courts.");
                }

                // Users
                if (!db.Users.Any())
                {
                    const string defaultPassword = "password123!";

                    var adminPasswordHash = passwordHasher.HashPassword(defaultPassword);
                    var adminPasswordSalt = ExtractSaltFromPasswordHash(adminPasswordHash);

                    db.Users.AddRange(new[]
                    {
                        new User
                        {
                            Username = "admin",
                            Email = "admin@padelclub.local",
                            FirstName = "Padel",
                            LastName = "Admin",
                            PhoneNumber = "123456789",
                            PasswordHash = adminPasswordHash,
                            PasswordSalt = adminPasswordSalt,
                            IsActive = true
                        },
                        new User
                        {
                            Username = "player1",
                            Email = "player1@padelclub.local",
                            FirstName = "Casey",
                            LastName = "Player",
                            PhoneNumber = "987654321",
                            PasswordHash = adminPasswordHash,
                            PasswordSalt = adminPasswordSalt,
                            IsActive = true
                        }
                    });
                    db.SaveChanges();
                    logger.LogInformation("Seeded Users.");
                }

                if (!db.Roles.Any(x => x.Name == "Administrator"))
                    db.Roles.Add(new Role { Name = "Administrator", Description = "Club management access", IsActive = true });
                if (!db.Roles.Any(x => x.Name == "Player"))
                    db.Roles.Add(new Role { Name = "Player", Description = "Mobile player access", IsActive = true });
                db.SaveChanges();

                var administratorRoleId = db.Roles.Where(x => x.Name == "Administrator").Select(x => x.Id).First();
                var playerRoleId = db.Roles.Where(x => x.Name == "Player").Select(x => x.Id).First();
                var adminUserId = db.Users.Where(x => x.Username == "admin").Select(x => x.Id).FirstOrDefault();
                var playerUserId = db.Users.Where(x => x.Username == "player1").Select(x => x.Id).FirstOrDefault();

                if (adminUserId > 0 && !db.UserRoles.Any(x => x.UserId == adminUserId && x.RoleId == administratorRoleId))
                    db.UserRoles.Add(new UserRole { UserId = adminUserId, RoleId = administratorRoleId });
                if (playerUserId > 0 && !db.UserRoles.Any(x => x.UserId == playerUserId && x.RoleId == playerRoleId))
                    db.UserRoles.Add(new UserRole { UserId = playerUserId, RoleId = playerRoleId });
                db.SaveChanges();

                if (!db.ClubReviews.Any() && playerUserId > 0)
                {
                    db.ClubReviews.Add(new ClubReview
                    {
                        UserId = playerUserId,
                        Rating = 5,
                        Comment = "Court booking is quick, and I can see my next reservation immediately.",
                        IsPublished = true
                    });
                    db.SaveChanges();
                    logger.LogInformation("Seeded ClubReviews.");
                }

                // Products
                if (!db.Products.Any())
                {
                    var equipmentCategoryId = db.ProductCategories
                        .Where(c => c.Name == "Equipment")
                        .Select(c => c.Id)
                        .FirstOrDefault();
                    var merchandiseCategoryId = db.ProductCategories
                        .Where(c => c.Name == "Merchandise")
                        .Select(c => c.Id)
                        .FirstOrDefault();

                    var racketsTypeId = db.ProductTypes
                        .Where(t => t.Name == "Rackets")
                        .Select(t => t.Id)
                        .FirstOrDefault();
                    var ballsTypeId = db.ProductTypes
                        .Where(t => t.Name == "Balls")
                        .Select(t => t.Id)
                        .FirstOrDefault();
                    var shoesTypeId = db.ProductTypes
                        .Where(t => t.Name == "Shoes")
                        .Select(t => t.Id)
                        .FirstOrDefault();

                    // Fallbacks (in case you renamed categories/types)
                    equipmentCategoryId = equipmentCategoryId != 0
                        ? equipmentCategoryId
                        : db.ProductCategories.OrderBy(c => c.Id).Select(c => c.Id).First();
                    merchandiseCategoryId = merchandiseCategoryId != 0
                        ? merchandiseCategoryId
                        : db.ProductCategories.OrderBy(c => c.Id).Select(c => c.Id).First();

                    racketsTypeId = racketsTypeId != 0
                        ? racketsTypeId
                        : db.ProductTypes.OrderBy(t => t.Id).Select(t => t.Id).First();
                    ballsTypeId = ballsTypeId != 0
                        ? ballsTypeId
                        : db.ProductTypes.OrderBy(t => t.Id).Select(t => t.Id).First();
                    shoesTypeId = shoesTypeId != 0
                        ? shoesTypeId
                        : db.ProductTypes.OrderBy(t => t.Id).Select(t => t.Id).First();

                    db.Products.AddRange(new[]
                    {
                        new Product
                        {
                            Name = "Padel Racket (Starter)",
                            Description = "Balanced starter racket.",
                            Price = 79.99m,
                            StockQuantity = 12,
                            ImageUrl = null,
                            IsActive = true,
                            ProductState = "DraftProductState",
                            ProductCategoryId = equipmentCategoryId,
                            ProductTypeId = racketsTypeId
                        },
                        new Product
                        {
                            Name = "Padel Balls (3 pack)",
                            Description = "Official club balls.",
                            Price = 12.50m,
                            StockQuantity = 100,
                            ImageUrl = null,
                            IsActive = true,
                            ProductState = "DraftProductState",
                            ProductCategoryId = equipmentCategoryId,
                            ProductTypeId = ballsTypeId
                        },
                        new Product
                        {
                            Name = "Padel Shoes (Comfort)",
                            Description = "Non-marking court shoes.",
                            Price = 49.90m,
                            StockQuantity = 20,
                            ImageUrl = null,
                            IsActive = true,
                            ProductState = "DraftProductState",
                            ProductCategoryId = merchandiseCategoryId,
                            ProductTypeId = shoesTypeId
                        }
                    });
                    db.SaveChanges();
                    logger.LogInformation("Seeded Products.");
                }

                // Reservations
                if (!db.Reservations.Any())
                {
                    var courtId = db.Courts.OrderBy(c => c.Id).Select(c => c.Id).First();
                    var userId = db.Users.OrderBy(u => u.Id).Select(u => u.Id).First();

                    var start1 = DateTime.UtcNow.AddDays(1);
                    var start2 = DateTime.UtcNow.AddDays(2);

                    db.Reservations.AddRange(new[]
                    {
                        new Reservation
                        {
                            CourtId = courtId,
                            UserId = userId,
                            StartTime = start1,
                            EndTime = start1.AddHours(1),
                            TotalPrice = 40m,
                            Status = "Pending",
                            Notes = "Seed reservation #1"
                        },
                        new Reservation
                        {
                            CourtId = courtId,
                            UserId = userId,
                            StartTime = start2,
                            EndTime = start2.AddHours(1),
                            TotalPrice = 45m,
                            Status = "Confirmed",
                            Notes = "Seed reservation #2"
                        }
                    });
                    db.SaveChanges();
                    logger.LogInformation("Seeded Reservations.");
                }

                SeedCorrelatedDemoData(db, passwordHasher, playerRoleId, logger);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error seeding initial data.");
            }
        }

        private static void SeedCorrelatedDemoData(
            PadelClubContext db,
            IPasswordHasher passwordHasher,
            int playerRoleId,
            ILogger logger)
        {
            const string demoPassword = "password123!";
            var passwordHash = passwordHasher.HashPassword(demoPassword);
            var passwordSalt = ExtractSaltFromPasswordHash(passwordHash);
            var demoUsers = new[]
            {
                new { Username = "player2", Email = "player2@padelclub.local", First = "Lejla", Last = "Hadžić", Phone = "+387 61 220 102" },
                new { Username = "player3", Email = "player3@padelclub.local", First = "Emir", Last = "Kovač", Phone = "+387 61 220 103" },
                new { Username = "player4", Email = "player4@padelclub.local", First = "Sara", Last = "Begić", Phone = "+387 61 220 104" }
            };
            foreach (var seed in demoUsers)
            {
                if (!db.Users.Any(x => x.Username == seed.Username))
                {
                    db.Users.Add(new User
                    {
                        Username = seed.Username,
                        Email = seed.Email,
                        FirstName = seed.First,
                        LastName = seed.Last,
                        PhoneNumber = seed.Phone,
                        PasswordHash = passwordHash,
                        PasswordSalt = passwordSalt,
                        IsActive = true
                    });
                }
            }
            db.SaveChanges();

            var playerIds = db.Users
                .Where(x => new[] { "player1", "player2", "player3", "player4" }.Contains(x.Username))
                .OrderBy(x => x.Username)
                .Select(x => x.Id)
                .ToList();
            foreach (var userId in playerIds)
            {
                if (!db.UserRoles.Any(x => x.UserId == userId && x.RoleId == playerRoleId))
                    db.UserRoles.Add(new UserRole { UserId = userId, RoleId = playerRoleId });
            }
            db.SaveChanges();
            if (playerIds.Count < 4) return;

            var today = DateTime.UtcNow.Date;
            foreach (var userId in playerIds)
            {
                if (!db.Memberships.Any(x => x.UserId == userId && x.MembershipType.StartsWith("Demo")))
                {
                    db.Memberships.Add(new Membership
                    {
                        UserId = userId,
                        MembershipType = userId == playerIds[0] ? "Demo Premium" : "Demo Basic",
                        StartDate = today.AddMonths(-2),
                        EndDate = today.AddMonths(10),
                        Price = userId == playerIds[0] ? 240m : 150m,
                        IsActive = true
                    });
                }
            }
            db.SaveChanges();

            var courtIds = db.Courts.OrderBy(x => x.Id).Select(x => x.Id).ToList();
            var primaryCourtId = courtIds[0];
            var secondaryCourtId = courtIds.Count > 1 ? courtIds[1] : primaryCourtId;
            if (!db.Reservations.Any(x => x.Notes == "DEMO-COMPLETED-MATCH"))
            {
                db.Reservations.Add(new Reservation
                {
                    UserId = playerIds[0], CourtId = primaryCourtId,
                    StartTime = today.AddDays(-8).AddHours(18),
                    EndTime = today.AddDays(-8).AddHours(19.5),
                    TotalPrice = 37.50m, Status = "Completed", Notes = "DEMO-COMPLETED-MATCH"
                });
            }
            if (!db.Reservations.Any(x => x.Notes == "DEMO-UPCOMING-TRAINING"))
            {
                db.Reservations.Add(new Reservation
                {
                    UserId = playerIds[1], CourtId = secondaryCourtId,
                    StartTime = today.AddDays(3).AddHours(19),
                    EndTime = today.AddDays(3).AddHours(20.5),
                    TotalPrice = 45m, Status = "Confirmed", Notes = "DEMO-UPCOMING-TRAINING"
                });
            }
            db.SaveChanges();

            const string tournamentName = "PadelClub Sarajevo Open 2026";
            var tournament = db.Tournaments.FirstOrDefault(x => x.Name == tournamentName);
            if (tournament == null)
            {
                tournament = new Tournament
                {
                    Name = tournamentName,
                    Description = "Club doubles tournament for registered PadelClub members.",
                    StartDate = today.AddDays(14),
                    EndDate = today.AddDays(16),
                    RegistrationDeadline = today.AddDays(10),
                    MaxParticipants = 16,
                    EntryFee = 25m,
                    Status = "Upcoming",
                    PrizeInfo = "Club trophy and equipment vouchers"
                };
                db.Tournaments.Add(tournament);
                db.SaveChanges();
            }
            foreach (var userId in playerIds)
            {
                if (!db.TournamentParticipants.Any(x => x.TournamentId == tournament.Id && x.UserId == userId))
                {
                    db.TournamentParticipants.Add(new TournamentParticipant
                    {
                        TournamentId = tournament.Id,
                        UserId = userId,
                        Status = "Confirmed",
                        RegisteredAt = today.AddDays(-4),
                        ConfirmedAt = today.AddDays(-3)
                    });
                }
            }
            db.SaveChanges();

            var completedMatch = db.Matches.FirstOrDefault(x =>
                x.TournamentId == tournament.Id && x.Notes == "DEMO-SEMIFINAL-1");
            if (completedMatch == null)
            {
                completedMatch = new Match
                {
                    TournamentId = tournament.Id,
                    CourtId = primaryCourtId,
                    ScheduledTime = today.AddDays(-8).AddHours(18),
                    ActualStartTime = today.AddDays(-8).AddHours(18),
                    ActualEndTime = today.AddDays(-8).AddHours(19.25),
                    Status = "Completed",
                    WinnerTeamId = 1,
                    Score = "6-4, 3-6, 10-7",
                    Notes = "DEMO-SEMIFINAL-1"
                };
                db.Matches.Add(completedMatch);
                db.SaveChanges();
            }
            if (!db.Matches.Any(x => x.TournamentId == tournament.Id && x.Notes == "DEMO-FINAL"))
            {
                db.Matches.Add(new Match
                {
                    TournamentId = tournament.Id,
                    CourtId = secondaryCourtId,
                    ScheduledTime = today.AddDays(16).AddHours(17),
                    Status = "Scheduled",
                    Notes = "DEMO-FINAL"
                });
                db.SaveChanges();
            }
            for (var index = 0; index < playerIds.Count; index++)
            {
                var userId = playerIds[index];
                if (!db.MatchParticipants.Any(x => x.MatchId == completedMatch.Id && x.UserId == userId))
                {
                    db.MatchParticipants.Add(new MatchParticipant
                    {
                        MatchId = completedMatch.Id,
                        UserId = userId,
                        TeamNumber = index < 2 ? 1 : 2,
                        Role = index is 0 or 2 ? "Captain" : "Player"
                    });
                }
            }
            db.SaveChanges();

            var demoProduct = db.Products.FirstOrDefault(x => x.Name == "PadelClub Control Racket");
            if (demoProduct == null)
            {
                var categoryId = db.ProductCategories.Where(x => x.Name == "Equipment").Select(x => x.Id).First();
                var typeId = db.ProductTypes.Where(x => x.Name == "Rackets").Select(x => x.Id).First();
                demoProduct = new Product
                {
                    Name = "PadelClub Control Racket",
                    Description = "Medium-balance club racket for intermediate players.",
                    Price = 149.90m,
                    StockQuantity = 15,
                    ProductCategoryId = categoryId,
                    ProductTypeId = typeId,
                    IsActive = true,
                    ProductState = "ActiveProductState"
                };
                db.Products.Add(demoProduct);
                db.SaveChanges();
            }
            if (!db.Assets.Any(x => x.ProductId == demoProduct.Id))
            {
                db.Assets.Add(new Asset
                {
                    ProductId = demoProduct.Id,
                    Base64Image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
                    DisplayOrder = 0,
                    IsPrimary = true
                });
                db.SaveChanges();
            }

            const string orderNumber = "DEMO-ORDER-2026-001";
            var order = db.Orders.FirstOrDefault(x => x.OrderNumber == orderNumber);
            if (order == null)
            {
                order = new Order
                {
                    UserId = playerIds[0],
                    OrderNumber = orderNumber,
                    TotalAmount = demoProduct.Price,
                    Status = "Delivered",
                    RecipientName = "Casey Player",
                    PhoneNumber = "+387 61 220 101",
                    ShippingAddress = "Zmaja od Bosne 7",
                    City = "Sarajevo",
                    PostalCode = "71000",
                    Notes = "Leave at reception",
                    CreatedAt = today.AddDays(-12)
                };
                db.Orders.Add(order);
                db.SaveChanges();
            }
            if (!db.OrderItems.Any(x => x.OrderId == order.Id))
            {
                db.OrderItems.Add(new OrderItem
                {
                    OrderId = order.Id,
                    ProductId = demoProduct.Id,
                    Quantity = 1,
                    UnitPrice = demoProduct.Price,
                    TotalPrice = demoProduct.Price,
                    CreatedAt = order.CreatedAt
                });
                db.SaveChanges();
            }

            var membership = db.Memberships.First(x => x.UserId == playerIds[0] && x.MembershipType.StartsWith("Demo"));
            var paidReservation = db.Reservations.First(x => x.Notes == "DEMO-COMPLETED-MATCH");
            if (!db.Payments.Any(x => x.MembershipId == membership.Id))
                db.Payments.Add(new Payment { UserId = playerIds[0], MembershipId = membership.Id, PaymentType = "Membership", Amount = membership.Price, PaymentMethod = "CreditCard", Status = "Completed", TransactionId = "DEMO-PAY-MEM-001", PaymentDate = membership.StartDate });
            if (!db.Payments.Any(x => x.ReservationId == paidReservation.Id))
                db.Payments.Add(new Payment { UserId = playerIds[0], ReservationId = paidReservation.Id, PaymentType = "Reservation", Amount = paidReservation.TotalPrice, PaymentMethod = "Cash", Status = "Completed", TransactionId = "DEMO-PAY-RES-001", PaymentDate = paidReservation.StartTime.AddDays(-1) });
            if (!db.Payments.Any(x => x.OrderId == order.Id))
                db.Payments.Add(new Payment { UserId = playerIds[0], OrderId = order.Id, PaymentType = "Product", Amount = order.TotalAmount, PaymentMethod = "CreditCard", Status = "Completed", TransactionId = "DEMO-PAY-ORD-001", PaymentDate = order.CreatedAt });
            db.SaveChanges();

            const string notificationTitle = "Sarajevo Open registration confirmed";
            var notification = db.Notifications.FirstOrDefault(x => x.Title == notificationTitle);
            if (notification == null)
            {
                notification = new Notification
                {
                    Title = notificationTitle,
                    Message = "Your registration for the PadelClub Sarajevo Open 2026 is confirmed.",
                    Type = "Tournament",
                    CreatedAt = today.AddDays(-3)
                };
                db.Notifications.Add(notification);
                db.SaveChanges();
            }
            foreach (var userId in playerIds)
            {
                if (!db.NotificationRecipients.Any(x => x.NotificationId == notification.Id && x.UserId == userId))
                    db.NotificationRecipients.Add(new NotificationRecipient { NotificationId = notification.Id, UserId = userId, IsRead = userId != playerIds[0], ReadAt = userId != playerIds[0] ? today.AddDays(-2) : null });
            }
            db.SaveChanges();

            var reviews = new[]
            {
                (UserId: playerIds[1], Rating: 5, Comment: "The indoor court is well maintained and evening reservations start on time."),
                (UserId: playerIds[2], Rating: 4, Comment: "Tournament registration was clear and the court staff were helpful."),
                (UserId: playerIds[3], Rating: 5, Comment: "A reliable place for weekly doubles sessions with good court availability.")
            };
            foreach (var review in reviews)
            {
                if (!db.ClubReviews.Any(x => x.UserId == review.UserId))
                    db.ClubReviews.Add(new ClubReview { UserId = review.UserId, Rating = review.Rating, Comment = review.Comment, IsPublished = true });
            }
            db.SaveChanges();
            logger.LogInformation("Ensured correlated demo data for all PadelClub entities.");
        }

        private static void EnsureRoleSchema(PadelClubContext db, ILogger logger)
        {
            const string ensureRolesTableSql = @"
IF OBJECT_ID(N'dbo.Roles', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Roles]
    (
        [Id] INT IDENTITY(1,1) NOT NULL,
        [Name] NVARCHAR(50) NOT NULL,
        [Description] NVARCHAR(200) NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_Roles_CreatedAt] DEFAULT (GETUTCDATE()),
        [IsActive] BIT NOT NULL CONSTRAINT [DF_Roles_IsActive] DEFAULT ((1)),
        CONSTRAINT [PK_Roles] PRIMARY KEY CLUSTERED ([Id] ASC)
    );

    CREATE UNIQUE INDEX [IX_Roles_Name] ON [dbo].[Roles]([Name]);
END";

            const string ensureUserRolesTableSql = @"
IF OBJECT_ID(N'dbo.UserRoles', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[UserRoles]
    (
        [Id] INT IDENTITY(1,1) NOT NULL,
        [UserId] INT NOT NULL,
        [RoleId] INT NOT NULL,
        [DateAssigned] DATETIME2 NOT NULL CONSTRAINT [DF_UserRoles_DateAssigned] DEFAULT (GETUTCDATE()),
        CONSTRAINT [PK_UserRoles] PRIMARY KEY CLUSTERED ([Id] ASC),
        CONSTRAINT [FK_UserRoles_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users]([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_UserRoles_Roles_RoleId] FOREIGN KEY ([RoleId]) REFERENCES [dbo].[Roles]([Id]) ON DELETE NO ACTION
    );

    CREATE UNIQUE INDEX [IX_UserRoles_UserId_RoleId] ON [dbo].[UserRoles]([UserId], [RoleId]);
    CREATE INDEX [IX_UserRoles_RoleId] ON [dbo].[UserRoles]([RoleId]);
END";

            try
            {
                db.Database.ExecuteSqlRaw(ensureRolesTableSql);
                db.Database.ExecuteSqlRaw(ensureUserRolesTableSql);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Failed to ensure role schema. Role endpoints may not be available until schema is fixed.");
            }
        }

        private static string ExtractSaltFromPasswordHash(string hashedPassword)
        {
            if (string.IsNullOrWhiteSpace(hashedPassword))
                throw new ArgumentException("Password hash cannot be null/empty.", nameof(hashedPassword));

            var parts = hashedPassword.Split('.');
            if (parts.Length != 3)
                throw new ArgumentException("Invalid password hash format.", nameof(hashedPassword));

            // Expected format: {iterations}.{base64(salt)}.{base64(derivedKey)}
            return parts[1];
        }

        private static void RunCrudSmokeTestsIfNeeded(PadelClubContext db, IServiceProvider serviceProvider, ILogger logger)
        {
            // Run only once (marker court) to avoid creating endless test data.
            const string markerCourtName = "CRUD_MARKER_COURT";
            if (db.Courts.Any(c => c.Name == markerCourtName))
                return;

            var courtService = serviceProvider.GetRequiredService<ICourtService>();
            var userService = serviceProvider.GetRequiredService<IUserService>();
            var productService = serviceProvider.GetRequiredService<IProductService>();
            var reservationService = serviceProvider.GetRequiredService<IReservationService>();

            try
            {
                // Marker data (dummy records that will stay in the DB)
                var markerCourt = courtService.CreateAsync(new CourtInsertRequest
                {
                    Name = markerCourtName,
                    Description = "Smoke-test marker court.",
                    IsIndoor = false,
                    IsActive = true,
                    HourlyRate = 28m,
                    MaxPlayers = 4
                }).GetAwaiter().GetResult();

                var markerUser = userService.CreateAsync(new UserInsertRequest
                {
                    Username = "crud_marker_user",
                    Email = "crud_marker_user@padelclub.local",
                    FirstName = "Smoke",
                    LastName = "Tester",
                    Password = "password123!",
                    PhoneNumber = "111222333"
                }).GetAwaiter().GetResult();

                var markerProduct = productService.CreateAsync(new ProductInsertRequest
                {
                    Name = "CRUD_MARKER_PRODUCT",
                    Description = "Smoke-test marker product.",
                    Price = 19.99m,
                    StockQuantity = 5,
                    ImageUrl = null
                }).GetAwaiter().GetResult();

                var markerReservation = reservationService.CreateAsync(new ReservationInsertRequest
                {
                    CourtId = markerCourt.Id,
                    UserId = markerUser.Id,
                    StartTime = DateTime.UtcNow.AddDays(3),
                    EndTime = DateTime.UtcNow.AddDays(3).AddHours(1),
                    TotalPrice = markerCourt.HourlyRate,
                    Status = "Pending",
                    Notes = "CRUD_MARKER_RESERVATION"
                }).GetAwaiter().GetResult();

                logger.LogInformation(
                    "CRUD smoke marker created: court={CourtId}, user={UserId}, product={ProductId}, reservation={ReservationId}",
                    markerCourt.Id, markerUser.Id, markerProduct.Id, markerReservation.Id);

                // Temporary records for full CRUD (including delete)
                var suffix = Guid.NewGuid().ToString("N").Substring(0, 8);

                var tempCourt = courtService.CreateAsync(new CourtInsertRequest
                {
                    Name = $"CRUD_TEMP_COURT_{suffix}",
                    Description = "Temporary smoke-test court.",
                    IsIndoor = true,
                    IsActive = true,
                    HourlyRate = 32m,
                    MaxPlayers = 4
                }).GetAwaiter().GetResult();

                var tempUser = userService.CreateAsync(new UserInsertRequest
                {
                    Username = $"crud_temp_user_{suffix}",
                    Email = $"crud_temp_user_{suffix}@padelclub.local",
                    FirstName = "Temp",
                    LastName = $"User_{suffix}",
                    Password = "password123!",
                    PhoneNumber = "000111222"
                }).GetAwaiter().GetResult();

                var tempProduct = productService.CreateAsync(new ProductInsertRequest
                {
                    Name = $"CRUD_TEMP_PRODUCT_{suffix}",
                    Description = "Temporary smoke-test product.",
                    Price = 9.99m,
                    StockQuantity = 7,
                    ImageUrl = null
                }).GetAwaiter().GetResult();

                var tempReservation = reservationService.CreateAsync(new ReservationInsertRequest
                {
                    CourtId = tempCourt.Id,
                    UserId = tempUser.Id,
                    StartTime = DateTime.UtcNow.AddDays(4),
                    EndTime = DateTime.UtcNow.AddDays(4).AddHours(1),
                    TotalPrice = tempCourt.HourlyRate,
                    Status = "Pending",
                    Notes = $"CRUD_TEMP_RESERVATION_{suffix}"
                }).GetAwaiter().GetResult();

                // Update
                courtService.UpdateAsync(tempCourt.Id, new CourtUpdateRequest
                {
                    Name = $"CRUD_TEMP_COURT_{suffix}_UPDATED",
                    Description = "Updated temporary smoke-test court.",
                    IsIndoor = false,
                    IsActive = true,
                    HourlyRate = 35m,
                    MaxPlayers = 4
                }).GetAwaiter().GetResult();

                userService.UpdateAsync(tempUser.Id, new UserUpdateRequest
                {
                    Username = $"crud_temp_user_{suffix}_UPDATED",
                    Email = $"crud_temp_user_{suffix}_UPDATED@padelclub.local",
                    FirstName = "Temp",
                    LastName = $"User_{suffix}_UPDATED",
                    PhoneNumber = "333444555",
                    Password = null,
                    IsActive = true,
                    UpdatedAt = DateTime.UtcNow
                }).GetAwaiter().GetResult();

                productService.UpdateAsync(tempProduct.Id, new ProductUpdateRequest
                {
                    Name = $"CRUD_TEMP_PRODUCT_{suffix}_UPDATED",
                    Description = "Updated temporary smoke-test product.",
                    Price = 11.50m,
                    StockQuantity = 3,
                    ImageUrl = null
                }).GetAwaiter().GetResult();

                reservationService.UpdateAsync(tempReservation.Id, new ReservationUpdateRequest
                {
                    CourtId = tempCourt.Id,
                    UserId = tempUser.Id,
                    StartTime = DateTime.UtcNow.AddDays(5),
                    EndTime = DateTime.UtcNow.AddDays(5).AddHours(1),
                    TotalPrice = 99m,
                    Status = "Confirmed",
                    Notes = $"CRUD_TEMP_RESERVATION_{suffix}_UPDATED"
                }).GetAwaiter().GetResult();

                // Read (ensure it exists)
                var courtRead = courtService.GetByIdAsync(tempCourt.Id).GetAwaiter().GetResult();
                var userRead = userService.GetByIdAsync(tempUser.Id).GetAwaiter().GetResult();
                var productRead = productService.GetByIdAsync(tempProduct.Id).GetAwaiter().GetResult();
                var reservationRead = reservationService.GetByIdAsync(tempReservation.Id).GetAwaiter().GetResult();

                if (courtRead == null || userRead == null || productRead == null || reservationRead == null)
                    logger.LogWarning("CRUD smoke test read check failed (one or more reads returned null).");

                // Delete (order matters due to Reservation foreign keys)
                reservationService.DeleteAsync(tempReservation.Id).GetAwaiter().GetResult();
                productService.DeleteAsync(tempProduct.Id).GetAwaiter().GetResult();
                courtService.DeleteAsync(tempCourt.Id).GetAwaiter().GetResult();
                userService.DeleteAsync(tempUser.Id).GetAwaiter().GetResult();

                logger.LogInformation("CRUD smoke test completed successfully (temp entities deleted).");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "CRUD smoke test failed.");
            }
        }

        private static void ApplyMigrationsWithRetry(PadelClubContext db, ILogger logger)
        {
            const int maxAttempts = 10;
            const int delayMilliseconds = 3000;

            for (var attempt = 1; attempt <= maxAttempts; attempt++)
            {
                try
                {
                    db.Database.Migrate();
                    return;
                }
                catch (Exception ex) when (attempt < maxAttempts)
                {
                    logger.LogWarning(
                        ex,
                        "Database migration attempt {Attempt} of {MaxAttempts} failed. Retrying in {DelayMilliseconds}ms.",
                        attempt,
                        maxAttempts,
                        delayMilliseconds);
                    Thread.Sleep(delayMilliseconds);
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "An error occurred while applying database migrations.");
                    throw;
                }
            }
        }
    }
}
