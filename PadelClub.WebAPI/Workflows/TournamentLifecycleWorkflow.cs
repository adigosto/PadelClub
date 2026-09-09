using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Requests;
using PadelClub.Services;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Tournaments;
using PadelClub.WebAPI.Authentication;
using static PadelClub.WebAPI.Workflows.WorkflowResults;

namespace PadelClub.WebAPI.Workflows;

public sealed class TournamentLifecycleWorkflow(PadelClubContext db, IBracketService brackets, INotificationService notifications, ICurrentUser currentUser)
{
    /// <summary>
    /// Returns only the authenticated player's own tournament participation.
    /// The generic tournament catalogue deliberately does not expose team
    /// registration state, so this owner-scoped projection is the client
    /// contract for responding to an invite or withdrawing safely.
    /// </summary>


    public async Task<WorkflowResult> Mine(CancellationToken ct)
    {
        var userId = CurrentUserId();
        var registrations = await db.TournamentParticipants
            .AsNoTracking()
            .Where(participant => participant.UserId == userId)
            .OrderByDescending(participant => participant.Tournament.StartDate)
            .Select(participant => new
            {
                TournamentId = participant.TournamentId,
                TournamentName = participant.Tournament.Name,
                participant.Tournament.StartDate,
                participant.Tournament.RegistrationDeadline,
                TournamentStatus = participant.Tournament.Status,
                RegistrationStatus = participant.Status,
                participant.TeamNumber,
                // Older generic registrations can have no team number.  Do
                // not let SQL null equality turn another unteamed row into a
                // fictitious partner for the current player.
                PartnerName = participant.TeamNumber == null
                    ? null
                    : participant.Tournament.Participants
                        .Where(teammate =>
                            teammate.TeamNumber == participant.TeamNumber &&
                            teammate.UserId != userId)
                        .OrderBy(teammate => teammate.Id)
                        .Select(teammate => teammate.User.FirstName + " " + teammate.User.LastName)
                        .FirstOrDefault()
            })
            .ToListAsync(ct);

        return Ok(registrations);
    }


    public async Task<WorkflowResult> Register(int tournamentId, TournamentTeamRegistration request, CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (request.PartnerUserId == userId) return BadRequest("Choose another player as your partner.");
        await using var transaction = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, ct);
        var tournament = await db.Tournaments.Include(x => x.Participants).SingleOrDefaultAsync(x => x.Id == tournamentId, ct);
        if (tournament is null) return NotFound();
        if (tournament.Status != "Upcoming" || tournament.RegistrationDeadline <= DateTime.UtcNow) return Conflict("Registration is closed.");
        if (tournament.Participants.Any(x => x.UserId == userId || x.UserId == request.PartnerUserId)) return Conflict("One of these players is already registered.");
        if (tournament.Participants.Count(x => x.Status != "Withdrawn") + 2 > tournament.MaxParticipants) return Conflict("The tournament is full.");
        if (!await db.Users.AnyAsync(x => x.Id == request.PartnerUserId && x.IsActive && x.UserRoles.Any(r => r.Role.Name == "Player"), ct)) return BadRequest("The selected partner is unavailable.");
        var teamNumber = tournament.Participants.Max(x => (int?)x.TeamNumber).GetValueOrDefault() + 1;
        tournament.Participants.Add(new TournamentParticipant { UserId = userId, TeamNumber = teamNumber, Status = "Confirmed", ConfirmedAt = DateTime.UtcNow });
        tournament.Participants.Add(new TournamentParticipant { UserId = request.PartnerUserId, TeamNumber = teamNumber, Status = "Invited" });
        await db.SaveChangesAsync(ct); await transaction.CommitAsync(ct);
        await notifications.CreateAsync(new NotificationInsertRequest { Title = "Tournament team invitation", Message = $"You were invited to join {tournament.Name}.", Type = "Tournaments", RecipientUserIds = [request.PartnerUserId] });
        return NoContent();
    }


    public async Task<WorkflowResult> Respond(int tournamentId, TournamentRegistrationResponse request, CancellationToken ct)
    {
        var participant = await db.TournamentParticipants.Include(x => x.Tournament)
            .SingleOrDefaultAsync(x => x.TournamentId == tournamentId && x.UserId == CurrentUserId(), ct);
        if (participant is null) return NotFound();
        if (participant.Status != "Invited") return Conflict("This registration is not awaiting a response.");
        if (participant.Tournament.RegistrationDeadline <= DateTime.UtcNow) return Conflict("Registration is closed.");
        participant.Status = request.Accept ? "Confirmed" : "Withdrawn";
        participant.ConfirmedAt = request.Accept ? DateTime.UtcNow : null;
        await db.SaveChangesAsync(ct);
        return NoContent();
    }


    public async Task<WorkflowResult> Withdraw(int tournamentId, CancellationToken ct)
    {
        var userId = CurrentUserId();
        var tournament = await db.Tournaments.Include(x => x.Participants).SingleOrDefaultAsync(x => x.Id == tournamentId, ct);
        if (tournament is null) return NotFound();
        if (await db.Matches.AnyAsync(x => x.TournamentId == tournamentId && x.BracketRound != null, ct) || tournament.RegistrationDeadline <= DateTime.UtcNow) return Conflict("Withdrawal is closed.");
        var participant = tournament.Participants.SingleOrDefault(x => x.UserId == userId && x.Status != "Withdrawn");
        if (participant is null) return NotFound();
        var affected = participant.TeamNumber.HasValue
            ? tournament.Participants.Where(x => x.TeamNumber == participant.TeamNumber)
            : tournament.Participants.Where(x => x.Id == participant.Id);
        foreach (var teammate in affected) teammate.Status = "Withdrawn";
        await db.SaveChangesAsync(ct);
        return NoContent();
    }


    public async Task<WorkflowResult> Generate(int tournamentId, CancellationToken ct)
    {
        try { await brackets.GenerateAsync(tournamentId, ct); return NoContent(); }
        catch (KeyNotFoundException) { return NotFound(); }
        catch (InvalidOperationException ex) { return Conflict(ex.Message); }
    }

    public async Task<WorkflowResult> Bracket(int tournamentId, CancellationToken ct)
    {
        if (!await db.Tournaments.AnyAsync(x => x.Id == tournamentId, ct)) return NotFound();
        var result = await db.Matches.AsNoTracking().Where(x => x.TournamentId == tournamentId && x.BracketRound != null)
            .OrderBy(x => x.BracketRound).ThenBy(x => x.BracketPosition)
            .Select(x => new { x.Id, Round = x.BracketRound, Position = x.BracketPosition, x.ScheduledTime, x.Status, x.Score, x.WinnerTeamId, x.IsBye, x.NextMatchId, x.NextMatchTeamNumber,
                TeamOne = x.Participants.Where(p => p.TeamNumber == 1).Select(p => new { p.UserId, Name = p.User.FirstName + " " + p.User.LastName }),
                TeamTwo = x.Participants.Where(p => p.TeamNumber == 2).Select(p => new { p.UserId, Name = p.User.FirstName + " " + p.User.LastName }) }).ToListAsync(ct);
        return Ok(result);
    }

    private int CurrentUserId() => currentUser.Id;

}
