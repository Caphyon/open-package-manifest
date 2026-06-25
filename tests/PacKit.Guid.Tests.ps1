<#
  Tests for New-PacKitGuid.ps1 / Test-PacKitGuid - locks the braced UPPERCASE
  GUID format PacKit validates via CLSIDFromString.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'PacKit\PacKit.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module PacKit -Force -ErrorAction SilentlyContinue
}

Describe 'New-PacKitGuid' {

    It 'produces a braced UPPERCASE 38-character GUID' {
        $g = InModuleScope PacKit { New-PacKitGuid }
        $g.Length | Should -Be 38
        $g | Should -MatchExactly '^\{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\}$'
    }

    It 'produces unique values' {
        $a = InModuleScope PacKit { New-PacKitGuid }
        $b = InModuleScope PacKit { New-PacKitGuid }
        $a | Should -Not -Be $b
    }

    It 'round-trips through .NET Guid parsing' {
        $g = InModuleScope PacKit { New-PacKitGuid }
        { [guid]::Parse($g) } | Should -Not -Throw
    }
}

Describe 'Test-PacKitGuid' {

    It 'accepts a generated GUID' {
        $ok = InModuleScope PacKit { Test-PacKitGuid -Value (New-PacKitGuid) }
        $ok | Should -BeTrue
    }

    It 'accepts a known braced UPPERCASE GUID' {
        (InModuleScope PacKit { Test-PacKitGuid -Value '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}' }) | Should -BeTrue
    }

    It 'rejects lowercase' {
        (InModuleScope PacKit { Test-PacKitGuid -Value '{0a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d}' }) | Should -BeFalse
    }

    It 'rejects an unbraced GUID' {
        (InModuleScope PacKit { Test-PacKitGuid -Value '0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D' }) | Should -BeFalse
    }

    It 'rejects empty and malformed input' {
        (InModuleScope PacKit { Test-PacKitGuid -Value '' }) | Should -BeFalse
        (InModuleScope PacKit { Test-PacKitGuid -Value 'not-a-guid' }) | Should -BeFalse
        (InModuleScope PacKit { Test-PacKitGuid -Value '{123}' }) | Should -BeFalse
    }
}
