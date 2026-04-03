using System;

namespace PadelClub.Model.SearchObjects
{
    public class TournamentSearchObject : BaseSearchObject
    {
        public string? Name { get; set; }
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
                
    }
}

