<#
  Tests for Export-PacKitApplicationFragment - writes a byte-faithful fragment
  to a .packit folder or a literal path, with ShouldProcess support.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'PacKit\PacKit.psd1'
    Import-Module $modulePath -Force
    . (Join-Path $PSScriptRoot '_CanonicalFragment.ps1')

    $script:goldenFragmentBytes = [System.IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'fixtures\golden-fragment.xml'))
}

AfterAll {
    Remove-Module PacKit -Force -ErrorAction SilentlyContinue
}

Describe 'Export-PacKitApplicationFragment' {

    BeforeEach {
        $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ("packit-exp-{0}" -f ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path $script:work -Force | Out-Null
    }

    AfterEach {
        Remove-Item -LiteralPath $script:work -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'writes the fragment to .packit\{AppId}.xml under -SourceFolder' {
        $app = New-PacKitApplicationFragment -Name 'Acme' -AppId '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
        $written = Export-PacKitApplicationFragment -Fragment $app -SourceFolder $script:work
        $expected = Join-Path $script:work '.packit\{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}.xml'
        $written | Should -BeExactly $expected
        Test-Path -LiteralPath $expected | Should -BeTrue
    }

    It 'accepts the fragment from the pipeline' {
        $expected = Join-Path $script:work '.packit\{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}.xml'
        New-PacKitApplicationFragment -Name 'Acme' -AppId '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}' |
            Export-PacKitApplicationFragment -SourceFolder $script:work | Out-Null
        Test-Path -LiteralPath $expected | Should -BeTrue
    }

    It 'produces bytes identical to golden-fragment.xml for the canonical sample' {
        $app = New-CanonicalPacKitFragment
        $file = Join-Path $script:work 'canonical.xml'
        Export-PacKitApplicationFragment -Fragment $app -LiteralPath $file | Out-Null
        $bytes = [System.IO.File]::ReadAllBytes($file)
        ($bytes -join ',') | Should -BeExactly ($script:goldenFragmentBytes -join ',')
    }

    It 'writes exactly the -LiteralPath file' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        $file = Join-Path $script:work 'custom-name.xml'
        $written = Export-PacKitApplicationFragment -Fragment $app -LiteralPath $file
        $written | Should -BeExactly ([System.IO.Path]::GetFullPath($file))
        Test-Path -LiteralPath $file | Should -BeTrue
    }

    It 'supports -WhatIf without writing a file' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        $file = Join-Path $script:work 'whatif.xml'
        Export-PacKitApplicationFragment -Fragment $app -LiteralPath $file -WhatIf | Out-Null
        Test-Path -LiteralPath $file | Should -BeFalse
    }

    It 'returns the fragment with -PassThru' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        $result = Export-PacKitApplicationFragment -Fragment $app -SourceFolder $script:work -PassThru
        $result.PSObject.TypeNames[0] | Should -BeExactly 'PacKit.ApplicationFragment'
        $result.AppId | Should -BeExactly $app.AppId
    }

    It 'throws when the fragment Name is empty' {
        $app = New-PacKitApplicationFragment -Name 'placeholder'
        $app.Name = ''
        { Export-PacKitApplicationFragment -Fragment $app -SourceFolder $script:work } | Should -Throw
    }

    It 'throws when the fragment AppId is not a valid PacKit GUID' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        $app.AppId = 'not-a-guid'
        { Export-PacKitApplicationFragment -Fragment $app -SourceFolder $script:work } | Should -Throw
    }

    It 'rewrites an absolute package Path relative to .packit with -RelativizePaths' {
        $abs = Join-Path $script:work 'installers\app.msi'
        $app = New-PacKitApplicationFragment -Name 'Acme' -AppId '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
        $pkg = InModuleScope PacKit -Parameters @{ p = $abs } {
            param($p)
            $o = New-PacKitPackageObject
            $o.PackageId = '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}'
            $o.Path = $p
            $o.Type = 'msi'
            $o
        }
        $app.Packages = @($pkg)
        Export-PacKitApplicationFragment -Fragment $app -SourceFolder $script:work -RelativizePaths | Out-Null
        $reloaded = Import-PacKitApplicationFragment -SourceFolder $script:work
        # .packit is <work>\.packit ; installer is <work>\installers\app.msi ; relative = ..\installers\app.msi
        $reloaded.Packages[0].Path | Should -BeExactly '..\installers\app.msi'
    }

    It 'does not mutate the caller fragment when -RelativizePaths is used' {
        $abs = Join-Path $script:work 'installers\app.msi'
        $app = New-PacKitApplicationFragment -Name 'Acme'
        $pkg = InModuleScope PacKit -Parameters @{ p = $abs } {
            param($p)
            $o = New-PacKitPackageObject
            $o.PackageId = '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}'
            $o.Path = $p
            $o.Type = 'msi'
            $o
        }
        $app.Packages = @($pkg)
        Export-PacKitApplicationFragment -Fragment $app -SourceFolder $script:work -RelativizePaths | Out-Null
        $app.Packages[0].Path | Should -BeExactly $abs
    }
}
