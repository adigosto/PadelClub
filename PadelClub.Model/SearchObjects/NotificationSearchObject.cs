using System;

namespace PadelClub.Model.SearchObjects
{
    public class NotificationSearchObject : BaseSearchObject
    {
        public string? Type { get; set; }
        public bool? IsRead { get; set; }
        public DateTime? CreatedFrom { get; set; }
        public DateTime? CreatedTo { get; set; }
    }
}
