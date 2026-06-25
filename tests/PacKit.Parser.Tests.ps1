<#
  Tests for ConvertFrom-PacKitXmlString - parses a fragment back into the typed
  object model and unescapes attribute values (the inverse of the emitter).
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'PacKit\PacKit.psd1'
    Import-Module $modulePath -Force

    $script:fixturesDir = Join-Path $PSScriptRoot 'fixtures'
    $script:goldenFragmentText = [System.IO.File]::ReadAllText((Join-Path $script:fixturesDir 'golden-fragment.xml'))
    $script:goldenEmptyText = [System.IO.File]::ReadAllText((Join-Path $script:fixturesDir 'golden-empty.xml'))

    $script:app = InModuleScope PacKit -Parameters @{ xml = $script:goldenFragmentText } {
        param($xml)
        ConvertFrom-PacKitXmlString -Xml $xml
    }
    $script:empty = InModuleScope PacKit -Parameters @{ xml = $script:goldenEmptyText } {
        param($xml)
        ConvertFrom-PacKitXmlString -Xml $xml
    }
}

AfterAll {
    Remove-Module PacKit -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertFrom-PacKitXmlString' {

    It 'returns a PacKit.ApplicationFragment' {
        $script:app.PSObject.TypeNames[0] | Should -BeExactly 'PacKit.ApplicationFragment'
    }

    It 'reads the application-level fields' {
        $script:app.AppId | Should -BeExactly '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
        $script:app.Vendor | Should -BeExactly 'Acme Corporation'
        $script:app.Description | Should -BeExactly 'Reads PDFs'
        $script:app.IconPath | Should -BeExactly 'icons\app.png'
        $script:app.OperatingSys | Should -BeExactly 'Windows'
        $script:app.OperatingSysArchitecture | Should -BeExactly 'x64'
    }

    It 'unescapes the named XML entities back to the raw Name' {
        $expected = 'Acme & Co "Reader" <v1> ' + [char]39 + 'X' + [char]39
        $script:app.Name | Should -BeExactly $expected
    }

    It 'types numeric and boolean fields' {
        $script:app.WinGetAppScannedAt | Should -BeOfType [long]
        $script:app.WinGetAppScannedAt | Should -Be 0
        $script:app.Unseen | Should -BeOfType [bool]
        $script:app.Unseen | Should -BeFalse
    }

    It 'reads one package with the expected fields' {
        $script:app.Packages.Count | Should -Be 1
        $pkg = $script:app.Packages[0]
        $pkg.PSObject.TypeNames[0] | Should -BeExactly 'PacKit.Package'
        $pkg.PackageId | Should -BeExactly '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}'
        $pkg.Path | Should -BeExactly 'app.msi'
        $pkg.Type | Should -BeExactly 'msi'
        $pkg.Version | Should -BeExactly '1.0.0'
        $pkg.InstallCmdLine | Should -BeExactly '/qn'
        $pkg.CatalogUpdateAvailable | Should -BeFalse
    }

    It 'reads the WinGet scan result with a typed double score' {
        $pkg = $script:app.Packages[0]
        $pkg.WinGetScanResults.Count | Should -Be 1
        $scan = $pkg.WinGetScanResults[0]
        $scan.CatalogPackageId | Should -BeExactly 'Acme.Reader'
        $scan.Vendor | Should -BeExactly 'Acme'
        $scan.MatchScore | Should -BeOfType [double]
        $scan.MatchScore | Should -Be 0.95
    }

    It 'reads one Intune assignment' {
        $script:app.IntuneAssignments.Count | Should -Be 1
        $asg = $script:app.IntuneAssignments[0]
        $asg.MsEntraGroupId | Should -BeExactly '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}'
        $asg.AssignmentType | Should -BeExactly 'Required'
        $asg.InclusionType | Should -BeExactly 'Include'
    }

    It 'parses an empty fragment with no packages or assignments' {
        $script:empty.Name | Should -BeExactly 'Minimal'
        $script:empty.Packages.Count | Should -Be 0
        $script:empty.IntuneAssignments.Count | Should -Be 0
    }

    It 'throws on a non-fragment root element' {
        {
            InModuleScope PacKit { ConvertFrom-PacKitXmlString -Xml '<PROJECT Version="23.8"></PROJECT>' }
        } | Should -Throw
    }

    It 'throws on malformed XML' {
        {
            InModuleScope PacKit { ConvertFrom-PacKitXmlString -Xml '<FRAGMENT><ITEM' }
        } | Should -Throw
    }
}
