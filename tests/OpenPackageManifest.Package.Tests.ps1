<#
  Tests for Add/Set/Remove-OpmPackage and Add-OpmWinGetScanResult.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'OpenPackageManifest\OpenPackageManifest.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module OpenPackageManifest -Force -ErrorAction SilentlyContinue
}

Describe 'Add-OpmPackage' {

    It 'appends a package and derives Type from the path extension (case-insensitive)' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Add-OpmPackage -Fragment $app -Path 'installers\app.MSI' | Out-Null
        $app.Packages.Count | Should -Be 1
        $app.Packages[0].Type | Should -BeExactly 'msi'
        $app.Packages[0].Path | Should -BeExactly 'installers\app.MSI'
    }

    It 'derives ps1 for a PSADT deploy script' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $pkg = Add-OpmPackage -Fragment $app -Path 'Deploy-Application.ps1' -PassThru
        $pkg.Type | Should -BeExactly 'ps1'
    }

    It 'honours an explicit -Type override' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $pkg = Add-OpmPackage -Fragment $app -Path 'setup.bin' -Type 'exe' -PassThru
        $pkg.Type | Should -BeExactly 'exe'
    }

    It 'assigns a braced UPPERCASE PackageId by default' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $pkg = Add-OpmPackage -Fragment $app -Path 'app.msi' -PassThru
        $pkg.PackageId | Should -MatchExactly '^\{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\}$'
    }

    It 'normalises a supplied PackageId' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $pkg = Add-OpmPackage -Fragment $app -Path 'app.msi' -PackageId '1b2c3d4e-5f60-7182-93a4-b5c6d7e8f900' -PassThru
        $pkg.PackageId | Should -BeExactly '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}'
    }

    It 'returns nothing without -PassThru' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        (Add-OpmPackage -Fragment $app -Path 'app.msi') | Should -BeNullOrEmpty
    }

    It 'preserves order when adding multiple packages' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Add-OpmPackage -Fragment $app -Path 'a.msi' -PackageId '{AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA}' | Out-Null
        Add-OpmPackage -Fragment $app -Path 'b.exe' -PackageId '{BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB}' | Out-Null
        $app.Packages[0].PackageId | Should -BeExactly '{AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA}'
        $app.Packages[1].PackageId | Should -BeExactly '{BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB}'
    }
}

Describe 'Set-OpmPackage' {

    It 'updates fields of an existing package by PackageId' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $pkg = Add-OpmPackage -Fragment $app -Path 'app.msi' -PassThru
        Set-OpmPackage -Fragment $app -PackageId $pkg.PackageId -Version '2.0.0' -InstallCmdLine '/quiet'
        $app.Packages[0].Version | Should -BeExactly '2.0.0'
        $app.Packages[0].InstallCmdLine | Should -BeExactly '/quiet'
    }

    It 're-derives Type when Path changes and Type is not supplied' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $pkg = Add-OpmPackage -Fragment $app -Path 'app.msi' -PassThru
        Set-OpmPackage -Fragment $app -PackageId $pkg.PackageId -Path 'app.exe'
        $app.Packages[0].Type | Should -BeExactly 'exe'
    }

    It 'throws for an unknown PackageId' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        { Set-OpmPackage -Fragment $app -PackageId '{00000000-0000-0000-0000-000000000000}' -Version '1' } | Should -Throw
    }

    It 'finds the package when given a lowercase/unbraced PackageId' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Add-OpmPackage -Fragment $app -Path 'app.msi' -PackageId '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}' | Out-Null
        Set-OpmPackage -Fragment $app -PackageId '1b2c3d4e-5f60-7182-93a4-b5c6d7e8f900' -Version '3.0.0'
        $app.Packages[0].Version | Should -BeExactly '3.0.0'
    }
}

Describe 'Remove-OpmPackage' {

    It 'removes the package with the matching PackageId' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $a = Add-OpmPackage -Fragment $app -Path 'a.msi' -PassThru
        Add-OpmPackage -Fragment $app -Path 'b.exe' | Out-Null
        Remove-OpmPackage -Fragment $app -PackageId $a.PackageId
        $app.Packages.Count | Should -Be 1
        $app.Packages[0].Path | Should -BeExactly 'b.exe'
    }

    It 'removes when given a lowercase/unbraced PackageId' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Add-OpmPackage -Fragment $app -Path 'a.msi' -PackageId '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}' | Out-Null
        Remove-OpmPackage -Fragment $app -PackageId '1b2c3d4e-5f60-7182-93a4-b5c6d7e8f900'
        $app.Packages.Count | Should -Be 0
    }
}

Describe 'Add-OpmWinGetScanResult' {

    It 'adds a scan result that serialises the score with six decimals' {
        $work = Join-Path ([System.IO.Path]::GetTempPath()) ("opm-scan-{0}" -f ([guid]::NewGuid()))
        try {
            $app = New-OpmApplicationFragment -Name 'Acme'
            $pkg = Add-OpmPackage -Fragment $app -Path 'app.msi' -PassThru
            Add-OpmWinGetScanResult -Fragment $app -PackageId $pkg.PackageId -CatalogPackageId 'Acme.Reader' -MatchScore 0.95 -Vendor 'Acme' | Out-Null
            $app.Packages[0].WinGetScanResults.Count | Should -Be 1
            $file = Join-Path $work 'app.xml'
            Export-OpmApplicationFragment -Fragment $app -LiteralPath $file | Out-Null
            $text = [System.IO.File]::ReadAllText($file)
            $text | Should -Match ([regex]::Escape('WinGetMatchScore="0.950000"'))
            $text | Should -Match ([regex]::Escape('WinGetCatalogPackageId="Acme.Reader"'))
        }
        finally {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws for an unknown PackageId' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        { Add-OpmWinGetScanResult -Fragment $app -PackageId '{00000000-0000-0000-0000-000000000000}' -CatalogPackageId 'x' } | Should -Throw
    }
}
