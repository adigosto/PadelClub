namespace PadelClub.Model.Requests
{
    public class NotificationUpdateRequest
    {
        public string Title { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public string Type { get; set; } = "System";
    }
}
