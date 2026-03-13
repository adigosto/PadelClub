namespace PadelClub.Model.SearchObjects
{
    public class CourtSearchObject : BaseSearchObject
    {
        public string? Name { get; set; }
        public bool? IsIndoor { get; set; }
        public bool? IsActive { get; set; }
    }
}

