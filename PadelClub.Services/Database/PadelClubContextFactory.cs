using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace PadelClub.Services.Database
{
    public class PadelClubContextFactory : IDesignTimeDbContextFactory<PadelClubContext>
    {
        public PadelClubContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<PadelClubContext>();

            optionsBuilder.UseSqlServer(
                "Server=DESKTOP-MPRVV8J;Database=PadelClub;Trusted_Connection=True;MultipleActiveResultSets=True;TrustServerCertificate=True");

            return new PadelClubContext(optionsBuilder.Options);
        }
    }
}