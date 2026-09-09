[CmdletBinding()]
param(
    [string]$DatasetPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repositoryRoot 'artifacts\external-real-data-benchmark\uci-online-retail-rolling-v1.json'
}

if ([string]::IsNullOrWhiteSpace($DatasetPath)) {
    # Keep the source workbook outside the repository. The resulting JSON has
    # aggregate counts and a SHA-256 only; it does not import UCI rows into the
    # PadelClub operational database.
    $benchmarkTempRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'padelclub-uci-online-retail'
    $archivePath = Join-Path $benchmarkTempRoot 'online-retail.zip'
    $extractPath = Join-Path $benchmarkTempRoot 'extracted'
    $DatasetPath = Join-Path $extractPath 'Online Retail.xlsx'

    New-Item -ItemType Directory -Path $benchmarkTempRoot -Force | Out-Null
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        Write-Host 'Downloading the UCI Online Retail archive to a temporary directory...'
        Invoke-WebRequest `
            -Uri 'https://archive.ics.uci.edu/static/public/352/online%2Bretail.zip' `
            -OutFile $archivePath
    }

    if (-not (Test-Path -LiteralPath $DatasetPath -PathType Leaf)) {
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force
    }
}

if (-not (Test-Path -LiteralPath $DatasetPath -PathType Leaf)) {
    throw "The UCI workbook was not found: $DatasetPath"
}

$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

& dotnet run `
    --project (Join-Path $repositoryRoot 'tools\PadelClub.RecommendationBenchmark\PadelClub.RecommendationBenchmark.csproj') `
    --configuration Release `
    -- `
    --input $DatasetPath `
    --output $resolvedOutputPath

if ($LASTEXITCODE -ne 0) {
    throw "The recommendation benchmark exited with code $LASTEXITCODE."
}

Write-Host "Benchmark evidence written to: $resolvedOutputPath"
Write-Host 'This result is external public-data evidence for the algorithm, not PadelClub customer-performance evidence.'
