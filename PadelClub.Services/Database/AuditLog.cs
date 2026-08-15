namespace PadelClub.Services.Database;

public class AuditLog
{
    public long Id { get; set; }
    public int? UserId { get; set; }
    public string Method { get; set; } = string.Empty;
    public string Path { get; set; } = string.Empty;
    public int StatusCode { get; set; }
    public string IpAddress { get; set; } = string.Empty;
    public string CorrelationId { get; set; } = string.Empty;
    public long DurationMs { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
