using System;

namespace PadelClub.Model.Requests
{
    public class RoleInsertRequest
    {
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public bool IsActive { get; set; } = true;
    }
}
