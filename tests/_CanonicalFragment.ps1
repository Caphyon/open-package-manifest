<#
  Shared test helper: builds the canonical sample fragment object (matching
  tests/fixtures/golden-fragment.xml) and a minimal one (golden-empty.xml).
  Not a test file (no *.Tests.ps1 suffix), so Pester discovery ignores it.
  Uses the module's private factories via InModuleScope, so it must be called
  from within a Pester run with the OpenPackageManifest module imported.
#>

function New-CanonicalOpmFragment {
    [CmdletBinding()]
    param()

    return InModuleScope OpenPackageManifest {
        $app = New-OpmApplicationFragmentObject
        $app.AppId = '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
        $app.Name = "Acme & Co `"Reader`" <v1> 'X'"
        $app.Vendor = 'Acme Corporation'
        $app.Description = 'Reads PDFs'
        $app.IconPath = 'icons\app.png'
        $app.OperatingSys = 'Windows'
        $app.OperatingSysArchitecture = '64-bit'

        $pkg = New-OpmPackageObject
        $pkg.PackageId = '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}'
        $pkg.InstallCmdLine = '/qn'
        $pkg.Path = 'app.msi'
        $pkg.Type = 'msi'
        $pkg.Version = '1.0.0'

        $scan = New-OpmWinGetScanResultObject
        $scan.CatalogPackageId = 'Acme.Reader'
        $scan.MatchScore = 0.95
        $scan.Vendor = 'Acme'
        $pkg.WinGetScanResults = @($scan)

        $app.Packages = @($pkg)

        $asg = New-OpmAssignmentObject
        $asg.MsEntraGroupId = '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}'
        $asg.AssignmentType = 'Required'
        $asg.InclusionType = 'included'
        $app.IntuneAssignments = @($asg)

        $app
    }
}

function New-MinimalOpmFragment {
    [CmdletBinding()]
    param()

    return InModuleScope OpenPackageManifest {
        $app = New-OpmApplicationFragmentObject
        $app.AppId = '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
        $app.Name = 'Minimal'
        $app
    }
}
