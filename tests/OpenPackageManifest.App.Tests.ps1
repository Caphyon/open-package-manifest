<#
  Tests for the application-fragment object model + New-OpmApplicationFragment.
  (Wave 4A appends Set-OpmApplication / Set-OpmDetectionRule cases here.)
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'OpenPackageManifest\OpenPackageManifest.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module OpenPackageManifest -Force -ErrorAction SilentlyContinue
}

Describe 'New-OpmApplicationFragment' {

    It 'requires a Name' {
        { New-OpmApplicationFragment -Name '' } | Should -Throw
    }

    It 'returns a PacKit.ApplicationFragment object' {
        $app = New-OpmApplicationFragment -Name 'Acme Reader'
        $app.PSObject.TypeNames[0] | Should -BeExactly 'PacKit.ApplicationFragment'
    }

    It 'defaults AppId to a braced UPPERCASE GUID' {
        $app = New-OpmApplicationFragment -Name 'Acme Reader'
        $app.AppId | Should -MatchExactly '^\{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\}$'
    }

    It 'accepts and normalises a supplied AppId to braced UPPERCASE' {
        $app = New-OpmApplicationFragment -Name 'Acme Reader' -AppId '0a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d'
        $app.AppId | Should -BeExactly '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
    }

    It 'keeps an already-canonical AppId unchanged' {
        $app = New-OpmApplicationFragment -Name 'Acme Reader' -AppId '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
        $app.AppId | Should -BeExactly '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
    }

    It 'throws on a non-GUID AppId' {
        { New-OpmApplicationFragment -Name 'Acme Reader' -AppId 'not-a-guid' } | Should -Throw
    }

    It 'sets the supplied application fields' {
        $app = New-OpmApplicationFragment -Name 'Acme Reader' -Vendor 'Acme Corporation' -Description 'Reads PDFs' -IconPath 'icons\app.png' -OperatingSys 'Windows' -OperatingSysArchitecture '64-bit'
        $app.Name | Should -BeExactly 'Acme Reader'
        $app.Vendor | Should -BeExactly 'Acme Corporation'
        $app.Description | Should -BeExactly 'Reads PDFs'
        $app.IconPath | Should -BeExactly 'icons\app.png'
        $app.OperatingSys | Should -BeExactly 'Windows'
        $app.OperatingSysArchitecture | Should -BeExactly '64-bit'
    }

    It 'initialises empty Packages and IntuneAssignments arrays' {
        $app = New-OpmApplicationFragment -Name 'Acme Reader'
        , $app.Packages | Should -BeOfType [System.Object[]]
        $app.Packages.Count | Should -Be 0
        $app.IntuneAssignments.Count | Should -Be 0
    }

    It 'has a nested PacKit.DetectionRule with empty defaults' {
        $app = New-OpmApplicationFragment -Name 'Acme Reader'
        $app.DetectionRule.PSObject.TypeNames[0] | Should -BeExactly 'PacKit.DetectionRule'
        $app.DetectionRule.Format | Should -BeExactly ''
        $app.DetectionRule.MsiValue | Should -BeExactly ''
    }

    It 'defaults numeric and boolean fields correctly' {
        $app = New-OpmApplicationFragment -Name 'Acme Reader'
        $app.WinGetAppScannedAt | Should -Be 0
        $app.Unseen | Should -BeFalse
    }
}

Describe 'PacKit object factories' {

    It 'package factory yields a PacKit.Package with empty WinGetScanResults' {
        $pkg = InModuleScope OpenPackageManifest { New-OpmPackageObject }
        $pkg.PSObject.TypeNames[0] | Should -BeExactly 'PacKit.Package'
        $pkg.WinGetScanResults.Count | Should -Be 0
        $pkg.CatalogUpdateAvailable | Should -BeFalse
        $pkg.CatalogUpdateCheckedAt | Should -Be 0
    }

    It 'scan-result factory yields a PacKit.WinGetScanResult with double score' {
        $r = InModuleScope OpenPackageManifest { New-OpmWinGetScanResultObject }
        $r.PSObject.TypeNames[0] | Should -BeExactly 'PacKit.WinGetScanResult'
        $r.MatchScore | Should -BeOfType [double]
    }

    It 'assignment factory yields a PacKit.Assignment' {
        $a = InModuleScope OpenPackageManifest { New-OpmAssignmentObject }
        $a.PSObject.TypeNames[0] | Should -BeExactly 'PacKit.Assignment'
    }
}
