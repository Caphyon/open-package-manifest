<#
.SYNOPSIS
  OpenPackageManifest application-fragment authoring module (root module loader).
.DESCRIPTION
  Dot-sources every Private then Public script and exports the Public functions.
  Public/Private files are auto-discovered, so adding a new cmdlet file requires
  no edit here. The manifest (OpenPackageManifest.psd1) controls the externally visible surface.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$privateFiles = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue | Sort-Object FullName)
$publicFiles  = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public')  -Filter '*.ps1' -ErrorAction SilentlyContinue | Sort-Object FullName)

foreach ($file in @($privateFiles + $publicFiles)) {
    try {
        . $file.FullName
    }
    catch {
        throw "OpenPackageManifest: failed to import '$($file.FullName)': $($_.Exception.Message)"
    }
}

if ($publicFiles.Count -gt 0) {
    Export-ModuleMember -Function $publicFiles.BaseName
}
