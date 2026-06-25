<#
  Tests for Add/Set/Remove-PacKitPackage and Add-PacKitWinGetScanResult.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'PacKit\PacKit.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module PacKit -Force -ErrorAction SilentlyContinue
}

Describe 'Add-PacKitPackage' {

    It 'appends a package and derives Type from the path extension (case-insensitive)' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        Add-PacKitPackage -Fragment $app -Path 'installers\app.MSI' | Out-Null
        $app.Packages.Count | Should -Be 1
        $app.Packages[0].Type | Should -BeExactly 'msi'
        $app.Packages[0].Path | Should -BeExactly 'installers\app.MSI'
    }

    It 'derives ps1 for a PSADT deploy script' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        $pkg = Add-PacKitPackage -Fragment $app -Path 'Deploy-Application.ps1' -PassThru
        $pkg.Type | Should -BeExactly 'ps1'
    }

    It 'honours an explicit -Type override' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        $pkg = Add-PacKitPackage -Fragment $app -Path 'setup.bin' -Type 'exe' -PassThru
        $pkg.Type | Should -BeExactly 'exe'
    }

    It 'assigns a braced UPPERCASE PackageId by default' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        $pkg = Add-PacKitPackage -Fragment $app -Path 'app.msi' -PassThru
        $pkg.PackageId | Should -MatchExactly '^\{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\}$'
    }

    It 'normalises a supplied PackageId' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        $pkg = Add-PacKitPackage -Fragment $app -Path 'app.msi' -PackageId '1b2c3d4e-5f60-7182-93a4-b5c6d7e8f900' -PassThru
        $pkg.PackageId | Should -BeExactly '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}'
    }

    It 'returns nothing without -PassThru' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        (Add-PacKitPackage -Fragment $app -Path 'app.msi') | Should -BeNullOrEmpty
    }

    It 'preserves order when adding multiple packages' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        Add-PacKitPackage -Fragment $app -Path 'a.msi' -PackageId '{AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA}' | Out-Null
        Add-PacKitPackage -Fragment $app -Path 'b.exe' -PackageId '{BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB}' | Out-Null
        $app.Packages[0].PackageId | Should -BeExactly '{AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA}'
        $app.Packages[1].PackageId | Should -BeExactly '{BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB}'
    }
}

Describe 'Set-PacKitPackage' {

    It 'updates fields of an existing package by PackageId' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        $pkg = Add-PacKitPackage -Fragment $app -Path 'app.msi' -PassThru
        Set-PacKitPackage -Fragment $app -PackageId $pkg.PackageId -Version '2.0.0' -InstallCmdLine '/quiet'
        $app.Packages[0].Version | Should -BeExactly '2.0.0'
        $app.Packages[0].InstallCmdLine | Should -BeExactly '/quiet'
    }

    It 're-derives Type when Path changes and Type is not supplied' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        $pkg = Add-PacKitPackage -Fragment $app -Path 'app.msi' -PassThru
        Set-PacKitPackage -Fragment $app -PackageId $pkg.PackageId -Path 'app.exe'
        $app.Packages[0].Type | Should -BeExactly 'exe'
    }

    It 'throws for an unknown PackageId' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        { Set-PacKitPackage -Fragment $app -PackageId '{00000000-0000-0000-0000-000000000000}' -Version '1' } | Should -Throw
    }

    It 'finds the package when given a lowercase/unbraced PackageId' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        Add-PacKitPackage -Fragment $app -Path 'app.msi' -PackageId '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}' | Out-Null
        Set-PacKitPackage -Fragment $app -PackageId '1b2c3d4e-5f60-7182-93a4-b5c6d7e8f900' -Version '3.0.0'
        $app.Packages[0].Version | Should -BeExactly '3.0.0'
    }
}

Describe 'Remove-PacKitPackage' {

    It 'removes the package with the matching PackageId' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        $a = Add-PacKitPackage -Fragment $app -Path 'a.msi' -PassThru
        Add-PacKitPackage -Fragment $app -Path 'b.exe' | Out-Null
        Remove-PacKitPackage -Fragment $app -PackageId $a.PackageId
        $app.Packages.Count | Should -Be 1
        $app.Packages[0].Path | Should -BeExactly 'b.exe'
    }

    It 'removes when given a lowercase/unbraced PackageId' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        Add-PacKitPackage -Fragment $app -Path 'a.msi' -PackageId '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}' | Out-Null
        Remove-PacKitPackage -Fragment $app -PackageId '1b2c3d4e-5f60-7182-93a4-b5c6d7e8f900'
        $app.Packages.Count | Should -Be 0
    }
}

Describe 'Add-PacKitWinGetScanResult' {

    It 'adds a scan result that serialises the score with six decimals' {
        $work = Join-Path ([System.IO.Path]::GetTempPath()) ("packit-scan-{0}" -f ([guid]::NewGuid()))
        try {
            $app = New-PacKitApplicationFragment -Name 'Acme'
            $pkg = Add-PacKitPackage -Fragment $app -Path 'app.msi' -PassThru
            Add-PacKitWinGetScanResult -Fragment $app -PackageId $pkg.PackageId -CatalogPackageId 'Acme.Reader' -MatchScore 0.95 -Vendor 'Acme' | Out-Null
            $app.Packages[0].WinGetScanResults.Count | Should -Be 1
            $file = Join-Path $work 'app.xml'
            Export-PacKitApplicationFragment -Fragment $app -LiteralPath $file | Out-Null
            $text = [System.IO.File]::ReadAllText($file)
            $text | Should -Match ([regex]::Escape('WinGetMatchScore="0.950000"'))
            $text | Should -Match ([regex]::Escape('WinGetCatalogPackageId="Acme.Reader"'))
        }
        finally {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws for an unknown PackageId' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        { Add-PacKitWinGetScanResult -Fragment $app -PackageId '{00000000-0000-0000-0000-000000000000}' -CatalogPackageId 'x' } | Should -Throw
    }
}
