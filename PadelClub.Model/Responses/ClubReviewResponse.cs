using System;

namespace PadelClub.Model.Responses
{
    public class ClubReviewResponse
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string MemberName { get; set; } = string.Empty;
        public int Rating { get; set; }
        public string Comment { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
    }
}
