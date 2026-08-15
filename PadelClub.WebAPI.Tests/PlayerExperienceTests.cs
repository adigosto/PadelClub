using Microsoft.AspNetCore.Authorization;
using PadelClub.WebAPI.Controllers;
using PadelClub.WebAPI.PlayerExperience;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class PlayerExperienceTests
{
    [Theory]
    [InlineData("6-4, 3-6, 10-7", 1, true)]
    [InlineData("6-0, 6-0", 1, true)]
    [InlineData("6-4, 6-4", 2, false)]
    [InlineData("6-6, 6-4", 1, false)]
    [InlineData("6-4", 1, false)]
    public void Padel_scores_are_validated(string score, int winner, bool expected) =>
        Assert.Equal(expected, MatchScoreValidator.IsValid(score, winner));

    [Fact]
    public void Player_experience_requires_authentication() =>
        Assert.NotEmpty(typeof(PlayerExperienceController).GetCustomAttributes(typeof(AuthorizeAttribute), true));
}
