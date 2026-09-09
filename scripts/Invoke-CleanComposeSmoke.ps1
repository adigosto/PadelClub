<#
.SYNOPSIS
Runs an isolated, clean-volume Compose rehearsal for the exam demo.

.DESCRIPTION
Uses `docker-compose.clean.yml` and a project name beginning with
`padelclub-clean-`. Compose namespaces all named volumes and networks by that
project name, so the normal `padelclub` stack is never stopped, reused, or
deleted. The script verifies a fresh bootstrap, health, administrator/player
authentication, authorization and validation contracts, recommendation response
invariants, historical-evaluation behavior, and the RabbitMQ product-update
path.

Pass -Cleanup only after reviewing the project name. It removes solely this
script's isolated Compose project and its namespaced volumes.

Pass -EvidenceDirectory to save a machine-readable result and Compose
diagnostics before any requested cleanup. The directory must remain within the
repository workspace.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^padelclub-clean-[a-z0-9][a-z0-9_-]*$')]
    [string]$ProjectName = "padelclub-clean-smoke",
    [ValidateRange(1024, 65535)]
    [int]$ApiPort = 5100,
    [ValidateRange(60, 600)]
    [int]$TimeoutSeconds = 240,
    [string]$EvidenceDirectory,
    [switch]$Cleanup
)

$ErrorActionPreference = "Stop"
$workspace = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$baseUrl = "http://127.0.0.1:$ApiPort"
$baseCompose = Join-Path $workspace "docker-compose.yml"
$cleanCompose = Join-Path $workspace "docker-compose.clean.yml"
$environmentFile = Join-Path $workspace ".env.example"
$demoPassword = "Smoke-$([Guid]::NewGuid().ToString('N'))-A9!"
$env:MSSQL_SA_PASSWORD = "Smoke-Sql-$([Guid]::NewGuid().ToString('N'))-A9!"
$env:RABBITMQ_DEFAULT_USER = "smoke$(Get-Random -Minimum 1000 -Maximum 9999)"
$env:RABBITMQ_DEFAULT_PASS = "Smoke-Rabbit-$([Guid]::NewGuid().ToString('N'))-A9!"
$env:AUTH_SIGNING_KEY = "Smoke-Jwt-$([Guid]::NewGuid().ToString('N'))-A9!"
$env:SEED_DEMO_DATA = "true"
$env:DEMO_PASSWORD = $demoPassword

$evidenceRoot = $null
if (-not [string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
    $candidateEvidencePath = if ([System.IO.Path]::IsPathRooted($EvidenceDirectory)) {
        [System.IO.Path]::GetFullPath($EvidenceDirectory)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $workspace $EvidenceDirectory))
    }
    $workspaceRoot = [System.IO.Path]::GetFullPath($workspace).TrimEnd(
        [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar))
    $pathComparison = if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }
    $workspacePrefix = "$workspaceRoot$([System.IO.Path]::DirectorySeparatorChar)"
    if ($candidateEvidencePath -eq $workspaceRoot -or
        -not $candidateEvidencePath.StartsWith($workspacePrefix, $pathComparison)) {
        throw "EvidenceDirectory must resolve within the repository workspace: $EvidenceDirectory"
    }

    $evidenceRoot = $candidateEvidencePath
}

foreach ($requiredPath in @($baseCompose, $cleanCompose, $environmentFile)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required file was not found: $requiredPath"
    }
}

$composeBaseArguments = @(
    "compose",
    "--project-name", $ProjectName,
    "--env-file", $environmentFile,
    "-f", $baseCompose,
    "-f", $cleanCompose
)

function Invoke-CleanCompose {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    & docker @composeBaseArguments @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

function Test-HostTcpPortAvailable {
    param([Parameter(Mandatory = $true)][int]$Port)

    # This catches an existing normal stack or another process before Compose
    # attempts to publish the API port. The named mutex below closes the race
    # between concurrent invocations of this script in the same user session.
    $listeners = @(
        [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() |
            Where-Object { $_.Port -eq $Port }
    )

    if ($listeners.Count -gt 0) {
        $bindings = $listeners |
            ForEach-Object { $_.ToString() } |
            Sort-Object -Unique
        throw "API port $Port is already listening on the host ($($bindings -join ', ')). Stop that stack or choose a different -ApiPort."
    }
}

function Get-IsolatedDockerResources {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("container", "volume", "network")]
        [string]$ResourceType
    )

    $format = if ($ResourceType -eq "volume") { "{{.Name}}" } else { "{{.ID}}" }
    $arguments = @($ResourceType, "ls")
    if ($ResourceType -eq "container") {
        $arguments += "--all"
    }
    $arguments += @(
        "--filter", "label=com.docker.compose.project=$ProjectName",
        "--format", $format
    )

    $resources = @(& docker @arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not list Docker $ResourceType resources for isolated project $ProjectName."
    }

    return @($resources | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Write-CleanComposeEvidence {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Summary,
        [string[]]$ComposePs,
        [string[]]$ComposeLogs
    )

    if ($null -eq $evidenceRoot) {
        return
    }

    [System.IO.Directory]::CreateDirectory($evidenceRoot) | Out-Null
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    $summaryPath = Join-Path $evidenceRoot "clean-compose-smoke.json"
    $psPath = Join-Path $evidenceRoot "compose-ps.txt"
    $logsPath = Join-Path $evidenceRoot "compose.log"

    [System.IO.File]::WriteAllText(
        $summaryPath,
        ($Summary | ConvertTo-Json -Depth 5),
        $utf8WithoutBom)
    [System.IO.File]::WriteAllLines(
        $psPath,
        [string[]]@($ComposePs | ForEach-Object { $_.ToString() }),
        $utf8WithoutBom)
    [System.IO.File]::WriteAllLines(
        $logsPath,
        [string[]]@($ComposeLogs | ForEach-Object { $_.ToString() }),
        $utf8WithoutBom)
}

function Wait-ForReadyEndpoint {
    param([Parameter(Mandatory = $true)][string]$BaseUrl)

    $deadline = (Get-Date).ToUniversalTime().AddSeconds($TimeoutSeconds)
    do {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/health/ready" -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                return $response
            }
        }
        catch {
            # The API is expected to take time while SQL Server initializes and seeds.
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date).ToUniversalTime() -lt $deadline)

    throw "The isolated API did not return 200 from $BaseUrl/health/ready within $TimeoutSeconds seconds."
}

function Get-DemoSession {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Username
    )

    $body = @{ username = $Username; password = $demoPassword } | ConvertTo-Json -Compress
    $session = Invoke-RestMethod -Method Post -Uri "$BaseUrl/Users/login" -ContentType "application/json" -Body $body
    if ([string]::IsNullOrWhiteSpace($session.AccessToken)) {
        throw "Login for $Username returned no access token."
    }

    return $session
}

function Get-HttpStatusCode {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [ValidateSet("Get", "Post", "Put", "Delete", "Patch")]
        [string]$Method = "Get",
        [hashtable]$Headers = @{}
    )

    try {
        $requestArguments = @{
            Method = $Method
            Uri = $Uri
            TimeoutSec = 20
            UseBasicParsing = $true
        }
        if ($Headers.Count -gt 0) {
            $requestArguments.Headers = $Headers
        }

        return [int](Invoke-WebRequest @requestArguments).StatusCode
    }
    catch {
        if ($null -ne $_.Exception.Response) {
            return [int]$_.Exception.Response.StatusCode
        }

        throw
    }
}

function Get-SubscriberDelivery {
    param(
        [Parameter(Mandatory = $true)][int]$ProductId,
        [Parameter(Mandatory = $true)][string]$ProductName
    )

    $expected = "Received product update event <guid> for product $ProductId ($ProductName)."
    $pattern = "Received product update event (?<eventId>[0-9a-fA-F-]{36}) for product " +
        [regex]::Escape($ProductId.ToString()) + " " + [regex]::Escape("($ProductName).")
    $deadline = (Get-Date).ToUniversalTime().AddSeconds(30)
    do {
        $logs = @(& docker @composeBaseArguments logs --tail 100 padelclub-subscriber 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read the isolated subscriber log."
        }

        $match = [regex]::Match(($logs -join "`n"), $pattern)
        if ($match.Success) {
            return $match.Groups['eventId'].Value
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date).ToUniversalTime() -lt $deadline)

    throw "Subscriber did not log the expected product-update delivery: $expected"
}

function Wait-ForSubscriberSubscription {
    $expected = "Subscribed to product update events as padelclub.product-update-worker.v1."
    $deadline = (Get-Date).ToUniversalTime().AddSeconds(30)
    do {
        $logs = @(& docker @composeBaseArguments logs --tail 100 padelclub-subscriber 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read the isolated subscriber log."
        }

        if ($logs -match [regex]::Escape($expected)) {
            return $true
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date).ToUniversalTime() -lt $deadline)

    throw "Subscriber did not establish its product-update subscription within 30 seconds."
}

$composeMayExist = $false
$failure = $null
$failureStage = "preflight"
$composePs = @()
$composeLogs = @()
$apiPortMutexName = "PadelClub.CleanComposeSmoke.ApiPort.$ApiPort"
$apiPortMutex = $null
$apiPortMutexAcquired = $false
$summary = [ordered]@{
    schemaVersion = "1.5"
    status = "running"
    startedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    completedAtUtc = $null
    projectName = $ProjectName
    apiBaseUrl = $baseUrl
    readinessStatus = $null
    adminAuthentication = $false
    playerAuthentication = $false
    unauthenticatedRecommendationStatus = $null
    playerEvaluationStatus = $null
    adminEvaluationMissingBoundsStatus = $null
    adminEvaluationInvalidKStatus = $null
    playerProductUpdateStatus = $null
    recommendationCount = 0
    recommendationSchemaValid = $false
    recommendationIdsDistinct = $false
    ownedControlRacketExcluded = $false
    recommendationAlgorithmVersion = $null
    evaluationProtocol = $null
    evaluationAvailable = $null
    evaluationTrainingOrders = $null
    evaluationHoldoutOrders = $null
    evaluationExcludedSeededDemoOrders = $null
    evaluationEvidenceTier = $null
    evaluationExcludedUnverifiedLegacyOrders = $null
    evaluationExcludedNonOperationalOrders = $null
    evaluationWarmUsers = $null
    evaluationUnavailableReason = $null
    evaluationContractValid = $false
    productUpdateId = $null
    productUpdateFieldsUnchanged = $false
    subscriberSubscriptionObserved = $false
    subscriberDeliveryObserved = $false
    outboxEventId = $null
    composeDiagnosticsRequired = $null -ne $evidenceRoot
    composePsCaptured = $false
    composePsExitCode = $null
    composeLogsCaptured = $false
    composeLogsExitCode = $null
    composeDiagnosticsError = $null
    cleanupRequested = [bool]$Cleanup
    cleanupAttempted = $false
    cleanupCompleted = $false
    cleanupResourcesVerified = $false
    cleanupError = $null
    failureStage = $null
    failureMessage = $null
}

try {
    $failureStage = "api-port-lock"
    $apiPortMutex = [System.Threading.Mutex]::new($false, $apiPortMutexName)
    try {
        $apiPortMutexAcquired = $apiPortMutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        # The previous process terminated without releasing the mutex. Windows
        # grants ownership to this process, so it is safe to continue.
        $apiPortMutexAcquired = $true
        Write-Warning "Recovered abandoned clean-smoke API-port lock '$apiPortMutexName'."
    }

    if (-not $apiPortMutexAcquired) {
        throw "Another clean Compose smoke run is already using API port $ApiPort. Wait for it to finish or choose a different -ApiPort."
    }

    $failureStage = "api-port-preflight"
    Test-HostTcpPortAvailable -Port $ApiPort

    $existingVolumes = Get-IsolatedDockerResources -ResourceType "volume"
    $existingContainers = Get-IsolatedDockerResources -ResourceType "container"
    $existingNetworks = Get-IsolatedDockerResources -ResourceType "network"
    if ($existingVolumes.Count -gt 0 -or $existingContainers.Count -gt 0 -or $existingNetworks.Count -gt 0) {
        throw "The isolated project name '$ProjectName' already has Docker resources. Choose a new project name; this script will not reuse or remove them implicitly."
    }

    $failureStage = "compose-config"
    Invoke-CleanCompose -Arguments @("config", "--quiet")
    # Set this before `up` so a partially created failed stack is still removed.
    $composeMayExist = $true
    $failureStage = "compose-up"
    # `--wait` only observes Docker container state and has produced a false
    # failure while a just-restarted service was becoming available. Compose
    # still honors the SQL/RabbitMQ health dependencies here; the explicit HTTP
    # readiness and subscriber checks below are the authoritative smoke gates.
    Invoke-CleanCompose -Arguments @("up", "--build", "--detach")

    $failureStage = "readiness"
    $ready = Wait-ForReadyEndpoint -BaseUrl $baseUrl
    $failureStage = "administrator-login"
    $adminSession = Get-DemoSession -BaseUrl $baseUrl -Username "admin"
    $failureStage = "player-login"
    $playerSession = Get-DemoSession -BaseUrl $baseUrl -Username "player1"
    $adminHeaders = @{ Authorization = "Bearer $($adminSession.AccessToken)" }
    $playerHeaders = @{ Authorization = "Bearer $($playerSession.AccessToken)" }
    $summary.readinessStatus = $ready.StatusCode
    $summary.adminAuthentication = $true
    $summary.playerAuthentication = $true

    $failureStage = "subscriber-subscription"
    $summary.subscriberSubscriptionObserved = Wait-ForSubscriberSubscription

    $cutoffUtc = [DateTimeOffset]::new([DateTime]::UtcNow.Date.AddDays(-7), [TimeSpan]::Zero)
    $endUtc = [DateTimeOffset]::new([DateTime]::UtcNow.Date.AddDays(-1), [TimeSpan]::Zero)
    $cutoffQuery = [uri]::EscapeDataString($cutoffUtc.ToString("o"))
    $endQuery = [uri]::EscapeDataString($endUtc.ToString("o"))
    $evaluationUri = "$baseUrl/Operations/recommendations/evaluation?cutoffUtc=$cutoffQuery&endUtc=$endQuery&k=6"

    $failureStage = "authorization-and-validation-contracts"
    $unauthenticatedRecommendationStatus = Get-HttpStatusCode -Uri "$baseUrl/Recommendations/products?limit=6"
    $playerEvaluationStatus = Get-HttpStatusCode -Uri $evaluationUri -Headers $playerHeaders
    $adminEvaluationMissingBoundsStatus = Get-HttpStatusCode -Uri "$baseUrl/Operations/recommendations/evaluation" -Headers $adminHeaders
    $adminEvaluationInvalidKStatus = Get-HttpStatusCode -Uri "$baseUrl/Operations/recommendations/evaluation?cutoffUtc=$cutoffQuery&endUtc=$endQuery&k=13" -Headers $adminHeaders
    if ($unauthenticatedRecommendationStatus -ne 401 -or
        $playerEvaluationStatus -ne 403 -or
        $adminEvaluationMissingBoundsStatus -ne 400 -or
        $adminEvaluationInvalidKStatus -ne 400) {
        throw "Authorization or evaluator-validation contract returned unexpected status codes."
    }
    $summary.unauthenticatedRecommendationStatus = $unauthenticatedRecommendationStatus
    $summary.playerEvaluationStatus = $playerEvaluationStatus
    $summary.adminEvaluationMissingBoundsStatus = $adminEvaluationMissingBoundsStatus
    $summary.adminEvaluationInvalidKStatus = $adminEvaluationInvalidKStatus

    $failureStage = "recommendations"
    $recommendationPayload = Invoke-RestMethod -Method Get -Uri "$baseUrl/Recommendations/products?limit=6" -Headers $playerHeaders
    $recommendations = @()
    foreach ($recommendation in $recommendationPayload) {
        $recommendations += $recommendation
    }
    if ($recommendations.Count -eq 0) {
        throw "Fresh seed returned no product recommendations for player1."
    }
    if ($recommendations.Count -gt 6) {
        throw "Recommendation endpoint returned more results than the requested limit."
    }
    $recommendationIds = @($recommendations | ForEach-Object { $_.Product.Id })
    $recommendationNames = @($recommendations | ForEach-Object { $_.Product.Name })
    $distinctRecommendationIds = @($recommendationIds | Sort-Object -Unique)
    $recommendationIdsDistinct = $distinctRecommendationIds.Count -eq $recommendationIds.Count
    if (-not $recommendationIdsDistinct) {
        throw "Recommendation endpoint returned duplicate product IDs."
    }
    $invalidRecommendation = $recommendations | Where-Object {
        $null -eq $_.Product -or
        $_.Product.Id -le 0 -or
        [string]::IsNullOrWhiteSpace($_.Product.Name) -or
        [string]::IsNullOrWhiteSpace($_.Strategy) -or
        [string]::IsNullOrWhiteSpace($_.AlgorithmVersion)
    } | Select-Object -First 1
    if ($null -ne $invalidRecommendation) {
        throw "Recommendation endpoint returned an incomplete response item."
    }
    $ownedControlRacketExcluded = -not ($recommendationNames -contains "PadelClub Control Racket")
    if (-not $ownedControlRacketExcluded) {
        throw "A product retained by player1 was returned as a recommendation."
    }
    $summary.recommendationCount = $recommendations.Count
    $summary.recommendationAlgorithmVersion = $recommendations[0].AlgorithmVersion
    $summary.recommendationSchemaValid = $true
    $summary.recommendationIdsDistinct = $recommendationIdsDistinct
    $summary.ownedControlRacketExcluded = $ownedControlRacketExcluded

    $failureStage = "historical-evaluation"
    $evaluation = Invoke-RestMethod -Method Get -Uri $evaluationUri -Headers $adminHeaders
    if ($evaluation.Protocol -ne "global-temporal-future-basket-v1") {
        throw "Evaluation endpoint returned an unexpected protocol identifier."
    }
    if ($evaluation.IsAvailable -and
        ($null -eq $evaluation.CollaborativeFiltering.PrecisionAtK -or
        $null -eq $evaluation.PopularityBaseline.PrecisionAtK)) {
        throw "Available evaluation results must include both method metric sets."
    }
    if (-not $evaluation.IsAvailable -and
        ($null -ne $evaluation.CollaborativeFiltering.PrecisionAtK -or
        $null -ne $evaluation.PopularityBaseline.PrecisionAtK)) {
        throw "Unavailable evaluation results must not fabricate metric values."
    }
    if ($null -eq $evaluation.Cohort.ExcludedSeededDemoOrders -or
        $evaluation.Cohort.ExcludedSeededDemoOrders -lt 1) {
        throw "Fresh demo data must be reported as excluded from quality evaluation."
    }
    if ($evaluation.EvidenceSource -ne "Operational" -or
        $evaluation.EvidenceTier -ne "Unavailable" -or
        $evaluation.IsAvailable -or
        $evaluation.UnavailableReason -notmatch "No provenance-eligible delivered order cohort") {
        throw "Fresh demo data must not produce a recommendation-quality result."
    }
    $summary.evaluationProtocol = $evaluation.Protocol
    $summary.evaluationEvidenceTier = $evaluation.EvidenceTier
    $summary.evaluationAvailable = $evaluation.IsAvailable
    $summary.evaluationTrainingOrders = $evaluation.Cohort.TrainingOrders
    $summary.evaluationHoldoutOrders = $evaluation.Cohort.HoldoutOrders
    $summary.evaluationExcludedSeededDemoOrders = $evaluation.Cohort.ExcludedSeededDemoOrders
    $summary.evaluationExcludedUnverifiedLegacyOrders = $evaluation.Cohort.ExcludedUnverifiedLegacyOrders
    $summary.evaluationExcludedNonOperationalOrders = $evaluation.Cohort.ExcludedNonOperationalOrders
    $summary.evaluationWarmUsers = $evaluation.Cohort.EvaluatedUsers
    $summary.evaluationUnavailableReason = $evaluation.UnavailableReason
    $summary.evaluationContractValid = $true

    $failureStage = "product-update"
    $products = @((Invoke-RestMethod -Method Get -Uri "$baseUrl/Product?Page=1&PageSize=200" -Headers $adminHeaders).Items)
    $draft = $products |
        Where-Object { $_.ProductState -eq "DraftProductState" -and $_.Name -eq "Padel Racket (Starter)" } |
        Select-Object -First 1
    if ($null -eq $draft) {
        $draft = $products | Where-Object { $_.ProductState -eq "DraftProductState" } | Select-Object -First 1
    }
    if ($null -eq $draft) {
        throw "Fresh seed did not provide a DraftProductState product for the message smoke test."
    }

    $failureStage = "product-authorization-contract"
    $playerProductUpdateStatus = Get-HttpStatusCode -Method Put -Uri "$baseUrl/Product/$($draft.Id)" -Headers $playerHeaders
    if ($playerProductUpdateStatus -ne 403) {
        throw "A player could access the administrator-only product update route."
    }
    $summary.playerProductUpdateStatus = $playerProductUpdateStatus

    $failureStage = "product-update"
    $updateBody = @{
        name = $draft.Name
        description = $draft.Description
        price = $draft.Price
        stockQuantity = $draft.StockQuantity
        imageUrl = $draft.ImageUrl
    } | ConvertTo-Json -Compress
    $updated = Invoke-RestMethod -Method Put -Uri "$baseUrl/Product/$($draft.Id)" -Headers $adminHeaders -ContentType "application/json" -Body $updateBody
    $productFieldsUnchanged = $updated.Name -eq $draft.Name -and
        $updated.Description -eq $draft.Description -and
        $updated.Price -eq $draft.Price -and
        $updated.StockQuantity -eq $draft.StockQuantity
    if (-not $productFieldsUnchanged) {
        throw "The smoke update unexpectedly changed a product business field."
    }
    $failureStage = "subscriber-delivery"
    $deliveryEventId = Get-SubscriberDelivery -ProductId $updated.Id -ProductName $updated.Name
    $deliveryObserved = -not [string]::IsNullOrWhiteSpace($deliveryEventId)

    $summary.productUpdateId = $updated.Id
    $summary.productUpdateFieldsUnchanged = $productFieldsUnchanged
    $summary.subscriberDeliveryObserved = $deliveryObserved
    $summary.outboxEventId = $deliveryEventId
    $summary.status = "passed"
}
catch {
    $failure = $_
    $summary.status = "failed"
    $summary.failureStage = $failureStage
    $summary.failureMessage = $_.Exception.Message
}
finally {
    if ($null -ne $evidenceRoot -and $composeMayExist) {
        $diagnosticFailures = @()
        try {
            $composePs = @(& docker @composeBaseArguments ps --all 2>&1)
            $summary.composePsExitCode = $LASTEXITCODE
            $summary.composePsCaptured = $LASTEXITCODE -eq 0
            if (-not $summary.composePsCaptured) {
                $diagnosticFailures += "docker compose ps failed with exit code $LASTEXITCODE."
            }

            $composeLogs = @(& docker @composeBaseArguments logs --no-color --timestamps 2>&1)
            $summary.composeLogsExitCode = $LASTEXITCODE
            $summary.composeLogsCaptured = $LASTEXITCODE -eq 0
            if (-not $summary.composeLogsCaptured) {
                $diagnosticFailures += "docker compose logs failed with exit code $LASTEXITCODE."
            }
        }
        catch {
            $diagnosticFailures += "Could not collect Compose diagnostics: $($_.Exception.Message)"
        }

        if ($diagnosticFailures.Count -gt 0) {
            $summary.composeDiagnosticsError = $diagnosticFailures -join " "
            if ($null -eq $failure) {
                $failure = [System.InvalidOperationException]::new($summary.composeDiagnosticsError)
                $summary.status = "failed"
                $summary.failureStage = "compose-diagnostics"
                $summary.failureMessage = $summary.composeDiagnosticsError
            }
            else {
                Write-Warning "Compose diagnostics also failed: $($summary.composeDiagnosticsError)"
            }
        }
    }

    if ($Cleanup -and $composeMayExist) {
        $summary.cleanupAttempted = $true
        try {
            Invoke-CleanCompose -Arguments @("down", "--volumes", "--remove-orphans")
            $remainingResources = @()
            foreach ($resourceType in @("container", "volume", "network")) {
                $remainingResources += Get-IsolatedDockerResources -ResourceType $resourceType
            }
            if ($remainingResources.Count -gt 0) {
                throw "Isolated Compose cleanup left resources for '$ProjectName': $($remainingResources -join ', ')"
            }

            $summary.cleanupResourcesVerified = $true
            $summary.cleanupCompleted = $true
        }
        catch {
            $summary.cleanupError = $_.Exception.Message
            if ($null -eq $failure) {
                $failure = $_
                $summary.status = "failed"
                $summary.failureStage = "cleanup"
                $summary.failureMessage = $_.Exception.Message
            }
            else {
                Write-Warning "Cleanup also failed: $($_.Exception.Message)"
            }
        }
    }

    $summary.completedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    if ($null -ne $evidenceRoot) {
        try {
            Write-CleanComposeEvidence -Summary $summary -ComposePs $composePs -ComposeLogs $composeLogs
        }
        catch {
            if ($null -eq $failure) {
                $failure = $_
                $summary.status = "failed"
                $summary.failureStage = "evidence-write"
                $summary.failureMessage = "Could not write smoke evidence: $($_.Exception.Message)"
            }
            else {
                Write-Warning "Writing smoke evidence also failed: $($_.Exception.Message)"
            }
        }
    }

    if ($apiPortMutexAcquired -and $null -ne $apiPortMutex) {
        try {
            $apiPortMutex.ReleaseMutex()
        }
        catch {
            Write-Warning "Could not release clean-smoke API-port lock '$apiPortMutexName': $($_.Exception.Message)"
        }
    }

    if ($null -ne $apiPortMutex) {
        $apiPortMutex.Dispose()
    }
}

if ($null -ne $failure) {
    throw $failure
}

$summary | ConvertTo-Json -Compress
