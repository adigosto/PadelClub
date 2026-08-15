namespace PadelClub.Model
{
    public class UserRequest
    {
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string? Password { get; set; }
        public string? PhoneNumber { get; set; }
        public bool IsActive { get; set; } = true;
    }
}






