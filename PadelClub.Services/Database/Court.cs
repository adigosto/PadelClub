using System;

namespace PadelClub.Services.Database
{
    public class Court
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public bool IsIndoor { get; set; }
        public bool IsActive { get; set; } = true;
        public decimal HourlyRate { get; set; }
        public int MaxPlayers { get; set; } = 4; // Standard padel court capacity
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }

        // Navigation properties
        public virtual ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
    }
}

