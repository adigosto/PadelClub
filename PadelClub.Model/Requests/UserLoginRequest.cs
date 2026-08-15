namespace PadelClub.Model.Requests
{
    using System.ComponentModel.DataAnnotations;

    public class UserLoginRequest
    {
        [Required, StringLength(100, MinimumLength = 1)]
        public string Username { get; set; } = null!;
        [Required, StringLength(256, MinimumLength = 1)]
        public string Password { get; set; } = null!;
    }
}
