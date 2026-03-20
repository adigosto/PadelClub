namespace PadelClub.Model.Requests
{
    public class CourtUpdateRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public bool IsIndoor { get; set; }
        public bool IsActive { get; set; } = true;
        public decimal HourlyRate { get; set; }
        public int MaxPlayers { get; set; } = 4;
    }
}

