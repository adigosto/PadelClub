using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using ExcelDataReader;
using PadelClub.Services.Recommendations;

return await RecommendationBenchmarkProgram.RunAsync(args);

internal static class RecommendationBenchmarkProgram
{
    private const int TopK = 6;
    private const int FoldCount = 3;
    private const int HoldoutDays = 28;
    private const string BenchmarkProtocol = "rolling-temporal-matured-real-retail-v1";
    private const string DatasetUrl = "https://archive.ics.uci.edu/dataset/352/online+retail";
    private const string DatasetDownloadUrl =
        "https://archive.ics.uci.edu/static/public/352/online%2Bretail.zip";
    private const string CanonicalUciOnlineRetailWorkbookSha256 =
        "43465a06f2ccf7c8b5bd2892bc7defb52f97487934fe93b16ae4c3936424676d";
    private const int ReturnMaturityDays = 30;
    private const int MaximumUnmatchedCancellationBasisPoints = 1_000;
    private static readonly Regex MerchandiseStockCode = new(
        @"^\d{5}[A-Z]?$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    public static Task<int> RunAsync(string[] args)
    {
        try
        {
            var options = BenchmarkOptions.Parse(args);
            var source = LoadSource(options.InputPath);
            var result = Evaluate(source);

            var outputDirectory = Path.GetDirectoryName(options.OutputPath);
            if (!string.IsNullOrWhiteSpace(outputDirectory))
                Directory.CreateDirectory(outputDirectory);

            File.WriteAllText(
                options.OutputPath,
                JsonSerializer.Serialize(result, JsonOptions),
                new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));

            Console.WriteLine($"Wrote benchmark evidence: {options.OutputPath}");
            Console.WriteLine(
                result.IsMeaningful
                    ? "External real-transaction benchmark quality gates passed."
                    : "External benchmark completed, but one or more quality gates failed; inspect the JSON report.");
            Console.WriteLine(
                "Boundary: this is an external UCI Online Retail benchmark, not PadelClub customer performance.");
            return Task.FromResult(result.IsMeaningful ? 0 : 2);
        }
        catch (BenchmarkArgumentException exception)
        {
            Console.Error.WriteLine(exception.Message);
            Console.Error.WriteLine(BenchmarkOptions.Usage);
            return Task.FromResult(64);
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine($"Benchmark failed: {exception.Message}");
            return Task.FromResult(1);
        }
    }

    private static ExternalBenchmarkReport Evaluate(LoadedRetailSource source)
    {
        var latestObservedExclusive = source.LatestObservedUtc.Date.AddDays(1);
        var latestMaturedEnd = latestObservedExclusive.AddDays(-ReturnMaturityDays);
        var firstCutoff = latestMaturedEnd.AddDays(-FoldCount * HoldoutDays);
        var foldReports = new List<ExternalBenchmarkFold>(FoldCount);

        for (var foldIndex = 0; foldIndex < FoldCount; foldIndex++)
        {
            var cutoff = firstCutoff.AddDays(foldIndex * HoldoutDays);
            var end = cutoff.AddDays(HoldoutDays);
            var labelMaturityEnd = end.AddDays(ReturnMaturityDays);
            var training = BuildNetPurchaseSnapshot(source, cutoff).Signals;
            var holdout = BuildNetPurchaseSnapshot(source, labelMaturityEnd).Signals
                .Where(x => x.PurchasedAt >= cutoff && x.PurchasedAt < end)
                .ToArray();
            var candidates = training
                .Select(x => x.ProductId)
                .Distinct()
                .OrderBy(x => x)
                .ToArray();
            var evaluation = TemporalRecommendationEvaluator.Evaluate(
                training,
                holdout,
                candidates,
                cutoff,
                TopK);

            foldReports.Add(new ExternalBenchmarkFold(
                Fold: foldIndex + 1,
                CutoffUtc: new DateTimeOffset(cutoff),
                EndUtc: new DateTimeOffset(end),
                LabelMaturityEndUtc: new DateTimeOffset(labelMaturityEnd),
                TrainingSignals: training.Count,
                HoldoutSignals: holdout.Length,
                TrainingOrders: training.Select(x => x.OrderId).Distinct().Count(),
                HoldoutOrders: holdout.Select(x => x.OrderId).Distinct().Count(),
                CandidateProducts: candidates.Length,
                EvaluatedUsers: evaluation.EvaluatedUsers,
                ColdStartUsers: evaluation.ColdStartUsers,
                UsersWithoutNovelHoldout: evaluation.UsersWithoutNovelHoldout,
                IsAvailable: evaluation.IsAvailable,
                UnavailableReason: evaluation.UnavailableReason,
                CollaborativeFiltering: BenchmarkMethodMetrics.From(evaluation.CollaborativeFiltering),
                PopularityBaseline: BenchmarkMethodMetrics.From(evaluation.PopularityBaseline)));
        }

        var gates = BuildQualityGates(source, firstCutoff, foldReports);
        var isMeaningful = gates.All(x => x.Passed);
        var aggregate = BenchmarkAggregate.From(foldReports);

        return new ExternalBenchmarkReport(
            EvidenceKind: "external-real-transaction-benchmark",
            ClaimBoundary:
                "This evaluates the PadelClub ranking algorithm on an external public retail dataset. It must not be described as PadelClub operational performance, customer conversion, or customer satisfaction.",
            Dataset: new ExternalDatasetMetadata(
                Name: "UCI Online Retail",
                DatasetUrl: DatasetUrl,
                DownloadUrl: DatasetDownloadUrl,
                Doi: "10.24432/C5BW33",
                License: "CC BY 4.0",
                CanonicalWorkbookSha256: CanonicalUciOnlineRetailWorkbookSha256,
                Description:
                    "A public, de-identified transaction dataset for a UK non-store retailer. The input must match the official workbook SHA-256. Raw rows remain outside PadelClub; this report stores aggregate counts and a source-file SHA-256 only."),
            GeneratedAtUtc: DateTimeOffset.UtcNow,
            SourceSha256: source.SourceSha256,
            AlgorithmVersion: ItemBasedCollaborativeRanker.Version,
            CoreEvaluatorProtocol: TemporalRecommendationEvaluator.Protocol,
            BenchmarkProtocol: BenchmarkProtocol,
            TopK: TopK,
            FoldCount: FoldCount,
            HoldoutDays: HoldoutDays,
            ReturnMaturityDays: ReturnMaturityDays,
            Cleaning: source.Cleaning,
            Folds: foldReports,
            Aggregate: aggregate,
            QualityGates: gates,
            IsMeaningful: isMeaningful,
            Conclusion: isMeaningful
                ? "The archived external dataset meets this benchmark's transparent volume, history, and rolling-fold gates. Report the metrics as external algorithm evidence only."
                : "The benchmark ran, but does not meet every documented quality gate; report it as diagnostic evidence only.");
    }

    private static IReadOnlyList<ExternalBenchmarkQualityGate> BuildQualityGates(
        LoadedRetailSource source,
        DateTime firstCutoff,
        IReadOnlyList<ExternalBenchmarkFold> folds)
    {
        var requiredHistoryEnd = source.EarliestNetRetainedPurchaseUtc.AddDays(90);
        var totalCancellationQuantity = source.Cleaning.MatchedCancellationQuantity +
                                        source.Cleaning.UnmatchedCancellationQuantity;
        var unmatchedCancellationBasisPoints = totalCancellationQuantity == 0
            ? 0
            : (int)Math.Round(
                source.Cleaning.UnmatchedCancellationQuantity * 10_000d /
                totalCancellationQuantity,
                MidpointRounding.AwayFromZero);
        return
        [
            Gate(
                "retained-interactions",
                source.Cleaning.NetRetainedSignals,
                5_000,
                source.Cleaning.NetRetainedSignals >= 5_000,
                "At least 5,000 cleaned, cancellation-netted customer-product-invoice interactions are required."),
            Gate(
                "distinct-customers",
                source.Cleaning.DistinctCustomers,
                100,
                source.Cleaning.DistinctCustomers >= 100,
                "At least 100 de-identified customers are required."),
            Gate(
                "merchandise-products",
                source.Cleaning.DistinctProducts,
                50,
                source.Cleaning.DistinctProducts >= 50,
                "At least 50 retained merchandise products are required."),
            Gate(
                "pre-fold-history",
                (int)(firstCutoff - source.EarliestNetRetainedPurchaseUtc).TotalDays,
                90,
                requiredHistoryEnd <= firstCutoff,
                "At least 90 days of retained history must exist before the first holdout cutoff."),
            Gate(
                "three-rolling-folds",
                folds.Count,
                FoldCount,
                folds.Count == FoldCount,
                "The official protocol requires all three consecutive 28-day folds."),
            Gate(
                "available-each-fold",
                folds.Count(x => x.IsAvailable),
                FoldCount,
                folds.All(x => x.IsAvailable),
                "Each fold must contain warm users with a new retained holdout product."),
            Gate(
                "warm-users-each-fold",
                folds.Count == 0 ? 0 : folds.Min(x => x.EvaluatedUsers),
                50,
                folds.All(x => x.EvaluatedUsers >= 50),
                "Every fold must evaluate at least 50 warm users."),
            Gate(
                "holdout-signals-each-fold",
                folds.Count == 0 ? 0 : folds.Min(x => x.HoldoutSignals),
                100,
                folds.All(x => x.HoldoutSignals >= 100),
                "Every fold must contain at least 100 cleaned holdout interactions."),
            Gate(
                "candidate-products-each-fold",
                folds.Count == 0 ? 0 : folds.Min(x => x.CandidateProducts),
                20,
                folds.All(x => x.CandidateProducts >= 20),
                "Every fold must contain at least 20 historical candidate products."),
            Gate(
                "return-maturity",
                folds.Count == 0
                    ? 0
                    : (int)(source.LatestObservedUtc.Date.AddDays(1) - folds.Max(x => x.EndUtc.UtcDateTime)).TotalDays,
                ReturnMaturityDays,
                folds.Count == FoldCount &&
                (source.LatestObservedUtc.Date.AddDays(1) - folds.Max(x => x.EndUtc.UtcDateTime)).TotalDays >= ReturnMaturityDays,
                "Each holdout end must be at least 30 days before the archive's last observed day, allowing later cancellations to be reflected in the label snapshot."),
            Gate(
                "unmatched-cancellation-rate",
                unmatchedCancellationBasisPoints,
                MaximumUnmatchedCancellationBasisPoints,
                unmatchedCancellationBasisPoints <= MaximumUnmatchedCancellationBasisPoints,
                "Observed and required values are basis points. At most 10.00% of cancellation quantity may remain unmatched after the conservative same-customer/same-product/prior-time allocation; unmatched returns stay disclosed rather than being imputed.")
        ];
    }

    private static ExternalBenchmarkQualityGate Gate(
        string name,
        int observed,
        int required,
        bool passed,
        string detail) => new(name, observed, required, passed, detail);

    private static LoadedRetailSource LoadSource(string inputPath)
    {
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        var sourceSha256 = CalculateSha256(inputPath);
        if (!string.Equals(
                sourceSha256,
                CanonicalUciOnlineRetailWorkbookSha256,
                StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                "The input workbook does not match the canonical UCI Online Retail SHA-256. " +
                $"Expected {CanonicalUciOnlineRetailWorkbookSha256}, received {sourceSha256}.");
        }

        var purchaseRows = new List<ExternalRetailLine>();
        var cancellationRows = new List<ExternalRetailCancellation>();
        var cleaning = new MutableCleaningSummary();

        using var stream = File.Open(inputPath, FileMode.Open, FileAccess.Read, FileShare.Read);
        using var reader = ExcelReaderFactory.CreateReader(stream);
        if (!reader.Read())
            throw new InvalidOperationException("The workbook has no header row.");

        var columns = ReadColumns(reader);
        var invoiceColumn = RequiredColumn(columns, "InvoiceNo");
        var stockColumn = RequiredColumn(columns, "StockCode");
        var quantityColumn = RequiredColumn(columns, "Quantity");
        var invoiceDateColumn = RequiredColumn(columns, "InvoiceDate");
        var unitPriceColumn = RequiredColumn(columns, "UnitPrice");
        var customerColumn = RequiredColumn(columns, "CustomerID");

        while (reader.Read())
        {
            cleaning.SourceRows++;
            var invoice = ReadText(reader, invoiceColumn);
            var stockCode = ReadText(reader, stockColumn);
            var customerId = ReadText(reader, customerColumn);
            if (string.IsNullOrWhiteSpace(invoice) ||
                string.IsNullOrWhiteSpace(stockCode) ||
                string.IsNullOrWhiteSpace(customerId) ||
                !TryReadDateTime(reader.GetValue(invoiceDateColumn), out var purchasedAt))
            {
                cleaning.MissingRequiredFields++;
                continue;
            }

            if (!MerchandiseStockCode.IsMatch(stockCode))
            {
                cleaning.NonMerchandiseStockCode++;
                continue;
            }

            if (!TryReadNonZeroInteger(reader.GetValue(quantityColumn), out var quantity))
            {
                cleaning.ZeroOrInvalidQuantity++;
                continue;
            }

            if (invoice.StartsWith("C", StringComparison.OrdinalIgnoreCase))
            {
                if (quantity >= 0)
                {
                    cleaning.InvalidCancellationRows++;
                    continue;
                }

                cancellationRows.Add(new ExternalRetailCancellation(
                    CustomerId: customerId,
                    StockCode: stockCode,
                    Quantity: checked(-quantity),
                    CancelledAt: NormalizeUtc(purchasedAt),
                    Sequence: cleaning.SourceRows));
                cleaning.CancellationRows++;
                continue;
            }

            if (quantity < 0)
            {
                cleaning.NegativePurchaseRows++;
                continue;
            }

            if (!TryReadPositiveDecimal(reader.GetValue(unitPriceColumn), out _))
            {
                cleaning.NonPositiveOrInvalidUnitPrice++;
                continue;
            }

            purchaseRows.Add(new ExternalRetailLine(
                CustomerId: customerId,
                InvoiceNo: invoice,
                StockCode: stockCode,
                Quantity: quantity,
                PurchasedAt: NormalizeUtc(purchasedAt),
                Sequence: cleaning.SourceRows));
            cleaning.EligiblePurchaseRows++;
        }

        if (purchaseRows.Count == 0)
            throw new InvalidOperationException("No eligible retail purchase rows were found after cleaning.");

        var userIds = AssignIds(purchaseRows.Select(x => x.CustomerId));
        var productIds = AssignIds(purchaseRows.Select(x => x.StockCode));
        var orderIds = AssignIds(purchaseRows.Select(x => x.InvoiceNo));
        var latestObservedUtc = purchaseRows
            .Select(x => x.PurchasedAt)
            .Concat(cancellationRows.Select(x => x.CancelledAt))
            .Max();
        var fullSourceSnapshot = BuildNetPurchaseSnapshot(
            purchaseRows,
            cancellationRows,
            latestObservedUtc.Date.AddDays(1),
            userIds,
            productIds,
            orderIds);

        cleaning.NetRetainedSignals = fullSourceSnapshot.Signals.Count;
        cleaning.DistinctCustomers = fullSourceSnapshot.Signals.Select(x => x.UserId).Distinct().Count();
        cleaning.DistinctProducts = fullSourceSnapshot.Signals.Select(x => x.ProductId).Distinct().Count();
        cleaning.DistinctInvoices = fullSourceSnapshot.Signals.Select(x => x.OrderId).Distinct().Count();
        cleaning.MatchedCancellationQuantity = fullSourceSnapshot.Netting.MatchedCancellationQuantity;
        cleaning.UnmatchedCancellationQuantity = fullSourceSnapshot.Netting.UnmatchedCancellationQuantity;
        cleaning.SignalsRemovedByCancellationNetting = fullSourceSnapshot.Netting.SignalsRemovedByCancellationNetting;

        if (fullSourceSnapshot.Signals.Count == 0)
            throw new InvalidOperationException("No retail interactions remained after cancellation netting.");

        return new LoadedRetailSource(
            SourceSha256: sourceSha256,
            Cleaning: cleaning.ToImmutable(),
            PurchaseRows: purchaseRows,
            CancellationRows: cancellationRows,
            UserIds: userIds,
            ProductIds: productIds,
            OrderIds: orderIds,
            EarliestNetRetainedPurchaseUtc: fullSourceSnapshot.Signals.Min(x => x.PurchasedAt),
            LatestObservedUtc: latestObservedUtc);
    }

    private static NetPurchaseSnapshot BuildNetPurchaseSnapshot(
        LoadedRetailSource source,
        DateTime asOfExclusive) => BuildNetPurchaseSnapshot(
        source.PurchaseRows,
        source.CancellationRows,
        asOfExclusive,
        source.UserIds,
        source.ProductIds,
        source.OrderIds);

    private static NetPurchaseSnapshot BuildNetPurchaseSnapshot(
        IReadOnlyList<ExternalRetailLine> purchaseRows,
        IReadOnlyList<ExternalRetailCancellation> cancellationRows,
        DateTime asOfExclusive,
        IReadOnlyDictionary<string, int> userIds,
        IReadOnlyDictionary<string, int> productIds,
        IReadOnlyDictionary<string, int> orderIds)
    {
        var purchasesByCustomerProduct = purchaseRows
            .Where(x => x.PurchasedAt < asOfExclusive)
            .GroupBy(x => new CustomerProductKey(x.CustomerId, x.StockCode))
            .ToDictionary(
                group => group.Key,
                group => group
                    .OrderBy(x => x.PurchasedAt)
                    .ThenBy(x => x.Sequence)
                    .Select(x => new MutableExternalRetailPurchase(x))
                    .ToList());
        var matchedCancellationQuantity = 0;
        var unmatchedCancellationQuantity = 0;

        foreach (var cancellation in cancellationRows
                     .Where(x => x.CancelledAt < asOfExclusive)
                     .OrderBy(x => x.CancelledAt)
                     .ThenBy(x => x.Sequence))
        {
            var remainingCancellationQuantity = cancellation.Quantity;
            if (purchasesByCustomerProduct.TryGetValue(
                    new CustomerProductKey(cancellation.CustomerId, cancellation.StockCode),
                    out var purchases))
            {
                for (var index = purchases.Count - 1;
                     index >= 0 && remainingCancellationQuantity > 0;
                     index--)
                {
                    var purchase = purchases[index];
                    if (purchase.PurchasedAt > cancellation.CancelledAt ||
                        (purchase.PurchasedAt == cancellation.CancelledAt &&
                         purchase.Sequence >= cancellation.Sequence))
                    {
                        continue;
                    }

                    var matchedQuantity = Math.Min(
                        purchase.RemainingQuantity,
                        remainingCancellationQuantity);
                    purchase.RemainingQuantity -= matchedQuantity;
                    remainingCancellationQuantity -= matchedQuantity;
                    matchedCancellationQuantity += matchedQuantity;
                }
            }

            unmatchedCancellationQuantity += remainingCancellationQuantity;
        }

        var mutablePurchases = purchasesByCustomerProduct.Values.SelectMany(x => x).ToArray();
        var signalsRemovedByCancellationNetting = mutablePurchases.Count(
            x => x.OriginalQuantity > 0 && x.RemainingQuantity == 0);
        var signals = mutablePurchases
            .Where(x => x.RemainingQuantity > 0)
            .GroupBy(x => new InvoiceProductKey(x.CustomerId, x.InvoiceNo, x.StockCode))
            .Select(group => new TemporalPurchaseSignal(
                UserId: userIds[group.Key.CustomerId],
                ProductId: productIds[group.Key.StockCode],
                OrderId: orderIds[group.Key.InvoiceNo],
                Quantity: checked(group.Sum(x => x.RemainingQuantity)),
                PurchasedAt: group.Min(x => x.PurchasedAt)))
            .OrderBy(x => x.PurchasedAt)
            .ThenBy(x => x.UserId)
            .ThenBy(x => x.OrderId)
            .ThenBy(x => x.ProductId)
            .ToArray();

        return new NetPurchaseSnapshot(
            signals,
            new CancellationNettingSummary(
                matchedCancellationQuantity,
                unmatchedCancellationQuantity,
                signalsRemovedByCancellationNetting));
    }

    private static Dictionary<string, int> AssignIds(IEnumerable<string> sourceValues) =>
        sourceValues
            .Distinct(StringComparer.Ordinal)
            .OrderBy(x => x, StringComparer.Ordinal)
            .Select((value, index) => new { value, id = index + 1 })
            .ToDictionary(x => x.value, x => x.id, StringComparer.Ordinal);

    private static Dictionary<string, int> ReadColumns(IExcelDataReader reader)
    {
        var columns = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        for (var index = 0; index < reader.FieldCount; index++)
        {
            var header = ReadText(reader, index);
            if (!string.IsNullOrWhiteSpace(header))
                columns[header] = index;
        }

        return columns;
    }

    private static int RequiredColumn(IReadOnlyDictionary<string, int> columns, string name) =>
        columns.TryGetValue(name, out var index)
            ? index
            : throw new InvalidOperationException($"Workbook is missing required '{name}' column.");

    private static string? ReadText(IExcelDataReader reader, int index)
    {
        if (index >= reader.FieldCount || reader.IsDBNull(index))
            return null;

        return Convert.ToString(reader.GetValue(index), CultureInfo.InvariantCulture)?.Trim();
    }

    private static bool TryReadNonZeroInteger(object? value, out int parsed)
    {
        parsed = 0;
        if (value is null || value is DBNull)
            return false;

        switch (value)
        {
            case int integer when integer != 0:
                parsed = integer;
                return true;
            case long integer when integer is >= int.MinValue and <= int.MaxValue && integer != 0:
                parsed = (int)integer;
                return true;
            case double number when number is >= int.MinValue and <= int.MaxValue &&
                                    Math.Abs(number) > 0d &&
                                    Math.Abs(number % 1d) < 0.000001d:
                parsed = (int)number;
                return true;
            default:
                return int.TryParse(
                    Convert.ToString(value, CultureInfo.InvariantCulture),
                    NumberStyles.Integer,
                    CultureInfo.InvariantCulture,
                    out parsed) && parsed != 0;
        }
    }

    private static bool TryReadPositiveDecimal(object? value, out decimal parsed)
    {
        parsed = 0m;
        if (value is null || value is DBNull)
            return false;

        return decimal.TryParse(
                   Convert.ToString(value, CultureInfo.InvariantCulture),
                   NumberStyles.Number,
                   CultureInfo.InvariantCulture,
                   out parsed) &&
               parsed > 0m;
    }

    private static bool TryReadDateTime(object? value, out DateTime parsed)
    {
        parsed = default;
        switch (value)
        {
            case DateTime dateTime:
                parsed = dateTime;
                return true;
            case double excelSerial when excelSerial > 0:
                parsed = DateTime.FromOADate(excelSerial);
                return true;
            case not null:
                return DateTime.TryParse(
                           Convert.ToString(value, CultureInfo.InvariantCulture),
                           CultureInfo.InvariantCulture,
                           DateTimeStyles.AllowWhiteSpaces,
                           out parsed) ||
                       DateTime.TryParse(
                           Convert.ToString(value, CultureInfo.GetCultureInfo("en-GB")),
                           CultureInfo.GetCultureInfo("en-GB"),
                           DateTimeStyles.AllowWhiteSpaces,
                           out parsed);
            default:
                return false;
        }
    }

    private static DateTime NormalizeUtc(DateTime value) =>
        value.Kind == DateTimeKind.Utc
            ? value
            : DateTime.SpecifyKind(value, DateTimeKind.Utc);

    private static string CalculateSha256(string path)
    {
        using var stream = File.OpenRead(path);
        return Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant();
    }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private sealed class MutableCleaningSummary
    {
        public int SourceRows { get; set; }

        public int EligiblePurchaseRows { get; set; }

        public int NetRetainedSignals { get; set; }

        public int DistinctCustomers { get; set; }

        public int DistinctProducts { get; set; }

        public int DistinctInvoices { get; set; }

        public int MissingRequiredFields { get; set; }

        public int CancellationRows { get; set; }

        public int InvalidCancellationRows { get; set; }

        public int NegativePurchaseRows { get; set; }

        public int ZeroOrInvalidQuantity { get; set; }

        public int NonPositiveOrInvalidUnitPrice { get; set; }

        public int NonMerchandiseStockCode { get; set; }

        public int MatchedCancellationQuantity { get; set; }

        public int UnmatchedCancellationQuantity { get; set; }

        public int SignalsRemovedByCancellationNetting { get; set; }

        public ExternalCleaningSummary ToImmutable() => new(
            SourceRows,
            EligiblePurchaseRows,
            NetRetainedSignals,
            DistinctCustomers,
            DistinctProducts,
            DistinctInvoices,
            MissingRequiredFields,
            CancellationRows,
            InvalidCancellationRows,
            NegativePurchaseRows,
            ZeroOrInvalidQuantity,
            NonPositiveOrInvalidUnitPrice,
            NonMerchandiseStockCode,
            MatchedCancellationQuantity,
            UnmatchedCancellationQuantity,
            SignalsRemovedByCancellationNetting,
            "Rows missing InvoiceNo, StockCode, CustomerID, or InvoiceDate are removed first. Merchandise cancellation rows (InvoiceNo starts with C) are matched only to a prior retained purchase for the same customer and stock code; their absolute quantity is allocated newest-first, and unmatched quantity is disclosed rather than heuristically assigned across customers or products. Non-cancellation rows with non-positive/invalid quantity or UnitPrice, and non-merchandise StockCode values, are excluded. Remaining rows are aggregated by customer, invoice, and stock code.");
    }
}

internal sealed record BenchmarkOptions(string InputPath, string OutputPath)
{
    public const string Usage =
        "Usage: dotnet run --project tools/PadelClub.RecommendationBenchmark -- --input <Online Retail.xlsx> --output <evidence.json>";

    public static BenchmarkOptions Parse(string[] args)
    {
        if (args.Length != 4)
            throw new BenchmarkArgumentException("Both --input and --output are required.");

        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (var index = 0; index < args.Length; index += 2)
        {
            if (!args[index].StartsWith("--", StringComparison.Ordinal) ||
                string.IsNullOrWhiteSpace(args[index + 1]) ||
                !values.TryAdd(args[index], args[index + 1]))
            {
                throw new BenchmarkArgumentException("Arguments must contain each named option exactly once.");
            }
        }

        if (!values.TryGetValue("--input", out var input) ||
            !values.TryGetValue("--output", out var output) ||
            values.Count != 2)
        {
            throw new BenchmarkArgumentException("Only --input and --output are supported by the locked benchmark protocol.");
        }

        var inputPath = Path.GetFullPath(input);
        if (!File.Exists(inputPath))
            throw new BenchmarkArgumentException($"Input workbook was not found: {inputPath}");

        return new BenchmarkOptions(inputPath, Path.GetFullPath(output));
    }
}

internal sealed class BenchmarkArgumentException(string message) : Exception(message);

internal sealed record ExternalRetailLine(
    string CustomerId,
    string InvoiceNo,
    string StockCode,
    int Quantity,
    DateTime PurchasedAt,
    int Sequence);

internal sealed record ExternalRetailCancellation(
    string CustomerId,
    string StockCode,
    int Quantity,
    DateTime CancelledAt,
    int Sequence);

internal sealed class MutableExternalRetailPurchase
{
    public MutableExternalRetailPurchase(ExternalRetailLine purchase)
    {
        CustomerId = purchase.CustomerId;
        InvoiceNo = purchase.InvoiceNo;
        StockCode = purchase.StockCode;
        OriginalQuantity = purchase.Quantity;
        RemainingQuantity = purchase.Quantity;
        PurchasedAt = purchase.PurchasedAt;
        Sequence = purchase.Sequence;
    }

    public string CustomerId { get; }

    public string InvoiceNo { get; }

    public string StockCode { get; }

    public int OriginalQuantity { get; }

    public int RemainingQuantity { get; set; }

    public DateTime PurchasedAt { get; }

    public int Sequence { get; }
}

internal readonly record struct CustomerProductKey(string CustomerId, string StockCode);

internal readonly record struct InvoiceProductKey(
    string CustomerId,
    string InvoiceNo,
    string StockCode);

internal sealed record CancellationNettingSummary(
    int MatchedCancellationQuantity,
    int UnmatchedCancellationQuantity,
    int SignalsRemovedByCancellationNetting);

internal sealed record NetPurchaseSnapshot(
    IReadOnlyList<TemporalPurchaseSignal> Signals,
    CancellationNettingSummary Netting);

internal sealed record LoadedRetailSource(
    string SourceSha256,
    ExternalCleaningSummary Cleaning,
    IReadOnlyList<ExternalRetailLine> PurchaseRows,
    IReadOnlyList<ExternalRetailCancellation> CancellationRows,
    IReadOnlyDictionary<string, int> UserIds,
    IReadOnlyDictionary<string, int> ProductIds,
    IReadOnlyDictionary<string, int> OrderIds,
    DateTime EarliestNetRetainedPurchaseUtc,
    DateTime LatestObservedUtc);

internal sealed record ExternalCleaningSummary(
    int SourceRows,
    int EligiblePurchaseRows,
    int NetRetainedSignals,
    int DistinctCustomers,
    int DistinctProducts,
    int DistinctInvoices,
    int MissingRequiredFields,
    int CancellationRows,
    int InvalidCancellationRows,
    int NegativePurchaseRows,
    int ZeroOrInvalidQuantity,
    int NonPositiveOrInvalidUnitPrice,
    int NonMerchandiseStockCode,
    int MatchedCancellationQuantity,
    int UnmatchedCancellationQuantity,
    int SignalsRemovedByCancellationNetting,
    string CleaningRule);

internal sealed record ExternalDatasetMetadata(
    string Name,
    string DatasetUrl,
    string DownloadUrl,
    string Doi,
    string License,
    string CanonicalWorkbookSha256,
    string Description);

internal sealed record ExternalBenchmarkQualityGate(
    string Name,
    int Observed,
    int Required,
    bool Passed,
    string Detail);

internal sealed record ExternalBenchmarkFold(
    int Fold,
    DateTimeOffset CutoffUtc,
    DateTimeOffset EndUtc,
    DateTimeOffset LabelMaturityEndUtc,
    int TrainingSignals,
    int HoldoutSignals,
    int TrainingOrders,
    int HoldoutOrders,
    int CandidateProducts,
    int EvaluatedUsers,
    int ColdStartUsers,
    int UsersWithoutNovelHoldout,
    bool IsAvailable,
    string? UnavailableReason,
    BenchmarkMethodMetrics CollaborativeFiltering,
    BenchmarkMethodMetrics PopularityBaseline);

internal sealed record BenchmarkMethodMetrics(
    double? PrecisionAtK,
    double? RecallAtK,
    double? HitRateAtK,
    double? MeanReciprocalRankAtK,
    double? NormalizedDiscountedCumulativeGainAtK,
    double? CatalogCoverageAtK,
    double? AverageRecommendationsReturned,
    int TotalHits,
    int UsersWithRecommendations)
{
    public static BenchmarkMethodMetrics From(RecommendationEvaluationMethodResult metrics) => new(
        metrics.PrecisionAtK,
        metrics.RecallAtK,
        metrics.HitRateAtK,
        metrics.MeanReciprocalRankAtK,
        metrics.NormalizedDiscountedCumulativeGainAtK,
        metrics.CatalogCoverageAtK,
        metrics.AverageRecommendationsReturned,
        metrics.TotalHits,
        metrics.UsersWithRecommendations);
}

internal sealed record BenchmarkAggregate(
    int EvaluatedUserFolds,
    int TotalHitsCollaborativeFiltering,
    int TotalHitsPopularityBaseline,
    string CatalogCoverageAggregation,
    BenchmarkMethodMetrics CollaborativeFiltering,
    BenchmarkMethodMetrics PopularityBaseline,
    BenchmarkMetricDelta CollaborativeFilteringMinusPopularity)
{
    public static BenchmarkAggregate From(IReadOnlyList<ExternalBenchmarkFold> folds)
    {
        var available = folds.Where(x => x.IsAvailable).ToArray();
        var evaluatedUserFolds = available.Sum(x => x.EvaluatedUsers);
        var collaborativeFiltering = AggregateMethod(
            available.Select(x => (x.CollaborativeFiltering, x.EvaluatedUsers)));
        var popularityBaseline = AggregateMethod(
            available.Select(x => (x.PopularityBaseline, x.EvaluatedUsers)));
        return new BenchmarkAggregate(
            EvaluatedUserFolds: evaluatedUserFolds,
            TotalHitsCollaborativeFiltering: available.Sum(x => x.CollaborativeFiltering.TotalHits),
            TotalHitsPopularityBaseline: available.Sum(x => x.PopularityBaseline.TotalHits),
            CatalogCoverageAggregation: "unweighted mean across available temporal folds",
            CollaborativeFiltering: collaborativeFiltering,
            PopularityBaseline: popularityBaseline,
            CollaborativeFilteringMinusPopularity: BenchmarkMetricDelta.From(
                collaborativeFiltering,
                popularityBaseline));
    }

    private static BenchmarkMethodMetrics AggregateMethod(
        IEnumerable<(BenchmarkMethodMetrics Metrics, int Weight)> values)
    {
        var rows = values.Where(x => x.Weight > 0).ToArray();
        var totalWeight = rows.Sum(x => x.Weight);
        if (totalWeight == 0)
        {
            return new BenchmarkMethodMetrics(
                null, null, null, null, null, null, null, 0, 0);
        }

        double? UserFoldAverage(Func<BenchmarkMethodMetrics, double?> selector) => rows.Any(x => selector(x.Metrics) is null)
            ? null
            : rows.Sum(x => selector(x.Metrics)!.Value * x.Weight) / totalWeight;
        double? FoldAverage(Func<BenchmarkMethodMetrics, double?> selector) => rows.Any(x => selector(x.Metrics) is null)
            ? null
            : rows.Average(x => selector(x.Metrics)!.Value);

        return new BenchmarkMethodMetrics(
            UserFoldAverage(x => x.PrecisionAtK),
            UserFoldAverage(x => x.RecallAtK),
            UserFoldAverage(x => x.HitRateAtK),
            UserFoldAverage(x => x.MeanReciprocalRankAtK),
            UserFoldAverage(x => x.NormalizedDiscountedCumulativeGainAtK),
            FoldAverage(x => x.CatalogCoverageAtK),
            UserFoldAverage(x => x.AverageRecommendationsReturned),
            rows.Sum(x => x.Metrics.TotalHits),
            rows.Sum(x => x.Metrics.UsersWithRecommendations));
    }
}

internal sealed record BenchmarkMetricDelta(
    double? PrecisionAtK,
    double? RecallAtK,
    double? HitRateAtK,
    double? MeanReciprocalRankAtK,
    double? NormalizedDiscountedCumulativeGainAtK,
    double? CatalogCoverageAtK)
{
    public static BenchmarkMetricDelta From(
        BenchmarkMethodMetrics collaborativeFiltering,
        BenchmarkMethodMetrics popularityBaseline) => new(
        Difference(collaborativeFiltering.PrecisionAtK, popularityBaseline.PrecisionAtK),
        Difference(collaborativeFiltering.RecallAtK, popularityBaseline.RecallAtK),
        Difference(collaborativeFiltering.HitRateAtK, popularityBaseline.HitRateAtK),
        Difference(collaborativeFiltering.MeanReciprocalRankAtK, popularityBaseline.MeanReciprocalRankAtK),
        Difference(
            collaborativeFiltering.NormalizedDiscountedCumulativeGainAtK,
            popularityBaseline.NormalizedDiscountedCumulativeGainAtK),
        Difference(collaborativeFiltering.CatalogCoverageAtK, popularityBaseline.CatalogCoverageAtK));

    private static double? Difference(double? left, double? right) =>
        left is null || right is null ? null : left.Value - right.Value;
}

internal sealed record ExternalBenchmarkReport(
    string EvidenceKind,
    string ClaimBoundary,
    ExternalDatasetMetadata Dataset,
    DateTimeOffset GeneratedAtUtc,
    string SourceSha256,
    string AlgorithmVersion,
    string CoreEvaluatorProtocol,
    string BenchmarkProtocol,
    int TopK,
    int FoldCount,
    int HoldoutDays,
    int ReturnMaturityDays,
    ExternalCleaningSummary Cleaning,
    IReadOnlyList<ExternalBenchmarkFold> Folds,
    BenchmarkAggregate Aggregate,
    IReadOnlyList<ExternalBenchmarkQualityGate> QualityGates,
    bool IsMeaningful,
    string Conclusion);
