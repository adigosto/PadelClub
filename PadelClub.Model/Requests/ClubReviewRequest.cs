using System.ComponentModel.DataAnnotations;

namespace PadelClub.Model.Requests
{
    public class ClubReviewRequest
    {
        [Range(1, 5)]
        public int Rating { get; set; }

        [Required]
        [MaxLength(600)]
        public string Comment { get; set; } = string.Empty;
    }
}
