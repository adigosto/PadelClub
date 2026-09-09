using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Requests;
using PadelClub.Services;
using PadelClub.Services.Database;
using PadelClub.WebAPI.PlayerExperience;
using PadelClub.WebAPI.Tournaments;
using PadelClub.WebAPI.Authentication;
using static PadelClub.WebAPI.Workflows.WorkflowResults;

namespace PadelClub.WebAPI.Workflows;

public sealed class PlayerExperienceWorkflow(PadelClubContext db, INotificationService notifications, IBracketService brackets, ICurrentUser currentUser)
{
    private static readonly string[] Levels = ["Beginner", "Intermediate", "Advanced", "Competitive"];
    private static readonly string[] Sides = ["Left", "Right", "Either"];

    public async Task<WorkflowResult> Cities(CancellationToken ct) =>
        Ok(await db.Cities.AsNoTracking().Where(x => x.IsActive).OrderBy(x => x.Name)
            .Select(x => new { x.Id, x.Name }).ToListAsync(ct));

    public async Task<WorkflowResult> Profile(CancellationToken ct)
    {
        var userId = CurrentUserId();
        var profile = await db.PlayerProfiles.AsNoTracking().Include(x => x.User).Include(x => x.City).SingleOrDefaultAsync(x => x.UserId == userId, ct);
        return profile is null ? NotFound("Complete player onboarding first.") : Ok(ProfileResponse(profile));
    }

    public async Task<WorkflowResult> SaveProfile(PlayerProfileRequest request, CancellationToken ct)
    {
        var level = Canonical(request.SkillLevel, Levels);
        var side = Canonical(request.PreferredSide, Sides);
        if (level is null || side is null) return BadRequest("Invalid skill level or preferred side.");
        if (request.Bio.Trim().Length > 500 || request.Availability.Trim().Length > 300)
            return BadRequest("Profile content is invalid or too long.");

        var city = await db.Cities.SingleOrDefaultAsync(x => x.Id == request.CityId && x.IsActive, ct);
        if (city is null) return BadRequest("Select an active city.");

        var userId = CurrentUserId();
        var profile = await db.PlayerProfiles.Include(x => x.User).Include(x => x.City).SingleOrDefaultAsync(x => x.UserId == userId, ct);
        if (profile is null)
        {
            profile = new PlayerProfile { UserId = userId };
            db.PlayerProfiles.Add(profile);
            profile.User = await db.Users.SingleAsync(x => x.Id == userId, ct);
        }
        profile.SkillLevel = level; profile.PreferredSide = side; profile.CityId = city.Id; profile.City = city;
        profile.Bio = request.Bio.Trim(); profile.Availability = request.Availability.Trim();
        profile.IsDiscoverable = request.IsDiscoverable; profile.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        return Ok(ProfileResponse(profile));
    }

    public async Task<WorkflowResult> Partners(string? skillLevel, string? city, string? query, CancellationToken ct)
    {
        var userId = CurrentUserId();
        var profiles = db.PlayerProfiles.AsNoTracking().Where(x => x.IsDiscoverable && x.UserId != userId && x.User.IsActive);
        if (!string.IsNullOrWhiteSpace(skillLevel)) profiles = profiles.Where(x => x.SkillLevel == skillLevel);
        if (!string.IsNullOrWhiteSpace(city)) profiles = profiles.Where(x => x.City.Name.Contains(city.Trim()));
        if (!string.IsNullOrWhiteSpace(query))
        {
            var term = query.Trim();
            profiles = profiles.Where(x => x.User.FirstName.Contains(term) || x.User.LastName.Contains(term) || x.User.Username.Contains(term));
        }
        var result = await profiles.OrderByDescending(x => x.Rating).ThenBy(x => x.User.FirstName).Take(50)
            .Select(x => new { x.UserId, PlayerName = x.User.FirstName + " " + x.User.LastName, x.SkillLevel, x.PreferredSide, x.CityId, City = x.City.Name, x.Bio, x.Availability, x.Rating }).ToListAsync(ct);
        return Ok(result);
    }

    public async Task<WorkflowResult> Invite(int recipientUserId, PartnerInviteRequest request, CancellationToken ct)
    {
        var senderId = CurrentUserId();
        if (recipientUserId == senderId) return BadRequest("You cannot invite yourself.");
        if (!await db.PlayerProfiles.AnyAsync(x => x.UserId == recipientUserId && x.IsDiscoverable && x.User.IsActive, ct)) return NotFound();
        if (request.Message.Trim().Length > 500) return BadRequest("Message is too long.");
        if (await db.PartnerInvitations.AnyAsync(x => x.SenderUserId == senderId && x.RecipientUserId == recipientUserId && x.Status == "Pending", ct))
            return Conflict("A pending invitation already exists.");
        var invitation = new PartnerInvitation { SenderUserId = senderId, RecipientUserId = recipientUserId, Message = request.Message.Trim() };
        db.PartnerInvitations.Add(invitation);
        await db.SaveChangesAsync(ct);
        await notifications.CreateAsync(new NotificationInsertRequest { Title = "New partner invitation", Message = "A player would like to connect and play padel with you.", Type = "Partners", RecipientUserIds = [recipientUserId] });
        return Ok(new { invitation.Id, invitation.Status, invitation.CreatedAt });
    }

    public async Task<WorkflowResult> Invitations(CancellationToken ct)
    {
        var userId = CurrentUserId();
        return Ok(await db.PartnerInvitations.AsNoTracking().Where(x => x.SenderUserId == userId || x.RecipientUserId == userId)
            .OrderByDescending(x => x.CreatedAt).Take(100).Select(x => new { x.Id, x.SenderUserId, SenderName = x.Sender.FirstName + " " + x.Sender.LastName, x.RecipientUserId, RecipientName = x.Recipient.FirstName + " " + x.Recipient.LastName, x.Message, x.Status, x.CreatedAt, x.RespondedAt }).ToListAsync(ct));
    }

    public async Task<WorkflowResult> Respond(int id, PartnerInviteResponse request, CancellationToken ct)
    {
        var status = request.Accept ? "Accepted" : "Declined";
        var invitation = await db.PartnerInvitations.SingleOrDefaultAsync(x => x.Id == id && x.RecipientUserId == CurrentUserId(), ct);
        if (invitation is null) return NotFound();
        if (invitation.Status != "Pending") return Conflict("This invitation has already been answered.");
        invitation.Status = status; invitation.RespondedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        await notifications.CreateAsync(new NotificationInsertRequest { Title = $"Partner invitation {status.ToLowerInvariant()}", Message = $"Your partner invitation was {status.ToLowerInvariant()}.", Type = "Partners", RecipientUserIds = [invitation.SenderUserId] });
        return NoContent();
    }

    public async Task<WorkflowResult> MatchHistory(CancellationToken ct)
    {
        var userId = CurrentUserId();
        return Ok(await db.Matches.AsNoTracking().Where(x => x.Participants.Any(p => p.UserId == userId)).OrderByDescending(x => x.ScheduledTime).Take(100)
            .Select(x => new { x.Id, TournamentName = x.Tournament.Name, CourtName = x.Court.Name, x.ScheduledTime, x.Status, x.Score, x.WinnerTeamId, x.ResultStatus,
                CanConfirmResult = x.ResultStatus == "PendingConfirmation" && x.ReportedByUserId.HasValue &&
                    x.Participants.Any(reporter => reporter.UserId == x.ReportedByUserId && (reporter.TeamNumber == 1 || reporter.TeamNumber == 2) &&
                        x.Participants.Any(confirmer => confirmer.UserId == userId && confirmer.TeamNumber == 3 - reporter.TeamNumber)),
                x.TeamOneRatingChange, x.TeamTwoRatingChange,
                TeamOne = x.Participants.Where(p => p.TeamNumber == 1).Select(p => p.User.FirstName + " " + p.User.LastName), TeamTwo = x.Participants.Where(p => p.TeamNumber == 2).Select(p => p.User.FirstName + " " + p.User.LastName) }).ToListAsync(ct));
    }

    public async Task<WorkflowResult> ReportResult(int matchId, MatchResultRequest request, CancellationToken ct)
    {
        var userId = CurrentUserId();
        var match = await db.Matches.Include(x => x.Participants).SingleOrDefaultAsync(x => x.Id == matchId, ct);
        if (match is null) return NotFound();
        if (!match.Participants.Any(x => x.UserId == userId)) return Forbid();
        if (match.IsBye || match.Status is not ("Scheduled" or "InProgress") || match.Participants.Select(x => x.TeamNumber).Distinct().Count() != 2)
            return Conflict("This match is not ready for result reporting.");
        if (match.ResultStatus is "PendingConfirmation" or "Confirmed") return Conflict("A result has already been submitted.");
        if (!MatchScoreValidator.IsValid(request.Score, request.WinnerTeamId)) return BadRequest("Use a valid padel score such as 6-4, 3-6, 10-7 and the matching winning team.");
        match.ProposedScore = request.Score.Trim(); match.ProposedWinnerTeamId = request.WinnerTeamId;
        match.ReportedByUserId = userId; match.ResultReportedAt = DateTime.UtcNow; match.ResultStatus = "PendingConfirmation";
        await db.SaveChangesAsync(ct);
        var recipients = match.Participants.Where(x => x.UserId != userId).Select(x => x.UserId).Distinct().ToList();
        if (recipients.Count > 0) await notifications.CreateAsync(new NotificationInsertRequest { Title = "Match result needs confirmation", Message = $"A score of {match.ProposedScore} was reported. Confirm it from your match history.", Type = "Matches", RecipientUserIds = recipients });
        return NoContent();
    }

    public async Task<WorkflowResult> ConfirmResult(int matchId, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, ct);
        var userId = CurrentUserId();
        var match = await db.Matches.Include(x => x.Participants).SingleOrDefaultAsync(x => x.Id == matchId, ct);
        if (match is null) return NotFound();
        var reporter = match.Participants.SingleOrDefault(x => x.UserId == match.ReportedByUserId);
        var confirmer = match.Participants.SingleOrDefault(x => x.UserId == userId);
        if (reporter is null || reporter.TeamNumber is not (1 or 2) ||
            confirmer is null || confirmer.TeamNumber != 3 - reporter.TeamNumber) return Forbid();
        if (match.ResultStatus != "PendingConfirmation" || match.ProposedWinnerTeamId is null || match.ProposedScore is null) return Conflict("There is no result awaiting confirmation.");

        var ids = match.Participants.Select(x => x.UserId).Distinct().ToList();
        var profiles = await db.PlayerProfiles.Where(x => ids.Contains(x.UserId)).ToDictionaryAsync(x => x.UserId, ct);
        foreach (var id in ids.Where(id => !profiles.ContainsKey(id))) { var p = new PlayerProfile { UserId = id, IsDiscoverable = false }; db.PlayerProfiles.Add(p); profiles[id] = p; }
        var teamOne = match.Participants.Where(x => x.TeamNumber == 1).Select(x => profiles[x.UserId]).ToList();
        var teamTwo = match.Participants.Where(x => x.TeamNumber == 2).Select(x => profiles[x.UserId]).ToList();
        if (teamOne.Count == 0 || teamTwo.Count == 0) return Conflict("Both teams require participants.");
        var ratingOne = teamOne.Average(x => x.Rating); var ratingTwo = teamTwo.Average(x => x.Rating);
        var expectedOne = 1d / (1d + Math.Pow(10d, (ratingTwo - ratingOne) / 400d));
        var changeOne = (int)Math.Round(32 * ((match.ProposedWinnerTeamId == 1 ? 1d : 0d) - expectedOne));
        foreach (var p in teamOne) p.Rating = Math.Max(100, p.Rating + changeOne);
        foreach (var p in teamTwo) p.Rating = Math.Max(100, p.Rating - changeOne);
        match.Score = match.ProposedScore; match.WinnerTeamId = match.ProposedWinnerTeamId; match.Status = "Completed";
        match.ActualEndTime ??= DateTime.UtcNow; match.ResultStatus = "Confirmed"; match.ResultConfirmedAt = DateTime.UtcNow;
        match.TeamOneRatingChange = changeOne; match.TeamTwoRatingChange = -changeOne;
        await db.SaveChangesAsync(ct);
        await brackets.AdvanceWinnerAsync(match, ct);
        await transaction.CommitAsync(ct);
        return NoContent();
    }

    private static string? Canonical(string value, IEnumerable<string> choices) => choices.FirstOrDefault(x => x.Equals(value.Trim(), StringComparison.OrdinalIgnoreCase));
    private int CurrentUserId() => currentUser.Id;
    private static object ProfileResponse(PlayerProfile x) => new { x.UserId, PlayerName = x.User.FirstName + " " + x.User.LastName, x.SkillLevel, x.PreferredSide, x.CityId, City = x.City.Name, x.Bio, x.Availability, x.IsDiscoverable, x.Rating, x.UpdatedAt };

}
