using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Tournaments;

public interface IBracketService
{
    Task GenerateAsync(int tournamentId, CancellationToken ct);
    Task AdvanceWinnerAsync(Match match, CancellationToken ct);
}

public sealed class BracketService(PadelClubContext db) : IBracketService
{
    public async Task GenerateAsync(int tournamentId, CancellationToken ct)
    {
        var tournament = await db.Tournaments.Include(x => x.Participants).Include(x => x.Matches).SingleOrDefaultAsync(x => x.Id == tournamentId, ct)
            ?? throw new KeyNotFoundException("Tournament not found.");
        if (tournament.Matches.Any(x => x.BracketRound != null)) throw new InvalidOperationException("The bracket has already been generated.");
        var teams = tournament.Participants.Where(x => x.Status == "Confirmed" && x.TeamNumber.HasValue).GroupBy(x => x.TeamNumber!.Value)
            .Where(x => x.Count() == 2).OrderBy(x => x.Min(p => p.Seed ?? int.MaxValue)).ThenBy(x => x.Key).Select(x => x.ToList()).ToList();
        if (teams.Count < 2) throw new InvalidOperationException("At least two confirmed teams of two players are required.");
        if (tournament.Participants.Any(x => x.Status == "Confirmed") && teams.Sum(x => x.Count) != tournament.Participants.Count(x => x.Status == "Confirmed"))
            throw new InvalidOperationException("Every confirmed player must belong to a complete team.");
        var courtId = await db.Courts.Where(x => x.IsActive).OrderBy(x => x.Id).Select(x => (int?)x.Id).FirstOrDefaultAsync(ct)
            ?? throw new InvalidOperationException("An active court is required to generate a bracket.");

        var size = 1; while (size < teams.Count) size *= 2;
        var rounds = (int)Math.Log2(size);
        var matches = new Dictionary<(int Round, int Position), Match>();
        for (var round = 1; round <= rounds; round++)
        {
            var count = size >> round;
            for (var position = 1; position <= count; position++)
            {
                var match = new Match { TournamentId = tournamentId, CourtId = courtId, BracketRound = round, BracketPosition = position,
                    ScheduledTime = tournament.StartDate.AddHours((round - 1) * 24 + position - 1), Status = round == 1 ? "Scheduled" : "AwaitingPlayers" };
                matches[(round, position)] = match; db.Matches.Add(match);
            }
        }
        await db.SaveChangesAsync(ct);
        for (var round = 1; round < rounds; round++)
        foreach (var current in matches.Where(x => x.Key.Round == round))
        {
            current.Value.NextMatchId = matches[(round + 1, (current.Key.Position + 1) / 2)].Id;
            current.Value.NextMatchTeamNumber = current.Key.Position % 2 == 1 ? 1 : 2;
        }

        var firstRound = matches.Where(x => x.Key.Round == 1).OrderBy(x => x.Key.Position).Select(x => x.Value).ToList();
        var byes = size - teams.Count;
        var teamIndex = 0;
        for (var i = 0; i < firstRound.Count; i++)
        {
            var teamOne = teams[teamIndex++];
            AddTeam(firstRound[i], teamOne, 1);
            if (i >= byes) AddTeam(firstRound[i], teams[teamIndex++], 2);
        }
        await db.SaveChangesAsync(ct);
        foreach (var bye in firstRound.Where(x => x.Participants.Select(p => p.TeamNumber).Distinct().Count() == 1))
        {
            bye.IsBye = true; bye.Status = "Completed"; bye.WinnerTeamId = 1; bye.Score = "BYE"; bye.ResultStatus = "Confirmed"; bye.ResultConfirmedAt = DateTime.UtcNow;
            await AdvanceWinnerAsync(bye, ct);
        }
        tournament.Status = "Ongoing"; tournament.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task AdvanceWinnerAsync(Match match, CancellationToken ct)
    {
        if (match.WinnerTeamId is null) return;
        if (match.NextMatchId is null || match.NextMatchTeamNumber is null)
        {
            var tournament = await db.Tournaments.SingleAsync(x => x.Id == match.TournamentId, ct);
            tournament.Status = "Completed"; tournament.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            return;
        }
        if (!db.Entry(match).Collection(x => x.Participants).IsLoaded) await db.Entry(match).Collection(x => x.Participants).LoadAsync(ct);
        var next = await db.Matches.Include(x => x.Participants).SingleAsync(x => x.Id == match.NextMatchId, ct);
        if (next.Participants.Any(x => x.TeamNumber == match.NextMatchTeamNumber)) throw new InvalidOperationException("The next bracket slot is already occupied.");
        var winners = match.Participants.Where(x => x.TeamNumber == match.WinnerTeamId).ToList();
        foreach (var winner in winners) next.Participants.Add(new MatchParticipant { UserId = winner.UserId, TeamNumber = match.NextMatchTeamNumber.Value, Role = winner.Role });
        if (next.Participants.Select(x => x.TeamNumber).Distinct().Count() == 2) next.Status = "Scheduled";
        await db.SaveChangesAsync(ct);
    }

    private static void AddTeam(Match match, IEnumerable<TournamentParticipant> team, int teamNumber)
    {
        foreach (var player in team) match.Participants.Add(new MatchParticipant { UserId = player.UserId, TeamNumber = teamNumber, Role = "Player" });
    }
}
