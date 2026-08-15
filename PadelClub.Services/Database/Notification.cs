namespace PadelClub.Services.Database
{
    public class Notification
    {
        public int Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public string Type { get; set; } = "System";
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }

        public virtual ICollection<NotificationRecipient> Recipients { get; set; } = new List<NotificationRecipient>();
        public virtual ICollection<NotificationDelivery> Deliveries { get; set; } = new List<NotificationDelivery>();
    }
}
