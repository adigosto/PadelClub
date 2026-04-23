using System;
using System.Collections.Generic;

namespace PadelClub.Model.Requests
{
    public class UserInsertRequest
    {
        public string Username { get; set; } = string.Empty;
        public List<int> RoleIds { get; set; } = new List<int>();
        public string Email { get; set; } = string.Empty;
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string? PhoneNumber { get; set; }
    }
}


