#Requires -Version 5.1
<#
.SYNOPSIS
  Build, lint, test, package and publish the OpenPackageManifest PowerShell module.

.DESCRIPTION
  Single entry point used locally and by CI. Tasks:
    Clean   - remove the output folder
    Lint    - run PSScriptAnalyzer with PSScriptAnalyzerSettings.psd1
    Test    - run the Pester 5 suite (writes NUnit results to output\testResults.xml)
    Package - stage the runtime module to output\OpenPackageManifest and zip it to output\OpenPackageManifest-<version>.zip
    Publish - Publish-Module the staged module to a gallery (needs an API key)
    All     - Clean + Lint + Test + Package (the default)

  Use -Bootstrap to install the required modules (NuGet provider, Pester 5,
  PSScriptAnalyzer) to the CurrentUser scope first.

.EXAMPLE
  .\build.ps1                      # Clean + Lint + Test + Package
.EXAMPLE
  .\build.ps1 -Task Test
.EXAMPLE
  .\build.ps1 -Bootstrap -Task All
.EXAMPLE
  .\build.ps1 -Task Publish -NuGetApiKey $env:PSGALLERY_API_KEY
#>
[CmdletBinding()]
param(
    [ValidateSet('Clean', 'Lint', 'Test', 'Build', 'Package', 'Publish', 'All')]
    [string[]] $Task = @('All'),

    [string] $OutputPath,

    [string] $NuGetApiKey = $env:PSGALLERY_API_KEY,

    [string] $Repository = 'PSGallery',

    [switch] $Bootstrap
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# $PSScriptRoot is not reliably populated in param defaults under -File on PS 5.1;
# resolve the script directory in the body and use it everywhere.
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrEmpty($OutputPath)) { $OutputPath = Join-Path $scriptDir 'output' }

$ModuleName = 'OpenPackageManifest'
$ModuleRoot = Join-Path $scriptDir $ModuleName
$ManifestPath = Join-Path $ModuleRoot "$ModuleName.psd1"
$StagePath = Join-Path $OutputPath $ModuleName

function Get-ModuleVersion {
    [OutputType([string])]
    param()
    return [string](Import-PowerShellDataFile -Path $ManifestPath).ModuleVersion
}

function Invoke-Bootstrap {
    Write-Host 'Bootstrapping build dependencies (CurrentUser)...' -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force -Scope CurrentUser | Out-Null
    }
    foreach ($dep in @(
            @{ Name = 'Pester'; Min = '5.0.0' },
            @{ Name = 'PSScriptAnalyzer'; Min = '1.20.0' })) {
        $have = Get-Module -ListAvailable -Name $dep.Name |
            Where-Object { $_.Version -ge [version]$dep.Min }
        if (-not $have) {
            Write-Host ("  installing {0} >= {1}" -f $dep.Name, $dep.Min)
            Install-Module -Name $dep.Name -MinimumVersion $dep.Min -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
        }
    }
}

function Initialize-OutputPath {
    if (-not (Test-Path -LiteralPath $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
}

function Invoke-Clean {
    if (Test-Path -LiteralPath $OutputPath) {
        Remove-Item -LiteralPath $OutputPath -Recurse -Force
    }
    Write-Host "Clean: removed $OutputPath" -ForegroundColor Green
}

function Invoke-Lint {
    Import-Module PSScriptAnalyzer -MinimumVersion '1.20.0' -Force
    $settings = Join-Path $scriptDir 'PSScriptAnalyzerSettings.psd1'
    $targets = @(
        $ModuleRoot
        (Join-Path $scriptDir 'tests')
        (Join-Path $scriptDir 'examples')
        (Join-Path $scriptDir 'build.ps1')
        (Join-Path $scriptDir 'Invoke-Tests.ps1')
    ) | Where-Object { Test-Path -LiteralPath $_ }

    $results = @()
    foreach ($target in $targets) {
        $results += Invoke-ScriptAnalyzer -Path $target -Recurse -Settings $settings
    }

    if ($results.Count -gt 0) {
        $results | ForEach-Object {
            $line = 0
            try { $line = [int]$_.Line } catch { $line = 0 }
            [PSCustomObject]@{
                Severity = [string]$_.Severity
                File     = if ($_.ScriptName) { Split-Path $_.ScriptName -Leaf } else { '' }
                Line     = $line
                Rule     = [string]$_.RuleName
                Message  = [string]$_.Message
            }
        } | Sort-Object File, Line | Format-Table -AutoSize -Wrap | Out-String | Write-Host
        throw "Lint: PSScriptAnalyzer reported $($results.Count) issue(s)."
    }
    Write-Host 'Lint: clean' -ForegroundColor Green
}

function Invoke-Test {
    Remove-Module Pester -Force -ErrorAction SilentlyContinue
    Import-Module Pester -MinimumVersion '5.0.0' -Force
    $loaded = Get-Module Pester
    if ($loaded.Version.Major -lt 5) {
        throw "Pester 5+ required but loaded $($loaded.Version). Run: .\build.ps1 -Bootstrap"
    }
    Initialize-OutputPath

    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $scriptDir 'tests'
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = Join-Path $OutputPath 'testResults.xml'
    $config.TestResult.OutputFormat = 'NUnitXml'

    $result = Invoke-Pester -Configuration $config
    if ($result.FailedCount -gt 0) {
        throw "Test: $($result.FailedCount) test(s) failed."
    }
    Write-Host "Test: $($result.PassedCount) passed" -ForegroundColor Green
}

function Invoke-Package {
    $version = Get-ModuleVersion
    Initialize-OutputPath

    if (Test-Path -LiteralPath $StagePath) {
        Remove-Item -LiteralPath $StagePath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $StagePath -Force | Out-Null

    # Runtime module files only (no tests/examples/build tooling).
    Copy-Item -LiteralPath $ManifestPath -Destination $StagePath
    Copy-Item -LiteralPath (Join-Path $ModuleRoot "$ModuleName.psm1") -Destination $StagePath
    foreach ($dir in @('Public', 'Private', 'Schema')) {
        Copy-Item -LiteralPath (Join-Path $ModuleRoot $dir) -Destination $StagePath -Recurse
    }
    # Ship license + docs alongside the module.
    foreach ($doc in @('LICENSE', 'README.md', 'CHANGELOG.md')) {
        $docPath = Join-Path $scriptDir $doc
        if (Test-Path -LiteralPath $docPath) {
            Copy-Item -LiteralPath $docPath -Destination $StagePath
        }
    }

    # The staged manifest must validate.
    Test-ModuleManifest -Path (Join-Path $StagePath "$ModuleName.psd1") | Out-Null

    $zip = Join-Path $OutputPath ("{0}-{1}.zip" -f $ModuleName, $version)
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -Path $StagePath -DestinationPath $zip

    Write-Host "Package: staged $StagePath" -ForegroundColor Green
    Write-Host "Package: zipped  $zip" -ForegroundColor Green
}

function Invoke-Publish {
    param(
        [string] $ApiKey,
        [string] $RepositoryName
    )
    if ([string]::IsNullOrEmpty($ApiKey)) {
        throw 'Publish: an API key is required. Pass -NuGetApiKey or set $env:PSGALLERY_API_KEY.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $StagePath "$ModuleName.psd1"))) {
        Invoke-Package
    }
    $version = Get-ModuleVersion
    Write-Host "Publish: $ModuleName $version -> $RepositoryName" -ForegroundColor Cyan
    Publish-Module -Path $StagePath -NuGetApiKey $ApiKey -Repository $RepositoryName -Force
    Write-Host "Publish: done" -ForegroundColor Green
}

if ($Bootstrap) { Invoke-Bootstrap }

$plan = if ($Task -contains 'All') { @('Clean', 'Lint', 'Test', 'Package') } else { $Task }

foreach ($t in $plan) {
    Write-Host "==> $t" -ForegroundColor Cyan
    switch ($t) {
        'Clean' { Invoke-Clean }
        'Lint' { Invoke-Lint }
        'Test' { Invoke-Test }
        'Build' { Invoke-Package }
        'Package' { Invoke-Package }
        'Publish' { Invoke-Publish -ApiKey $NuGetApiKey -RepositoryName $Repository }
    }
}

Write-Host 'Build complete.' -ForegroundColor Green
