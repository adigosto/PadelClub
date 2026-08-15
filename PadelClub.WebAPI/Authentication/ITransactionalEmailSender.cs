namespace PadelClub.WebAPI.Authentication;

public interface ITransactionalEmailSender
{
    Task SendPasswordResetAsync(string email, string token, CancellationToken cancellationToken);
    Task SendEmailVerificationAsync(string email, string token, CancellationToken cancellationToken);
}

public sealed class LoggingTransactionalEmailSender(ILogger<LoggingTransactionalEmailSender> logger)
    : ITransactionalEmailSender
{
    public Task SendPasswordResetAsync(string email, string token, CancellationToken cancellationToken)
    {
        logger.LogInformation("Password reset requested for {Email}. Development token: {Token}", email, token);
        return Task.CompletedTask;
    }

    public Task SendEmailVerificationAsync(string email, string token, CancellationToken cancellationToken)
    {
        logger.LogInformation("Email verification requested for {Email}. Development token: {Token}", email, token);
        return Task.CompletedTask;
    }
}
