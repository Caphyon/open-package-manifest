<#
.SYNOPSIS
  Run the PacKit module Pester suite, forcing Pester 5.

.DESCRIPTION
  Windows ships Pester 3.4.0; this repo also has Pester 5.7.1 (CurrentUser).
  A bare 'Import-Module Pester' loads 3.4.0 on PowerShell 5.1, which CANNOT run
  these tests. This runner forces Pester >= 5 and returns the failed-test count
  as the process exit code (0 = success), suitable for CI.

.EXAMPLE
  powershell -NoProfile -File .\Invoke-Tests.ps1

.EXAMPLE
  powershell -NoProfile -File .\Invoke-Tests.ps1 -TestPath .\tests\PacKit.Emitter.Tests.ps1
#>
[CmdletBinding()]
param(
    [string] $TestPath,
    [switch] $CI
)

$ErrorActionPreference = 'Stop'

Remove-Module Pester -Force -ErrorAction SilentlyContinue
Import-Module Pester -MinimumVersion 5.0.0 -Force

$loaded = Get-Module Pester
Write-Host "Using Pester $($loaded.Version)" -ForegroundColor Cyan
if ($loaded.Version.Major -lt 5) {
    throw "Pester 5+ required but loaded $($loaded.Version). Install: Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force -SkipPublisherCheck"
}

$testsDir = Join-Path $PSScriptRoot 'tests'

$config = New-PesterConfiguration
$config.Run.Path = if ($TestPath) { $TestPath } else { $testsDir }
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
if ($CI) {
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = (Join-Path $PSScriptRoot 'testResults.xml')
    $config.TestResult.OutputFormat = 'NUnitXml'
}

$result = Invoke-Pester -Configuration $config
exit $result.FailedCount
