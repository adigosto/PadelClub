using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Authentication;
using PadelClub.WebAPI.Notifications;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public sealed class PasswordResetDeliveryTests
{
    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Unconfigured_delivery_keeps_anonymous_reset_acknowledgement(bool smtpSender)
    {
        await using var db = new PadelClubContext(new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N")).Options);
        db.Users.Add(new User
        {
            Id = 1, Username = "reset-player", Email = "reset@example.test",
            FirstName = "Reset", LastName = "Player", PasswordHash = "hash",
            PasswordSalt = "salt", IsActive = true
        });
        await db.SaveChangesAsync();
        ITransactionalEmailSender sender = smtpSender
            ? new SmtpEmailSender(Options.Create(new NotificationDeliveryOptions()), NullLogger<SmtpEmailSender>.Instance)
            : new LoggingTransactionalEmailSender(NullLogger<LoggingTransactionalEmailSender>.Instance);
        var service = new AuthService(db, null!, null!, Options.Create(new AuthOptions()), sender);

        await service.RequestPasswordResetAsync("reset@example.test", CancellationToken.None);
        await service.RequestPasswordResetAsync("missing@example.test", CancellationToken.None);

        Assert.Single(db.AuthTokens);
    }
}
