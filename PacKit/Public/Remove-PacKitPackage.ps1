<#
.SYNOPSIS
  Remove a package from a PacKit application fragment by PackageId.

.DESCRIPTION
  Removes the package whose PackageId matches (case-insensitively) from the
  fragment's Packages collection. The fragment is modified in place.

.EXAMPLE
  Remove-PacKitPackage -Fragment $app -PackageId '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}'
#>
function Remove-PacKitPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $Fragment,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PackageId,

        [Parameter()] [switch] $PassThru
    )

    process {
        $target = ConvertTo-PacKitCanonicalGuid -Value $PackageId
        $before = @($Fragment.Packages).Count
        $Fragment.Packages = @($Fragment.Packages | Where-Object { $_.PackageId -ne $target })
        $after = @($Fragment.Packages).Count

        if ($after -eq $before) {
            Write-Verbose "No package with PackageId '$PackageId' was found; nothing removed."
        }

        if ($PassThru) { return $Fragment }
    }
}
