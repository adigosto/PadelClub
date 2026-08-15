using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;
using PadelClub.WebAPI.Authentication;

namespace PadelClub.WebAPI.Notifications;

public interface IEmailSender
{
    Task<string?> SendAsync(string recipient, string subject, string text, CancellationToken cancellationToken);
}

public sealed class SmtpEmailSender(IOptions<NotificationDeliveryOptions> options, ILogger<SmtpEmailSender> logger)
    : IEmailSender, ITransactionalEmailSender
{
    private readonly NotificationDeliveryOptions _options = options.Value;

    public async Task<string?> SendAsync(string recipient, string subject, string text, CancellationToken cancellationToken)
    {
        var smtp = _options.Smtp;
        if (string.IsNullOrWhiteSpace(smtp.Host))
        {
            logger.LogInformation("Email to {Recipient}: {Subject}. Development body: {Body}", recipient, subject, text);
            return "development-log";
        }

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(smtp.FromName, smtp.FromAddress));
        message.To.Add(MailboxAddress.Parse(recipient));
        message.Subject = subject;
        message.Body = new TextPart("plain") { Text = text };

        using var client = new SmtpClient();
        var socket = smtp.UseStartTls ? SecureSocketOptions.StartTls : SecureSocketOptions.Auto;
        await client.ConnectAsync(smtp.Host, smtp.Port, socket, cancellationToken);
        if (!string.IsNullOrWhiteSpace(smtp.Username))
            await client.AuthenticateAsync(smtp.Username, smtp.Password, cancellationToken);
        var id = await client.SendAsync(message, cancellationToken);
        await client.DisconnectAsync(true, cancellationToken);
        return id;
    }

    public Task SendPasswordResetAsync(string email, string token, CancellationToken cancellationToken) =>
        SendAsync(email, "Reset your PadelClub password", $"Use this token to reset your password:\n\n{token}\n\nIf you did not request this, ignore this message.", cancellationToken);

    public Task SendEmailVerificationAsync(string email, string token, CancellationToken cancellationToken) =>
        SendAsync(email, "Verify your PadelClub email", $"Use this token to verify your email:\n\n{token}", cancellationToken);
}
