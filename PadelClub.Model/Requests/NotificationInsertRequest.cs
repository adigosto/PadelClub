using System.Collections.Generic;

namespace PadelClub.Model.Requests
{
    public class NotificationInsertRequest
    {
        public string Title { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public string Type { get; set; } = "System";
        public List<int> RecipientUserIds { get; set; } = new();
    }
}
