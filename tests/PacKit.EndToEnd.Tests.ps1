<#
  End-to-end test: drive the whole public surface to build the canonical sample
  and prove the produced .packit\<AppId>.xml is byte-identical to the golden
  fixture and re-loadable. This is the public-API contract test.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'PacKit\PacKit.psd1'
    Import-Module $modulePath -Force
    $script:goldenFragmentBytes = [System.IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'fixtures\golden-fragment.xml'))
    $script:appId = '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
    $script:pkgId = '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}'
    $script:groupId = '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}'
}

AfterAll {
    Remove-Module PacKit -Force -ErrorAction SilentlyContinue
}

Describe 'End-to-end: author -> instrument -> export -> import' {

    BeforeEach {
        $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ("packit-e2e-{0}" -f ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path $script:work -Force | Out-Null
    }

    AfterEach {
        Remove-Item -LiteralPath $script:work -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'builds a PacKit-loadable .packit folder byte-identical to golden through the public API' {
        # Author
        $app = New-PacKitApplicationFragment -Name "Acme & Co `"Reader`" <v1> 'X'" -AppId $script:appId `
            -Vendor 'Acme Corporation' -Description 'Reads PDFs' -IconPath 'icons\app.png' `
            -OperatingSys 'Windows' -OperatingSysArchitecture 'x64'

        Add-PacKitPackage -Fragment $app -Path 'app.msi' -PackageId $script:pkgId -InstallCmdLine '/qn' -Version '1.0.0' | Out-Null
        Add-PacKitWinGetScanResult -Fragment $app -PackageId $script:pkgId -CatalogPackageId 'Acme.Reader' -MatchScore 0.95 -Vendor 'Acme' | Out-Null
        Add-PacKitAssignment -Fragment $app -MsEntraGroupId $script:groupId -AssignmentType 'Required' -InclusionType 'Include' | Out-Null

        # Validate before saving
        Test-PacKitApplicationFragment -Fragment $app | Should -BeTrue

        # Instrument the source folder + export
        Initialize-PacKitFolder -SourceFolder $script:work | Out-Null
        $written = Export-PacKitApplicationFragment -Fragment $app -SourceFolder $script:work

        # The fragment lands at <work>\.packit\<AppId>.xml
        $expected = Join-Path $script:work ('.packit\' + $script:appId + '.xml')
        $written | Should -BeExactly $expected
        Test-Path -LiteralPath $expected | Should -BeTrue

        # Byte-identical to golden
        $bytes = [System.IO.File]::ReadAllBytes($expected)
        ($bytes -join ',') | Should -BeExactly ($script:goldenFragmentBytes -join ',')
    }

    It 'round-trips the exported folder back into an equivalent object' {
        $app = New-PacKitApplicationFragment -Name 'Acme Reader' -AppId $script:appId -Vendor 'Acme Corporation'
        Add-PacKitPackage -Fragment $app -Path 'app.msi' -PackageId $script:pkgId -InstallCmdLine '/qn' -Version '1.0.0' | Out-Null
        Export-PacKitApplicationFragment -Fragment $app -SourceFolder $script:work | Out-Null

        $reloaded = Import-PacKitApplicationFragment -SourceFolder $script:work
        $reloaded.AppId | Should -BeExactly $script:appId
        $reloaded.Vendor | Should -BeExactly 'Acme Corporation'
        $reloaded.Packages.Count | Should -Be 1
        $reloaded.Packages[0].Type | Should -BeExactly 'msi'
        $reloaded.Packages[0].InstallCmdLine | Should -BeExactly '/qn'
    }

    It 'is loadable by the PacKit reader contract (FRAGMENT root, one ITEM, valid GUID, relative paths)' {
        $app = New-PacKitApplicationFragment -Name 'Acme Reader' -AppId $script:appId
        Add-PacKitPackage -Fragment $app -Path 'app.msi' -PackageId $script:pkgId | Out-Null
        Export-PacKitApplicationFragment -Fragment $app -SourceFolder $script:work | Out-Null
        $file = Join-Path $script:work ('.packit\' + $script:appId + '.xml')

        $doc = [xml][System.IO.File]::ReadAllText($file)
        $doc.DocumentElement.Name | Should -BeExactly 'FRAGMENT'        # PacKit ReadAppFragment expects <FRAGMENT>
        $doc.DocumentElement.Version | Should -BeExactly '23.8'
        @($doc.DocumentElement.SelectNodes('ITEM')).Count | Should -Be 1  # exactly one bare ITEM
        # AppId must be a CLSIDFromString-parseable braced GUID
        $appIdValue = $doc.DocumentElement.SelectSingleNode('ITEM').GetAttribute('AppId')
        { [guid]::Parse($appIdValue) } | Should -Not -Throw
        # Package path is stored relative (PacKit resolves against the .packit folder)
        $pkgPathValue = $doc.SelectSingleNode("//COLLECTION[@Name='Packages']/ITEM").GetAttribute('Path')
        [System.IO.Path]::IsPathRooted($pkgPathValue) | Should -BeFalse
    }
}
