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
                "Server=localhost;Database=PadelClub;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True");

            return new PadelClubContext(optionsBuilder.Options);
        }
    }
}