<#
.SYNOPSIS
  Validate a PacKit application fragment before saving.

.DESCRIPTION
  Checks the hard requirements PacKit enforces on load:
    - AppId is a valid braced UPPERCASE GUID
    - Name is non-empty
    - every package PackageId is a valid GUID
    - every assignment MsEntraGroupId is a valid GUID
    - no text field contains an XML-invalid control character (only TAB, CR and
      LF are allowed); such characters would make PacKit's XML reader reject the
      fragment
  And reports soft warnings (which do NOT fail validation):
    - a package Type that is not one of PacKit's recognised installer types

  Returns $true/$false by default. With -Detailed, returns an object with
  IsValid, Errors and Warnings so CI can log specifics.

.EXAMPLE
  if (-not (Test-PacKitApplicationFragment -Fragment $app)) { throw 'invalid fragment' }

.EXAMPLE
  $report = Test-PacKitApplicationFragment -Fragment $app -Detailed
  $report.Errors
#>
function Test-PacKitApplicationFragment {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $Fragment,

        [Parameter()]
        [switch] $Detailed
    )

    process {
        $errors = New-Object System.Collections.Generic.List[string]
        $warnings = New-Object System.Collections.Generic.List[string]
        $schema = Get-PacKitSchema

        if (-not (Test-PacKitGuid -Value $Fragment.AppId)) {
            $errors.Add("AppId '$($Fragment.AppId)' is not a valid braced UPPERCASE GUID.")
        }
        if ([string]::IsNullOrEmpty($Fragment.Name)) {
            $errors.Add('Name is empty; PacKit requires a non-empty application name.')
        }

        foreach ($pkg in @($Fragment.Packages)) {
            if (-not (Test-PacKitGuid -Value $pkg.PackageId)) {
                $errors.Add("Package PackageId '$($pkg.PackageId)' is not a valid braced UPPERCASE GUID.")
            }
            if (-not [string]::IsNullOrEmpty($pkg.Type) -and ($schema.PackageTypes -notcontains $pkg.Type)) {
                $warnings.Add("Package Type '$($pkg.Type)' is not one of PacKit's recognised installer types ($($schema.PackageTypes -join ', ')).")
            }
        }

        foreach ($asg in @($Fragment.IntuneAssignments)) {
            if (-not (Test-PacKitGuid -Value $asg.MsEntraGroupId)) {
                $errors.Add("Assignment MsEntraGroupId '$($asg.MsEntraGroupId)' is not a valid braced UPPERCASE GUID.")
            }
        }

        # XML-invalid control characters in any text field would make PacKit's XML
        # reader reject the fragment (the writer would emit references like &#1;).
        $textTargets = @(@{ Obj = $Fragment; Descriptors = $schema.App; Label = 'Application' })
        foreach ($pkg in @($Fragment.Packages)) {
            $textTargets += @{ Obj = $pkg; Descriptors = $schema.Package; Label = 'Package' }
            foreach ($scan in @($pkg.WinGetScanResults)) {
                $textTargets += @{ Obj = $scan; Descriptors = $schema.WinGetScanResult; Label = 'WinGetScanResult' }
            }
        }
        foreach ($asg in @($Fragment.IntuneAssignments)) {
            $textTargets += @{ Obj = $asg; Descriptors = $schema.Assignment; Label = 'Assignment' }
        }
        foreach ($target in $textTargets) {
            foreach ($d in $target.Descriptors) {
                if ($d.Type -ne 'String') { continue }
                $text = [string](Get-PacKitValueByPath -Object $target.Obj -Path $d.Path)
                if (-not (Test-PacKitXmlSafeText -Value $text)) {
                    $errors.Add("$($target.Label) field '$($d.Name)' contains an XML-invalid control character (only TAB, CR and LF are allowed); PacKit's XML reader would reject the fragment.")
                }
            }
        }

        $isValid = ($errors.Count -eq 0)

        if ($Detailed) {
            return [PSCustomObject]@{
                IsValid  = $isValid
                Errors   = $errors.ToArray()
                Warnings = $warnings.ToArray()
            }
        }

        return $isValid
    }
}
