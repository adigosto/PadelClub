using System.ComponentModel.DataAnnotations;
using PadelClub.Model.Requests;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class AuthRequestValidationTests
{
    [Fact]
    public void Weak_reset_password_is_rejected()
    {
        var request = new ResetPasswordRequest { Token = new string('x', 48), NewPassword = "short" };
        Assert.False(Validator.TryValidateObject(request, new ValidationContext(request), [], true));
    }

    [Fact]
    public void Invalid_recovery_email_is_rejected()
    {
        var request = new ForgotPasswordRequest { Email = "not-an-email" };
        Assert.False(Validator.TryValidateObject(request, new ValidationContext(request), [], true));
    }
}
