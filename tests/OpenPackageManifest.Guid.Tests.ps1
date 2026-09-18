<#
  Tests for New-OpmGuid.ps1 / Test-OpmGuid - locks the braced UPPERCASE
  GUID format PacKit validates via CLSIDFromString.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'OpenPackageManifest\OpenPackageManifest.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module OpenPackageManifest -Force -ErrorAction SilentlyContinue
}

Describe 'New-OpmGuid' {

    It 'produces a braced UPPERCASE 38-character GUID' {
        $g = InModuleScope OpenPackageManifest { New-OpmGuid }
        $g.Length | Should -Be 38
        $g | Should -MatchExactly '^\{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\}$'
    }

    It 'produces unique values' {
        $a = InModuleScope OpenPackageManifest { New-OpmGuid }
        $b = InModuleScope OpenPackageManifest { New-OpmGuid }
        $a | Should -Not -Be $b
    }

    It 'round-trips through .NET Guid parsing' {
        $g = InModuleScope OpenPackageManifest { New-OpmGuid }
        { [guid]::Parse($g) } | Should -Not -Throw
    }
}

Describe 'Test-OpmGuid' {

    It 'accepts a generated GUID' {
        $ok = InModuleScope OpenPackageManifest { Test-OpmGuid -Value (New-OpmGuid) }
        $ok | Should -BeTrue
    }

    It 'accepts a known braced UPPERCASE GUID' {
        (InModuleScope OpenPackageManifest { Test-OpmGuid -Value '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}' }) | Should -BeTrue
    }

    It 'rejects lowercase' {
        (InModuleScope OpenPackageManifest { Test-OpmGuid -Value '{0a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d}' }) | Should -BeFalse
    }

    It 'rejects an unbraced GUID' {
        (InModuleScope OpenPackageManifest { Test-OpmGuid -Value '0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D' }) | Should -BeFalse
    }

    It 'rejects empty and malformed input' {
        (InModuleScope OpenPackageManifest { Test-OpmGuid -Value '' }) | Should -BeFalse
        (InModuleScope OpenPackageManifest { Test-OpmGuid -Value 'not-a-guid' }) | Should -BeFalse
        (InModuleScope OpenPackageManifest { Test-OpmGuid -Value '{123}' }) | Should -BeFalse
    }
}
