<#
.SYNOPSIS
  Update an existing package on a PacKit application fragment by PackageId.

.DESCRIPTION
  Modifies the package whose PackageId matches. Only supplied parameters are
  changed. If -Path is supplied and -Type is not, the package Type is re-derived
  from the new path's lowercase extension (matching Add-OpmPackage).

.EXAMPLE
  Set-OpmPackage -Fragment $app -PackageId '{1B2C...}' -Version '2.0.0' -InstallCmdLine '/quiet'
#>
function Set-OpmPackage {
    [CmdletBinding()]
    [OutputType('PacKit.Package')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $Fragment,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PackageId,

        [Parameter()] [string] $Path,
        [Parameter()] [string] $Type,
        [Parameter()] [string] $Version,
        [Parameter()] [string] $InstallCmdLine,
        [Parameter()] [string] $UninstallCmdLine,
        [Parameter()] [string] $ProductCode,
        [Parameter()] [string] $PackageArchitecture,
        [Parameter()] [string] $SourceFolder,
        [Parameter()] [string] $CatalogPackageId,

        [Parameter()] [switch] $PassThru
    )

    process {
        $target = ConvertTo-OpmCanonicalGuid -Value $PackageId
        $pkg = @($Fragment.Packages) | Where-Object { $_.PackageId -eq $target } | Select-Object -First 1
        if ($null -eq $pkg) {
            throw "No package with PackageId '$PackageId' was found on the fragment."
        }

        foreach ($prop in @('Path', 'Type', 'Version', 'InstallCmdLine', 'UninstallCmdLine',
                'ProductCode', 'PackageArchitecture', 'SourceFolder', 'CatalogPackageId')) {
            if ($PSBoundParameters.ContainsKey($prop)) {
                $pkg.$prop = $PSBoundParameters[$prop]
            }
        }

        # Re-derive Type from a new Path unless Type was set explicitly.
        if ($PSBoundParameters.ContainsKey('Path') -and -not $PSBoundParameters.ContainsKey('Type')) {
            $ext = [System.IO.Path]::GetExtension($Path)
            $pkg.Type = if ([string]::IsNullOrEmpty($ext)) { '' } else { $ext.TrimStart('.').ToLowerInvariant() }
        }

        if ($PassThru) { return $pkg }
    }
}
