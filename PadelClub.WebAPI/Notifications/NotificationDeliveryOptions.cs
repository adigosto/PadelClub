namespace PadelClub.WebAPI.Notifications;

public sealed class NotificationDeliveryOptions
{
    public const string SectionName = "Notifications";
    public int PollSeconds { get; set; } = 10;
    public int MaxAttempts { get; set; } = 5;
    public string PublicAppUrl { get; set; } = "http://localhost:5000";
    public string FirebaseProjectId { get; set; } = string.Empty;
    public string FirebaseServiceAccountJson { get; set; } = string.Empty;
    public SmtpOptions Smtp { get; set; } = new();
}

public sealed class SmtpOptions
{
    public string Host { get; set; } = string.Empty;
    public int Port { get; set; } = 587;
    public bool UseStartTls { get; set; } = true;
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string FromAddress { get; set; } = "noreply@padelclub.local";
    public string FromName { get; set; } = "PadelClub";
}
