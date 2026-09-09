using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.Services.Recommendations;

/// <summary>
/// Implements the single, pre-registered CF-vs-popularity experiment. It
/// deliberately starts empty: no seed, test, legacy, administrator, or
/// unconsented customer can be assigned or later counted as experiment data.
/// </summary>
public sealed class RecommendationExperimentService : IRecommendationExperimentService
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly PadelClubContext _db;
    private readonly IRecommendationExperimentRandomizer _randomizer;

    public RecommendationExperimentService(PadelClubContext db)
        : this(db, new CryptographicRecommendationExperimentRandomizer())
    {
    }

    public RecommendationExperimentService(
        PadelClubContext db,
        IRecommendationExperimentRandomizer randomizer)
    {
        _db = db;
        _randomizer = randomizer;
    }

    public async Task<RecommendationAnalyticsConsentResponse> GetConsentAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        var consent = await _db.RecommendationAnalyticsConsents
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.UserId == userId, cancellationToken);
        return ToConsentResponse(consent);
    }

    public async Task<RecommendationAnalyticsConsentResponse> SetConsentAsync(
        int userId,
        bool isGranted,
        CancellationToken cancellationToken = default)
    {
        var consent = await _db.RecommendationAnalyticsConsents
            .SingleOrDefaultAsync(item => item.UserId == userId, cancellationToken);
        var now = DateTime.UtcNow;
        if (consent is null)
        {
            consent = new RecommendationAnalyticsConsent
            {
                UserId = userId,
                PolicyVersion = RecommendationExperimentPolicy.ConsentPolicyVersion,
                UpdatedAtUtc = now
            };
            _db.RecommendationAnalyticsConsents.Add(consent);
        }

        consent.PolicyVersion = RecommendationExperimentPolicy.ConsentPolicyVersion;
        consent.UpdatedAtUtc = now;
        if (isGranted)
        {
            // A re-grant after revocation starts a fresh consent period. An
            // idempotent repeat grant preserves the original grant time.
            // Historic assignment facts remain immutable, but no new
            // experimental serving happens while consent is revoked.
            if (consent.GrantedAtUtc is null || consent.RevokedAtUtc is not null)
                consent.GrantedAtUtc = now;
            consent.RevokedAtUtc = null;
        }
        else
        {
            consent.RevokedAtUtc = now;
        }

        await _db.SaveChangesAsync(cancellationToken);
        return ToConsentResponse(consent);
    }

    public async Task<RecommendationExperimentAssignmentContext?> GetActiveAssignmentAsync(
        int userId,
        RecommendationTelemetrySource telemetrySource,
        int recommendationLimit,
        CancellationToken cancellationToken = default)
    {
        // The source is calculated by ProductRecommendationService from the
        // deployment and account; a caller cannot submit a customer label.
        if (telemetrySource != RecommendationTelemetrySource.OperationalCustomer)
            return null;

        var consentActive = await _db.RecommendationAnalyticsConsents
            .AsNoTracking()
            .AnyAsync(item =>
                item.UserId == userId &&
                item.GrantedAtUtc != null &&
                item.RevokedAtUtc == null,
                cancellationToken);
        if (!consentActive)
            return null;

        var now = DateTime.UtcNow;
        var experiment = await _db.RecommendationExperiments
            .AsNoTracking()
            .SingleOrDefaultAsync(item =>
                item.Status == RecommendationExperimentStatuses.Running &&
                item.StartedAtUtc != null &&
                item.StartedAtUtc <= now &&
                item.ClosedAtUtc == null,
                cancellationToken);
        if (experiment is null || recommendationLimit != experiment.RecommendationLimit)
            return null;

        var assignment = await _db.RecommendationExperimentAssignments
            .SingleOrDefaultAsync(item =>
                item.ExperimentId == experiment.Id && item.UserId == userId,
                cancellationToken);
        if (assignment is null)
        {
            assignment = new RecommendationExperimentAssignment
            {
                ExperimentId = experiment.Id,
                UserId = userId,
                Variant = _randomizer.NextTreatmentPercent(experiment.TreatmentAllocationPercent)
                    ? RecommendationExperimentVariant.Treatment
                    : RecommendationExperimentVariant.Control,
                AssignedAtUtc = now
            };
            _db.RecommendationExperimentAssignments.Add(assignment);
            try
            {
                await _db.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateException)
            {
                // The unique (ExperimentId, UserId) constraint is the final
                // concurrency guard. If another request won the assignment,
                // discard this unsaved arm and use the durable original.
                _db.ChangeTracker.Clear();
                assignment = await _db.RecommendationExperimentAssignments
                    .SingleOrDefaultAsync(item =>
                        item.ExperimentId == experiment.Id && item.UserId == userId,
                        cancellationToken);
                if (assignment is null)
                    throw;
            }
        }

        return ToServingContext(assignment, experiment);
    }

    public async Task<RecommendationExperimentResponse> CreateAsync(
        int createdByUserId,
        CancellationToken cancellationToken = default)
    {
        var existing = await _db.RecommendationExperiments
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.ExperimentKey == RecommendationExperimentPolicy.ExperimentKey, cancellationToken);
        if (existing is not null)
            throw new InvalidOperationException("The fixed recommendation experiment is already registered.");

        var experiment = new RecommendationExperiment
        {
            ExperimentKey = RecommendationExperimentPolicy.ExperimentKey,
            Status = RecommendationExperimentStatuses.Draft,
            CreatedByUserId = createdByUserId,
            CreatedAtUtc = DateTime.UtcNow,
            Protocol = RecommendationExperimentPolicy.Protocol,
            TreatmentAlgorithmVersion = ItemBasedCollaborativeRanker.Version,
            ControlAlgorithmVersion = PopularityRecommendationRanker.Version,
            TreatmentStrategy = RecommendationExperimentPolicy.TreatmentStrategy,
            ControlStrategy = RecommendationExperimentPolicy.ControlStrategy,
            TreatmentAllocationPercent = RecommendationExperimentPolicy.TreatmentAllocationPercent,
            RecommendationLimit = RecommendationExperimentPolicy.RecommendationLimit,
            AttributionWindowDays = RecommendationExperimentPolicy.AttributionWindowDays,
            ReturnMaturityDays = RecommendationExperimentPolicy.ReturnMaturityDays,
            ConfigurationSha256 = Sha256(RecommendationExperimentPolicy.ConfigurationMaterial)
        };
        _db.RecommendationExperiments.Add(experiment);
        await _db.SaveChangesAsync(cancellationToken);
        return ToExperimentResponse(experiment);
    }

    public async Task<RecommendationExperimentResponse?> GetAsync(
        Guid experimentId,
        CancellationToken cancellationToken = default)
    {
        var experiment = await _db.RecommendationExperiments
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == experimentId, cancellationToken);
        return experiment is null ? null : ToExperimentResponse(experiment);
    }

    public async Task<RecommendationExperimentResponse> StartAsync(
        Guid experimentId,
        CancellationToken cancellationToken = default)
    {
        var experiment = await _db.RecommendationExperiments
            .SingleOrDefaultAsync(item => item.Id == experimentId, cancellationToken)
            ?? throw new KeyNotFoundException("Recommendation experiment was not found.");
        if (experiment.Status != RecommendationExperimentStatuses.Draft)
            throw new InvalidOperationException("Only a draft recommendation experiment can be started.");

        var anotherExperimentIsRunning = await _db.RecommendationExperiments
            .AsNoTracking()
            .AnyAsync(item =>
                item.Id != experimentId && item.Status == RecommendationExperimentStatuses.Running,
                cancellationToken);
        if (anotherExperimentIsRunning)
            throw new InvalidOperationException("Another recommendation experiment is already running.");

        experiment.Status = RecommendationExperimentStatuses.Running;
        experiment.StartedAtUtc = DateTime.UtcNow;
        try
        {
            await _db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            // The filtered unique database index is the final protection when
            // two administrators try to start drafts concurrently.
            throw new InvalidOperationException("Another recommendation experiment is already running.");
        }
        return ToExperimentResponse(experiment);
    }

    public async Task<RecommendationExperimentResponse> CloseAsync(
        Guid experimentId,
        CancellationToken cancellationToken = default)
    {
        var experiment = await _db.RecommendationExperiments
            .SingleOrDefaultAsync(item => item.Id == experimentId, cancellationToken)
            ?? throw new KeyNotFoundException("Recommendation experiment was not found.");
        if (experiment.Status != RecommendationExperimentStatuses.Running)
            throw new InvalidOperationException("Only a running recommendation experiment can be closed.");

        experiment.Status = RecommendationExperimentStatuses.Closed;
        experiment.ClosedAtUtc = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
        return ToExperimentResponse(experiment);
    }

    public async Task<RecommendationExperimentImpactResponse?> GetImpactAsync(
        Guid experimentId,
        CancellationToken cancellationToken = default)
    {
        var experiment = await _db.RecommendationExperiments
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == experimentId, cancellationToken);
        return experiment is null
            ? null
            : await BuildImpactAsync(experiment, cancellationToken);
    }

    public async Task<RecommendationExperimentAnalysisRunResponse?> CreateAnalysisRunAsync(
        int executedByUserId,
        Guid experimentId,
        CancellationToken cancellationToken = default)
    {
        var experiment = await _db.RecommendationExperiments
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == experimentId, cancellationToken);
        if (experiment is null)
            return null;

        string inputFingerprint = string.Empty;
        var report = await BuildImpactAsync(experiment, cancellationToken, value => inputFingerprint = value);
        var reportJson = JsonSerializer.Serialize(report, JsonOptions);
        var run = new RecommendationExperimentAnalysisRun
        {
            ExperimentId = experimentId,
            ExecutedByUserId = executedByUserId,
            ExecutedAtUtc = DateTime.UtcNow,
            EvidenceTier = report.EvidenceTier,
            Protocol = experiment.Protocol,
            ConfigurationSha256 = experiment.ConfigurationSha256,
            InputFingerprintSha256 = inputFingerprint,
            ReportJson = reportJson
        };
        _db.RecommendationExperimentAnalysisRuns.Add(run);
        await _db.SaveChangesAsync(cancellationToken);
        return ToAnalysisRunResponse(run, report);
    }

    public async Task<RecommendationExperimentAnalysisRunResponse?> GetLatestAnalysisRunAsync(
        Guid experimentId,
        CancellationToken cancellationToken = default)
    {
        var run = await _db.RecommendationExperimentAnalysisRuns
            .AsNoTracking()
            .Where(item => item.ExperimentId == experimentId)
            .OrderByDescending(item => item.ExecutedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        if (run is null)
            return null;

        var report = JsonSerializer.Deserialize<RecommendationExperimentImpactResponse>(run.ReportJson, JsonOptions)
            ?? throw new InvalidOperationException("Stored recommendation experiment analysis is invalid.");
        return ToAnalysisRunResponse(run, report);
    }

    private async Task<RecommendationExperimentImpactResponse> BuildImpactAsync(
        RecommendationExperiment experiment,
        CancellationToken cancellationToken,
        Action<string>? captureInputFingerprint = null)
    {
        var now = DateTime.UtcNow;
        var maturityBoundary = now.AddDays(-experiment.AttributionWindowDays);
        var assignments = await _db.RecommendationExperimentAssignments
            .AsNoTracking()
            .Where(item => item.ExperimentId == experiment.Id)
            .Select(item => new AssignmentRow(item.UserId, item.Variant))
            .ToListAsync(cancellationToken);
        var exposures = await _db.RecommendationExposures
            .AsNoTracking()
            .Where(item =>
                item.ExperimentAssignmentId != null &&
                item.ExperimentAssignment!.ExperimentId == experiment.Id &&
                item.UserId == item.ExperimentAssignment.UserId &&
                item.ServedAtUtc >= item.ExperimentAssignment.AssignedAtUtc &&
                experiment.StartedAtUtc != null && item.ServedAtUtc >= experiment.StartedAtUtc &&
                (experiment.ClosedAtUtc == null || item.ServedAtUtc <= experiment.ClosedAtUtc) &&
                item.TelemetrySource == RecommendationTelemetrySource.OperationalCustomer)
            .Select(item => new ExposureRow(
                item.UserId,
                item.ExperimentAssignment!.Variant,
                item.ServedAtUtc,
                item.ClickedAtUtc,
                item.PurchasedOrderId,
                item.PurchasedAtUtc,
                item.PurchasedOrder == null ? null : item.PurchasedOrder.Origin,
                item.PurchasedOrder != null && item.PurchasedOrder.IsSeededForDemo))
            .ToListAsync(cancellationToken);

        // Hash the canonical inputs, not the report timestamp. Repeating an
        // analysis with unchanged source facts preserves this fingerprint.
        captureInputFingerprint?.Invoke(Sha256(JsonSerializer.Serialize(new
        {
            experiment.ConfigurationSha256,
            experiment.Status,
            experiment.StartedAtUtc,
            experiment.ClosedAtUtc,
            Assignments = assignments.OrderBy(item => item.UserId),
            Exposures = exposures.Select(item => JsonSerializer.Serialize(item, JsonOptions))
                .OrderBy(item => item, StringComparer.Ordinal)
        }, JsonOptions)));

        // Do not judge an exposure before its full attribution period has
        // passed. This applies identically to both arms and protects the
        // denominator from treating a fresh page view as a non-conversion.
        var matureExposures = exposures
            .Where(item => item.ServedAtUtc <= maturityBoundary)
            .ToArray();
        var control = ToArm(
            RecommendationExperimentVariant.Control,
            assignments,
            matureExposures,
            experiment.AttributionWindowDays);
        var treatment = ToArm(
            RecommendationExperimentVariant.Treatment,
            assignments,
            matureExposures,
            experiment.AttributionWindowDays);
        var observationDays = matureExposures.Length == 0
            ? 0
            : Math.Max(0, (int)Math.Floor((matureExposures.Max(item => item.ServedAtUtc) - matureExposures.Min(item => item.ServedAtUtc)).TotalDays));

        var unmet = BuildUnmetRequirements(
            experiment,
            now,
            control,
            treatment,
            observationDays);
        var causalEstimateAvailable = unmet.Count == 0;
        double? absoluteLift = causalEstimateAvailable
            ? treatment.PrimaryOutcomeRate!.Value - control.PrimaryOutcomeRate!.Value
            : null;
        double? relativeLift = causalEstimateAvailable && control.PrimaryOutcomeRate > 0d
            ? absoluteLift!.Value / control.PrimaryOutcomeRate.Value
            : null;
        (double Lower, double Upper)? interval = causalEstimateAvailable
            ? NewcombeWilsonDifferenceInterval(
                treatment.UsersWithAttributedCheckout,
                treatment.AssignedUsers,
                control.UsersWithAttributedCheckout,
                control.AssignedUsers)
            : null;

        return new RecommendationExperimentImpactResponse
        {
            ExperimentId = experiment.Id,
            ExperimentKey = experiment.ExperimentKey,
            Status = experiment.Status,
            GeneratedAtUtc = ToOffset(now),
            StartedAtUtc = ToOffset(experiment.StartedAtUtc),
            ClosedAtUtc = ToOffset(experiment.ClosedAtUtc),
            Protocol = experiment.Protocol,
            EvidenceTier = causalEstimateAvailable ? "CausalEstimate" : "Collecting",
            IsCausalEstimateAvailable = causalEstimateAvailable,
            PrimaryOutcomeDefinition =
                "Fraction of all assigned users with at least one server-attributed checkout for a clicked recommended product within the seven-day attribution window; assignments without an attributed checkout remain in the denominator.",
            ConfidenceIntervalMethod = RecommendationExperimentPolicy.ConfidenceIntervalMethod,
            AttributionWindowDays = experiment.AttributionWindowDays,
            MinimumServedUsersPerVariant = RecommendationExperimentPolicy.MinimumServedUsersPerVariant,
            MinimumExposuresPerVariant = RecommendationExperimentPolicy.MinimumExposuresPerVariant,
            MinimumObservationDays = RecommendationExperimentPolicy.MinimumObservationDays,
            Control = control,
            Treatment = treatment,
            AbsoluteLift = absoluteLift,
            RelativeLift = relativeLift,
            AbsoluteLiftConfidenceIntervalLower = interval?.Lower,
            AbsoluteLiftConfidenceIntervalUpper = interval?.Upper,
            UnmetRequirements = unmet,
            Limitations =
            [
                "Only production OperationalCustomer exposures served after explicit recommendation-analytics consent can enter this report. Historic and descriptive-only exposures have no experiment assignment and are excluded.",
                "The primary outcome is bounded client-assisted attribution, not all shop conversion: unrelated purchases and clients that do not preserve the exposure ID are not counted.",
                "A collecting report contains no causal estimate. Null lift values mean insufficient pre-registered evidence, not zero effect.",
                "The point estimate compares sticky user-level randomized arms. It does not prove long-term retention, satisfaction, or return-adjusted revenue; those require a separately pre-registered mature outcome.",
                "This v1 report uses an aggregate Newcombe/Wilson 95% interval and does not claim statistical significance or causal impact until every listed gate has passed."
            ]
        };
    }

    private static RecommendationExperimentArmResponse ToArm(
        RecommendationExperimentVariant variant,
        IReadOnlyCollection<AssignmentRow> assignments,
        IReadOnlyCollection<ExposureRow> matureExposures,
        int attributionWindowDays)
    {
        var armAssignments = assignments
            .Where(item => item.Variant == variant)
            .Select(item => item.UserId)
            .Distinct()
            .ToArray();
        var armExposures = matureExposures
            .Where(item => item.Variant == variant)
            .ToArray();
        var validClicked = armExposures
            .Where(item => RecommendationImpactPolicy.HasValidClickTiming(item.ServedAtUtc, item.ClickedAtUtc))
            .ToArray();
        var outcomeUsers = validClicked
            .Where(item => IsOperationalAttribution(item, attributionWindowDays))
            .Select(item => item.UserId)
            .Distinct()
            .Count();
        var servedUsers = armExposures
            .Select(item => item.UserId)
            .Distinct()
            .Count();

        return new RecommendationExperimentArmResponse
        {
            Variant = variant.ToString(),
            AssignedUsers = armAssignments.Length,
            MaturedServedUsers = servedUsers,
            MaturedExposures = armExposures.Length,
            ValidClickedExposures = validClicked.Length,
            UsersWithAttributedCheckout = outcomeUsers,
            PrimaryOutcomeRate = armAssignments.Length == 0 ? null : (double)outcomeUsers / armAssignments.Length
        };
    }

    private static bool IsOperationalAttribution(ExposureRow row, int attributionWindowDays)
    {
        if (row.PurchasedOrderId is null ||
            row.PurchasedOrderOrigin != OrderOrigin.CustomerCheckout ||
            row.PurchasedOrderIsSeededForDemo ||
            row.PurchasedAtUtc is null ||
            row.ClickedAtUtc is null)
        {
            return false;
        }

        return row.ClickedAtUtc.Value >= row.ServedAtUtc &&
               row.ClickedAtUtc.Value <= row.ServedAtUtc.AddDays(attributionWindowDays) &&
               row.PurchasedAtUtc.Value >= row.ClickedAtUtc.Value &&
               row.PurchasedAtUtc.Value <= row.ServedAtUtc.AddDays(attributionWindowDays);
    }

    private static List<RecommendationExperimentRequirementResponse> BuildUnmetRequirements(
        RecommendationExperiment experiment,
        DateTime now,
        RecommendationExperimentArmResponse control,
        RecommendationExperimentArmResponse treatment,
        int observationDays)
    {
        var unmet = new List<RecommendationExperimentRequirementResponse>();
        if (experiment.Status != RecommendationExperimentStatuses.Closed || experiment.ClosedAtUtc is null)
        {
            unmet.Add(Requirement(
                "experiment-closed",
                experiment.Status,
                "Closed",
                "Close serving before requesting a causal estimate so the experiment definition and exposure population are fixed."));
        }
        else if (experiment.ClosedAtUtc.Value > now.AddDays(-experiment.AttributionWindowDays))
        {
            unmet.Add(Requirement(
                "attribution-maturity",
                ToOffset(experiment.ClosedAtUtc.Value).ToString("O"),
                $"closed at least {experiment.AttributionWindowDays} day(s) ago",
                "Wait for the final served exposure's bounded checkout-attribution window to mature."));
        }

        AddArmRequirement(
            unmet,
            "matured-served-users",
            control,
            treatment,
            RecommendationExperimentPolicy.MinimumServedUsersPerVariant,
            arm => arm.MaturedServedUsers,
            "distinct served users");
        AddArmRequirement(
            unmet,
            "matured-exposures",
            control,
            treatment,
            RecommendationExperimentPolicy.MinimumExposuresPerVariant,
            arm => arm.MaturedExposures,
            "matured server-recorded exposures");
        if (observationDays < RecommendationExperimentPolicy.MinimumObservationDays)
        {
            unmet.Add(Requirement(
                "observation-days",
                observationDays.ToString(),
                $">= {RecommendationExperimentPolicy.MinimumObservationDays} days",
                "The mature exposure window needs calendar coverage beyond a small convenience sample."));
        }

        return unmet;
    }

    private static void AddArmRequirement(
        ICollection<RecommendationExperimentRequirementResponse> unmet,
        string name,
        RecommendationExperimentArmResponse control,
        RecommendationExperimentArmResponse treatment,
        int required,
        Func<RecommendationExperimentArmResponse, int> selector,
        string noun)
    {
        var controlValue = selector(control);
        var treatmentValue = selector(treatment);
        if (controlValue >= required && treatmentValue >= required)
            return;

        unmet.Add(Requirement(
            name,
            $"Control {controlValue}; Treatment {treatmentValue}",
            $">= {required} {noun} in each arm",
            "The fixed 50/50 allocation needs adequate mature evidence in both randomized arms."));
    }

    private static RecommendationExperimentRequirementResponse Requirement(
        string name,
        string observed,
        string required,
        string detail) => new()
        {
            Name = name,
            Observed = observed,
            Required = required,
            Detail = detail
        };

    private static (double Lower, double Upper) NewcombeWilsonDifferenceInterval(
        int treatmentEvents,
        int treatmentTotal,
        int controlEvents,
        int controlTotal)
    {
        var treatment = WilsonInterval(treatmentEvents, treatmentTotal);
        var control = WilsonInterval(controlEvents, controlTotal);
        var treatmentRate = (double)treatmentEvents / treatmentTotal;
        var controlRate = (double)controlEvents / controlTotal;
        var difference = treatmentRate - controlRate;
        // Newcombe's uncorrected score method combines the distances from
        // each estimate to its Wilson bound in quadrature.
        return (
            Math.Max(-1d, difference - Math.Sqrt(Math.Pow(treatmentRate - treatment.Lower, 2) + Math.Pow(control.Upper - controlRate, 2))),
            Math.Min(1d, difference + Math.Sqrt(Math.Pow(treatment.Upper - treatmentRate, 2) + Math.Pow(controlRate - control.Lower, 2))));
    }

    private static (double Lower, double Upper) WilsonInterval(int events, int total)
    {
        const double z = 1.959963984540054d;
        var proportion = (double)events / total;
        var zSquared = z * z;
        var denominator = 1d + zSquared / total;
        var center = (proportion + zSquared / (2d * total)) / denominator;
        var adjustment = z * Math.Sqrt((proportion * (1d - proportion) + zSquared / (4d * total)) / total) / denominator;
        return (Math.Max(0d, center - adjustment), Math.Min(1d, center + adjustment));
    }

    private static RecommendationExperimentAssignmentContext ToServingContext(
        RecommendationExperimentAssignment assignment,
        RecommendationExperiment experiment) => assignment.Variant == RecommendationExperimentVariant.Treatment
        ? new RecommendationExperimentAssignmentContext(
            assignment.Id,
            assignment.Variant,
            experiment.TreatmentAlgorithmVersion,
            experiment.TreatmentStrategy)
        : new RecommendationExperimentAssignmentContext(
            assignment.Id,
            assignment.Variant,
            experiment.ControlAlgorithmVersion,
            experiment.ControlStrategy);

    private static RecommendationAnalyticsConsentResponse ToConsentResponse(
        RecommendationAnalyticsConsent? consent) => new()
        {
            IsGranted = consent?.IsActive == true,
            GrantedAtUtc = ToOffset(consent?.GrantedAtUtc),
            RevokedAtUtc = ToOffset(consent?.RevokedAtUtc),
            PolicyVersion = consent?.PolicyVersion ?? RecommendationExperimentPolicy.ConsentPolicyVersion
        };

    private static RecommendationExperimentResponse ToExperimentResponse(
        RecommendationExperiment experiment) => new()
        {
            Id = experiment.Id,
            ExperimentKey = experiment.ExperimentKey,
            Status = experiment.Status,
            CreatedAtUtc = ToOffset(experiment.CreatedAtUtc),
            StartedAtUtc = ToOffset(experiment.StartedAtUtc),
            ClosedAtUtc = ToOffset(experiment.ClosedAtUtc),
            Protocol = experiment.Protocol,
            TreatmentAlgorithmVersion = experiment.TreatmentAlgorithmVersion,
            ControlAlgorithmVersion = experiment.ControlAlgorithmVersion,
            TreatmentStrategy = experiment.TreatmentStrategy,
            ControlStrategy = experiment.ControlStrategy,
            TreatmentAllocationPercent = experiment.TreatmentAllocationPercent,
            RecommendationLimit = experiment.RecommendationLimit,
            AttributionWindowDays = experiment.AttributionWindowDays,
            ReturnMaturityDays = experiment.ReturnMaturityDays,
            ConfigurationSha256 = experiment.ConfigurationSha256
        };

    private static RecommendationExperimentAnalysisRunResponse ToAnalysisRunResponse(
        RecommendationExperimentAnalysisRun run,
        RecommendationExperimentImpactResponse report) => new()
        {
            RunId = run.RunId,
            ExperimentId = run.ExperimentId,
            ExecutedAtUtc = ToOffset(run.ExecutedAtUtc),
            EvidenceTier = run.EvidenceTier,
            Protocol = run.Protocol,
            ConfigurationSha256 = run.ConfigurationSha256,
            InputFingerprintSha256 = run.InputFingerprintSha256,
            Report = report
        };

    private static DateTimeOffset ToOffset(DateTime value) =>
        new(value.Kind == DateTimeKind.Utc ? value : DateTime.SpecifyKind(value, DateTimeKind.Utc));

    private static DateTimeOffset? ToOffset(DateTime? value) => value is null ? null : ToOffset(value.Value);

    private static string Sha256(string value) => Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();

    private sealed record AssignmentRow(int UserId, RecommendationExperimentVariant Variant);

    private sealed record ExposureRow(
        int UserId,
        RecommendationExperimentVariant Variant,
        DateTime ServedAtUtc,
        DateTime? ClickedAtUtc,
        int? PurchasedOrderId,
        DateTime? PurchasedAtUtc,
        OrderOrigin? PurchasedOrderOrigin,
        bool PurchasedOrderIsSeededForDemo);
}

public static class RecommendationExperimentStatuses
{
    public const string Draft = "Draft";
    public const string Running = "Running";
    public const string Closed = "Closed";
}

/// <summary>
/// Abstracts assignment randomness so tests can prove both arms without a
/// flaky retry loop. The production implementation uses a cryptographic RNG.
/// </summary>
public interface IRecommendationExperimentRandomizer
{
    bool NextTreatmentPercent(int treatmentPercent);
}

public sealed class CryptographicRecommendationExperimentRandomizer : IRecommendationExperimentRandomizer
{
    public bool NextTreatmentPercent(int treatmentPercent) =>
        RandomNumberGenerator.GetInt32(100) < treatmentPercent;
}
