using System.ComponentModel.DataAnnotations.Schema;

namespace PadelClub.Services.Database
{
    public class UserRole
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        [ForeignKey("UserId")]
        public virtual User User { get; set; } = null!;
        public int RoleId { get; set; }
        [ForeignKey("RoleId")]
        public virtual Role Role { get; set; } = null!;
        public DateTime DateAssigned { get; set; } = DateTime.UtcNow;
    }
}