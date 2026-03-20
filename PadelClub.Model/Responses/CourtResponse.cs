using System;

namespace PadelClub.Model
{
    public class CourtResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public bool IsIndoor { get; set; }
        public bool IsActive { get; set; }
        public decimal HourlyRate { get; set; }
        public int MaxPlayers { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}

