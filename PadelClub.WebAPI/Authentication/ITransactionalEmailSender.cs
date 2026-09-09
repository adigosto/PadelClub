namespace PadelClub.WebAPI.Authentication;

public interface ITransactionalEmailSender
{
    Task SendPasswordResetAsync(string email, string token, CancellationToken cancellationToken);
    Task SendEmailVerificationAsync(string email, string token, CancellationToken cancellationToken);
}

/// <summary>
/// A transactional email channel was intentionally not configured. Callers
/// must not claim the email was sent or log the token as a development
/// substitute.
/// </summary>
public sealed class TransactionalEmailUnavailableException(string message) : InvalidOperationException(message);

public sealed class LoggingTransactionalEmailSender(ILogger<LoggingTransactionalEmailSender> logger)
    : ITransactionalEmailSender
{
    public Task SendPasswordResetAsync(string email, string token, CancellationToken cancellationToken)
    {
        logger.LogInformation("Password-reset email delivery is unavailable; no email was sent.");
        throw new TransactionalEmailUnavailableException("Transactional email delivery is unavailable.");
    }

    public Task SendEmailVerificationAsync(string email, string token, CancellationToken cancellationToken)
    {
        logger.LogInformation("Email-verification delivery is unavailable; no email was sent.");
        throw new TransactionalEmailUnavailableException("Transactional email delivery is unavailable.");
    }
}
