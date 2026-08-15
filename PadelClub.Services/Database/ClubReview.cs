namespace PadelClub.Services.Database
{
    public class ClubReview
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public int Rating { get; set; }
        public string Comment { get; set; } = string.Empty;
        public bool IsPublished { get; set; } = true;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }

        public virtual User User { get; set; } = null!;
    }
}
