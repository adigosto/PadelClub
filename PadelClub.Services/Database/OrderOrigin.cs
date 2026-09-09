namespace PadelClub.Services.Database;

/// <summary>
/// Captures how an order entered PadelClub. The values deliberately separate
/// development/test/admin records from customer-originated commerce so that a
/// historical recommendation evaluation cannot silently treat them as an
/// operational cohort.
/// </summary>
public enum OrderOrigin
{
    /// <summary>
    /// Existing data for which the application cannot establish a trustworthy
    /// origin. It is retained for operational history, but excluded from
    /// qualified recommendation evidence.
    /// </summary>
    UnverifiedLegacy = 0,

    /// <summary>Development data inserted by the deterministic local seed.</summary>
    SeedDemo = 1,

    /// <summary>Records inserted by automated integration-test fixtures.</summary>
    IntegrationTest = 2,

    /// <summary>Records manually entered through the administrator CRUD API.</summary>
    AdminCreated = 3,

    /// <summary>Records created by the authenticated customer checkout flow.</summary>
    CustomerCheckout = 4,

    /// <summary>
    /// Records brought in through a separately verified import process. No
    /// importer currently writes this value; it is reserved for that audited
    /// workflow rather than a claim about legacy rows.
    /// </summary>
    VerifiedImport = 5
}
