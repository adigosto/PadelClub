using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PadelClub.Services.Database;

namespace PadelClub.Services
{
    public static class ServiceCollectionExtensions
    {
        /// <summary>
        /// Adds database-related services to the service collection.
        /// This includes the DbContext configuration and any database-related dependencies.
        /// </summary>
        /// <param name="services">The service collection to add services to.</param>
        /// <param name="configuration">The configuration instance to read connection strings from.</param>
        /// <returns>The service collection for chaining.</returns>
        public static IServiceCollection AddDatabaseServices(
            this IServiceCollection services,
            IConfiguration configuration)
        {
            // Get connection string from configuration
            var connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? "Server=DESKTOP-MPRVV8J;Database=PadelClub;Trusted_Connection=True;MultipleActiveResultSets=True;TrustServerCertificate=True";

            // Register DbContext with SQL Server provider
            services.AddDbContext<PadelClubContext>(options =>
                options.UseSqlServer(connectionString)
            );

            return services;
        }

        /// <summary>
        /// Adds database-related services to the service collection using a provided connection string.
        /// </summary>
        /// <param name="services">The service collection to add services to.</param>
        /// <param name="connectionString">The database connection string.</param>
        /// <returns>The service collection for chaining.</returns>
        public static IServiceCollection AddDatabaseServices(
            this IServiceCollection services,
            string connectionString)
        {
            // Register DbContext with SQL Server provider
            services.AddDbContext<PadelClubContext>(options =>
                options.UseSqlServer(connectionString)
            );

            return services;
        }
    }
}

