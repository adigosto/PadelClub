using System.Linq;
using Microsoft.EntityFrameworkCore;
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
            builder.Services.AddTransient<IProductService, DummyProductService>();
            builder.Services.AddTransient<IUserService, UserService>();
            builder.Services.AddTransient<ICourtService, CourtService>();
            builder.Services.AddTransient<IReservationService, ReservationService>();

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
                    
                    // In development, drop and recreate database to handle schema changes
                    if (app.Environment.IsDevelopment())
                    {
                        logger.LogInformation("Development environment detected. Ensuring database is up to date...");
                        try
                        {
                            db.Database.EnsureDeleted();
                            db.Database.EnsureCreated();
                            
                            // Seed initial data if needed
                            SeedInitialData(db, logger);
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
                // Check if data already exists
                if (db.ProductCategories.Any() || db.ProductTypes.Any())
                {
                    logger.LogInformation("Database already contains seed data.");
                    return;
                }

                // Seed ProductCategories
                var categories = new[]
                {
                    new PadelClub.Services.Database.ProductCategory { Name = "Equipment", Description = "Padel equipment and gear" },
                    new PadelClub.Services.Database.ProductCategory { Name = "Merchandise", Description = "Club merchandise" },
                    new PadelClub.Services.Database.ProductCategory { Name = "Accessories", Description = "Padel accessories" }
                };
                db.ProductCategories.AddRange(categories);

                // Seed ProductTypes
                var types = new[]
                {
                    new PadelClub.Services.Database.ProductType { Name = "Rackets", Description = "Padel rackets" },
                    new PadelClub.Services.Database.ProductType { Name = "Balls", Description = "Padel balls" },
                    new PadelClub.Services.Database.ProductType { Name = "Apparel", Description = "Clothing and apparel" },
                    new PadelClub.Services.Database.ProductType { Name = "Shoes", Description = "Padel shoes" }
                };
                db.ProductTypes.AddRange(types);

                db.SaveChanges();
                logger.LogInformation("Successfully seeded initial ProductCategory and ProductType data.");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error seeding initial data.");
            }
        }
    }
}
