namespace PadelClub.WebAPI.PlayerExperience;

public static class MatchScoreValidator
{
    public static bool IsValid(string score, int winnerTeam)
    {
        if (winnerTeam is not (1 or 2)) return false;
        var sets = score.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        if (sets.Length is < 2 or > 3) return false;
        var wins = new[] { 0, 0 };
        foreach (var set in sets)
        {
            var parts = set.Split('-', StringSplitOptions.TrimEntries);
            if (parts.Length != 2 || !int.TryParse(parts[0], out var a) || !int.TryParse(parts[1], out var b) || a == b || a < 0 || b < 0 || Math.Max(a, b) > 20) return false;
            var high = Math.Max(a, b); var low = Math.Min(a, b);
            var valid = (high == 6 && low <= 4) || (high == 7 && low is 5 or 6) || (high >= 10 && high - low >= 2);
            if (!valid) return false;
            wins[a > b ? 0 : 1]++;
        }
        return wins[winnerTeam - 1] >= 2 && wins[winnerTeam - 1] > wins[2 - winnerTeam];
    }
}
