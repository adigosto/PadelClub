namespace PadelClub.Services.Database;

/// <summary>
/// Server-stamped origin of a recommendation interaction. Only production,
/// verified player sessions may enter the operational online-impact cohort.
/// All other values remain observable as excluded aggregate diagnostics, but
/// can never satisfy a maturity gate.
/// </summary>
public enum RecommendationTelemetrySource
{
    /// <summary>
    /// Pre-provenance rows and any session whose operational status cannot be
    /// established. This conservative default prevents historical rows from
    /// becoming evidence merely because the schema was upgraded.
    /// </summary>
    Unverified = 0,

    /// <summary>Development-only application or seeded-demo session.</summary>
    DevelopmentDemo = 1,

    /// <summary>Automated integration-test session.</summary>
    IntegrationTest = 2,

    /// <summary>Authenticated administrator session.</summary>
    Administrator = 3,

    /// <summary>
    /// Active account without the verified Player identity and prior
    /// server-recorded operational-commerce evidence needed for operational
    /// telemetry.
    /// </summary>
    UnverifiedAccount = 4,

    /// <summary>Any non-production deployment other than the explicit test/demo classifications.</summary>
    NonProduction = 5,

    /// <summary>Production, active, email-verified Player session without an administrator role.</summary>
    OperationalCustomer = 6
}
