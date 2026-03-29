using System;
using System.Linq;
using Mapster;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Requests;
using PadelClub.Services;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // Add services to the container.
            builder.Services.AddSingleton<IPasswordHasher, PasswordHasher>();
            builder.Services.AddTransient<IProductService, ProductService>();
            builder.Services.AddTransient<IUserService, UserService>();
            builder.Services.AddTransient<ICourtService, CourtService>();
            builder.Services.AddTransient<IReservationService, ReservationService>();
            
            var mapsterConfig = TypeAdapterConfig.GlobalSettings;
            mapsterConfig.Scan(typeof(Program).Assembly);
            builder.Services.AddSingleton(mapsterConfig);
            builder.Services.AddScoped<IMapper, ServiceMapper>();

            // Configure database services
            builder.Services.AddDatabaseServices(builder.Configuration);

            builder.Services.AddControllers()
                .AddJsonOptions(options =>
                {
                    // Handle circular references in navigation properties
                    options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
                });
            // Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen(c =>
            {
                c.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
                {
                    Title = "PadelClub API",
                    Version = "v1"
                });
                
                // Use full type names to avoid conflicts
                c.CustomSchemaIds(type => type.FullName?.Replace("+", "."));
            });

            var app = builder.Build();

            // Initialize database (with error handling that doesn't block Swagger)
            try
            {
                using (var scope = app.Services.CreateScope())
                {
                    var db = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
                    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
                    
                    // In development, create the database if it doesn't exist
                    if (app.Environment.IsDevelopment())
                    {
                        logger.LogInformation("Development environment detected. Ensuring database is up to date...");
                        try
                        {
                            db.Database.EnsureCreated();
                            
                            // Seed initial data if needed
                            SeedInitialData(db, logger);
                            
                            // Run an automated CRUD smoke test once (development only)
                            RunCrudSmokeTestsIfNeeded(db, scope.ServiceProvider, logger);
                        }
                        catch (Exception dbEx)
                        {
                            logger.LogWarning(dbEx, "Database initialization failed, but continuing. Swagger should still work.");
                        }
                    }
                    else
                    {
                        try
                        {
                            db.Database.EnsureCreated();
                        }
                        catch (Exception dbEx)
                        {
                            logger.LogWarning(dbEx, "Database initialization failed, but continuing.");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                var logger = app.Services.GetRequiredService<ILogger<Program>>();
                logger.LogError(ex, "An error occurred while initializing the database. The application will continue, but database operations may fail.");
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

            app.UseHttpsRedirection();

            app.UseAuthorization();

            // Redirect root to Swagger in development
            if (app.Environment.IsDevelopment())
            {
                app.MapGet("/", () => Results.Redirect("/swagger")).ExcludeFromDescription();
            }

            app.MapControllers();

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
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error seeding initial data.");
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

                var markerReservation = reservationService.CreateAsync(new PadelClub.Model.ReservationRequest
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

                var tempReservation = reservationService.CreateAsync(new PadelClub.Model.ReservationRequest
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

                reservationService.UpdateAsync(tempReservation.Id, new PadelClub.Model.ReservationRequest
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
    }
}
