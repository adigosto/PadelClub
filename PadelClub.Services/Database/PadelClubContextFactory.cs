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
                "Server=host.docker.internal,1433;Database=PadelClub;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;MultipleActiveResultSets=True");

            return new PadelClubContext(optionsBuilder.Options);
        }
    }
}