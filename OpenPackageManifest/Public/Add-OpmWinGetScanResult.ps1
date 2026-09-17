<#
.SYNOPSIS
  Add a WinGet scan result to a package on a PacKit application fragment.

.DESCRIPTION
  Appends a WinGet scan result (catalog package id, match score, vendor) to the
  WinGetScanResults collection of the package identified by -PackageId. The
  match score is stored as a double and serialised with six decimals
  (e.g. 0.95 -> "0.950000"), matching PacKit.

.EXAMPLE
  Add-OpmWinGetScanResult -Fragment $app -PackageId '{1B2C...}' -CatalogPackageId 'Acme.Reader' -MatchScore 0.95 -Vendor 'Acme'
#>
function Add-OpmWinGetScanResult {
    [CmdletBinding()]
    [OutputType('PacKit.WinGetScanResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $Fragment,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PackageId,

        [Parameter()] [string] $CatalogPackageId = '',
        [Parameter()] [double] $MatchScore = 0.0,
        [Parameter()] [string] $Vendor = '',

        [Parameter()] [switch] $PassThru
    )

    process {
        $target = ConvertTo-OpmCanonicalGuid -Value $PackageId
        $pkg = @($Fragment.Packages) | Where-Object { $_.PackageId -eq $target } | Select-Object -First 1
        if ($null -eq $pkg) {
            throw "No package with PackageId '$PackageId' was found on the fragment."
        }

        $scan = New-OpmWinGetScanResultObject
        $scan.CatalogPackageId = $CatalogPackageId
        $scan.MatchScore = $MatchScore
        $scan.Vendor = $Vendor

        $pkg.WinGetScanResults = @($pkg.WinGetScanResults) + $scan

        if ($PassThru) { return $scan }
    }
}
