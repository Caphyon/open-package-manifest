<#
.SYNOPSIS
  Build a sample .packit application fragment and verify it end to end.

.DESCRIPTION
  Demonstrates the "instrument an application" recipe a third party would run in
  CI/CD, then proves the produced fragment is PacKit-compatible:
    1. import the PacKit module
    2. author an application (name, vendor, icon, detection rule)
    3. add an installer package, a WinGet scan result and an Intune assignment
    4. validate, create the .packit folder, and export the fragment
    5. verify on-disk encoding (UTF-8 no BOM), declaration, CRLF, schema shape,
       braced-UPPERCASE GUIDs, relative paths, a clean load round-trip, and
       (optionally) byte-identity against a golden fixture.

  Exits 0 only if every check passes; non-zero otherwise (CI-friendly).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File examples\Build-SampleApp.ps1 -OutDir C:\temp\packit-qa
#>
[CmdletBinding()]
param(
    [string] $OutDir = (Join-Path $env:TEMP ('opm-sample-' + [guid]::NewGuid())),
    [string] $GoldenPath
)

$ErrorActionPreference = 'Stop'
$script:failures = 0

# $PSScriptRoot is not reliably populated in param defaults under -File, so resolve here.
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $GoldenPath) {
    $GoldenPath = Join-Path $scriptDir '..\tests\fixtures\golden-fragment.xml'
}

function Assert-True {
    param([string] $Label, [bool] $Condition, [string] $Detail = '')
    if ($Condition) {
        Write-Host ("  [PASS] {0}" -f $Label) -ForegroundColor Green
    }
    else {
        Write-Host ("  [FAIL] {0} {1}" -f $Label, $Detail) -ForegroundColor Red
        $script:failures++
    }
}

Write-Host "PacKit sample build + verification" -ForegroundColor Cyan
Write-Host ("PowerShell {0} ({1})" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)

Import-Module (Join-Path $scriptDir '..\OpenPackageManifest\OpenPackageManifest.psd1') -Force

$appId = '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
$pkgId = '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}'
$groupId = '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}'

# --- 2..3 author + instrument -------------------------------------------------
$app = New-OpmApplicationFragment -Name "Acme & Co `"Reader`" <v1> 'X'" -AppId $appId `
    -Vendor 'Acme Corporation' -Description 'Reads PDFs' -IconPath 'icons\app.png' `
    -OperatingSys 'Windows' -OperatingSysArchitecture '64-bit'

Add-OpmPackage -Fragment $app -Path 'app.msi' -PackageId $pkgId -InstallCmdLine '/qn' -Version '1.0.0' | Out-Null
Add-OpmWinGetScanResult -Fragment $app -PackageId $pkgId -CatalogPackageId 'Acme.Reader' -MatchScore 0.95 -Vendor 'Acme' | Out-Null
Add-OpmAssignment -Fragment $app -MsEntraGroupId $groupId -AssignmentType 'Required' -InclusionType 'included' | Out-Null

Write-Host "`nValidation:" -ForegroundColor Cyan
Assert-True 'fragment validates' (Test-OpmApplicationFragment -Fragment $app)

# --- 4 export -----------------------------------------------------------------
Initialize-OpmFolder -SourceFolder $OutDir | Out-Null
$written = Export-OpmApplicationFragment -Fragment $app -SourceFolder $OutDir
Write-Host ("`nWrote: {0}" -f $written)

# --- 5 verify the artifact ----------------------------------------------------
Write-Host "`nArtifact checks:" -ForegroundColor Cyan
$bytes = [System.IO.File]::ReadAllBytes($written)
$text = [System.IO.File]::ReadAllText($written)
$doc = [xml]$text

$expectedFile = Join-Path $OutDir ('.packit\' + $appId + '.xml')
Assert-True 'fragment written to .packit\<AppId>.xml' ($written -eq $expectedFile) $written
Assert-True 'UTF-8 with NO BOM' (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF))
Assert-True 'exact XML declaration' ($text.StartsWith('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + [char]13 + [char]10))
$crlf = ([regex]::Matches($text, ([char]13 + [char]10))).Count
$lf = ([regex]::Matches($text, [char]10)).Count
Assert-True 'CRLF line endings (CRLF == LF count)' ($crlf -eq $lf) ("crlf=$crlf lf=$lf")
Assert-True 'FRAGMENT root element' ($doc.DocumentElement.Name -eq 'FRAGMENT')
Assert-True 'FRAGMENT Version = 23.8' ($doc.DocumentElement.Version -eq '23.8')
Assert-True 'exactly one app ITEM' (@($doc.DocumentElement.SelectNodes('ITEM')).Count -eq 1)
$item = $doc.DocumentElement.SelectSingleNode('ITEM')
Assert-True 'Packages COLLECTION present' ($null -ne $item.SelectSingleNode("COLLECTION[@Name='Packages']"))
Assert-True 'IntuneAssignments COLLECTION present' ($null -ne $item.SelectSingleNode("COLLECTION[@Name='IntuneAssignments']"))

foreach ($g in @(@{n = 'AppId'; v = $item.GetAttribute('AppId') },
        @{n = 'PackageId'; v = $item.SelectSingleNode("COLLECTION[@Name='Packages']/ITEM").GetAttribute('PackageId') },
        @{n = 'MsEntraGroupId'; v = $item.SelectSingleNode("COLLECTION[@Name='IntuneAssignments']/ITEM").GetAttribute('MsEntraGroupId') })) {
    Assert-True ("{0} is a braced UPPERCASE GUID" -f $g.n) ($g.v -cmatch '^\{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\}$') $g.v
}

$pkgPath = $item.SelectSingleNode("COLLECTION[@Name='Packages']/ITEM").GetAttribute('Path')
Assert-True 'package Path stored relative' (-not [System.IO.Path]::IsPathRooted($pkgPath)) $pkgPath
Assert-True 'special characters escaped' ($text -match [regex]::Escape('Name="Acme &amp; Co &quot;Reader&quot; &lt;v1&gt; &apos;X&apos;"'))

# --- load round-trip ----------------------------------------------------------
Write-Host "`nRound-trip:" -ForegroundColor Cyan
$reloaded = Import-OpmApplicationFragment -SourceFolder $OutDir
Assert-True 'reloads with the same AppId' ($reloaded.AppId -eq $appId)
Assert-True 'reloads the raw (unescaped) Name' ($reloaded.Name -eq ("Acme & Co `"Reader`" <v1> 'X'"))
Assert-True 'reloads one package (Type=msi)' ($reloaded.Packages.Count -eq 1 -and $reloaded.Packages[0].Type -eq 'msi')
Assert-True 'reloads one assignment' ($reloaded.IntuneAssignments.Count -eq 1)
$out2 = Join-Path $OutDir 'roundtrip.xml'
Export-OpmApplicationFragment -Fragment $reloaded -LiteralPath $out2 | Out-Null
Assert-True 'export is idempotent (re-export byte-stable)' ((([System.IO.File]::ReadAllBytes($out2)) -join ',') -eq ($bytes -join ','))

# --- byte-identity vs golden --------------------------------------------------
Write-Host "`nGolden comparison:" -ForegroundColor Cyan
$identical = $false
if (Test-Path -LiteralPath $GoldenPath) {
    $golden = [System.IO.File]::ReadAllBytes($GoldenPath)
    $identical = (($bytes -join ',') -eq ($golden -join ','))
    Assert-True 'byte-identical to golden-fragment.xml' $identical
}
else {
    Write-Host ("  [SKIP] golden fixture not found at {0}" -f $GoldenPath) -ForegroundColor Yellow
}

Write-Host ("`nBYTE-IDENTICAL TO GOLDEN: {0}" -f $identical) -ForegroundColor Cyan
$summaryColor = if ($script:failures -eq 0) { 'Green' } else { 'Red' }
Write-Host ("FAILURES: {0}" -f $script:failures) -ForegroundColor $summaryColor

if ($script:failures -gt 0) { exit 1 }
Write-Host "ALL CHECKS PASSED" -ForegroundColor Green
exit 0
