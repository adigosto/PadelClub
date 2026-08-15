using System;

namespace PadelClub.Model
{
    public class NotificationResponse
    {
        public int Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public string Type { get; set; } = "System";
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
        public int RecipientCount { get; set; }
        public int ReadCount { get; set; }
        public bool? IsRead { get; set; }
        public DateTime? ReadAt { get; set; }
    }
}
