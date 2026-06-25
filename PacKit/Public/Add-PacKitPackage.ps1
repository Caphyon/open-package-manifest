<#
.SYNOPSIS
  Add an installer package to a PacKit application fragment.

.DESCRIPTION
  Appends a package to the fragment's Packages collection. A PackageId is
  generated (braced UPPERCASE GUID) unless supplied. The package Type is derived
  from the lowercase file extension of -Path (e.g. app.msi -> msi) unless an
  explicit -Type is given, mirroring how PacKit recomputes Type from the path.

  The fragment is modified in place. By default nothing is returned; use
  -PassThru to emit the newly created package object (e.g. to add scan results).

.EXAMPLE
  Add-PacKitPackage -Fragment $app -Path 'app.msi' -InstallCmdLine '/qn' -Version '1.0.0'

.EXAMPLE
  $pkg = Add-PacKitPackage -Fragment $app -Path 'Deploy-Application.ps1' -PassThru
#>
function Add-PacKitPackage {
    [CmdletBinding()]
    [OutputType('PacKit.Package')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $Fragment,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter()] [string] $PackageId,
        [Parameter()] [string] $Type,
        [Parameter()] [string] $Version = '',
        [Parameter()] [string] $InstallCmdLine = '',
        [Parameter()] [string] $UninstallCmdLine = '',
        [Parameter()] [string] $ProductCode = '',
        [Parameter()] [string] $PackageArchitecture = '',
        [Parameter()] [string] $SourceFolder = '',
        [Parameter()] [string] $CatalogPackageId = '',

        [Parameter()] [switch] $PassThru
    )

    process {
        $pkg = New-PacKitPackageObject

        if (-not [string]::IsNullOrEmpty($PackageId)) {
            $parsed = [guid]::Empty
            if (-not [guid]::TryParse($PackageId, [ref] $parsed)) {
                throw "PackageId '$PackageId' is not a valid GUID."
            }
            $pkg.PackageId = $parsed.ToString('B').ToUpperInvariant()
        }
        else {
            $pkg.PackageId = New-PacKitGuid
        }

        $pkg.Path = $Path
        if ($PSBoundParameters.ContainsKey('Type') -and -not [string]::IsNullOrEmpty($Type)) {
            $pkg.Type = $Type
        }
        else {
            $ext = [System.IO.Path]::GetExtension($Path)
            $pkg.Type = if ([string]::IsNullOrEmpty($ext)) { '' } else { $ext.TrimStart('.').ToLowerInvariant() }
        }

        $pkg.Version = $Version
        $pkg.InstallCmdLine = $InstallCmdLine
        $pkg.UninstallCmdLine = $UninstallCmdLine
        $pkg.ProductCode = $ProductCode
        $pkg.PackageArchitecture = $PackageArchitecture
        $pkg.SourceFolder = $SourceFolder
        $pkg.CatalogPackageId = $CatalogPackageId

        $Fragment.Packages = @($Fragment.Packages) + $pkg

        if ($PassThru) { return $pkg }
    }
}
