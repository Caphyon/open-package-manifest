<#
  Tests for Export-OpmApplicationFragment - writes a byte-faithful fragment
  to a .opm folder or a literal path, with ShouldProcess support.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'OpenPackageManifest\OpenPackageManifest.psd1'
    Import-Module $modulePath -Force
    . (Join-Path $PSScriptRoot '_CanonicalFragment.ps1')

    $script:goldenFragmentBytes = [System.IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'fixtures\golden-fragment.xml'))
}

AfterAll {
    Remove-Module OpenPackageManifest -Force -ErrorAction SilentlyContinue
}

Describe 'Export-OpmApplicationFragment' {

    BeforeEach {
        $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ("opm-exp-{0}" -f ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path $script:work -Force | Out-Null
    }

    AfterEach {
        Remove-Item -LiteralPath $script:work -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'writes the fragment to .opm\{AppId}.xml under -SourceFolder' {
        $app = New-OpmApplicationFragment -Name 'Acme' -AppId '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
        $written = Export-OpmApplicationFragment -Fragment $app -SourceFolder $script:work
        $expected = Join-Path $script:work '.opm\{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}.xml'
        $written | Should -BeExactly $expected
        Test-Path -LiteralPath $expected | Should -BeTrue
    }

    It 'accepts the fragment from the pipeline' {
        $expected = Join-Path $script:work '.opm\{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}.xml'
        New-OpmApplicationFragment -Name 'Acme' -AppId '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}' |
            Export-OpmApplicationFragment -SourceFolder $script:work | Out-Null
        Test-Path -LiteralPath $expected | Should -BeTrue
    }

    It 'produces bytes identical to golden-fragment.xml for the canonical sample' {
        $app = New-CanonicalOpmFragment
        $file = Join-Path $script:work 'canonical.xml'
        Export-OpmApplicationFragment -Fragment $app -LiteralPath $file | Out-Null
        $bytes = [System.IO.File]::ReadAllBytes($file)
        ($bytes -join ',') | Should -BeExactly ($script:goldenFragmentBytes -join ',')
    }

    It 'writes exactly the -LiteralPath file' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $file = Join-Path $script:work 'custom-name.xml'
        $written = Export-OpmApplicationFragment -Fragment $app -LiteralPath $file
        $written | Should -BeExactly ([System.IO.Path]::GetFullPath($file))
        Test-Path -LiteralPath $file | Should -BeTrue
    }

    It 'supports -WhatIf without writing a file' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $file = Join-Path $script:work 'whatif.xml'
        Export-OpmApplicationFragment -Fragment $app -LiteralPath $file -WhatIf | Out-Null
        Test-Path -LiteralPath $file | Should -BeFalse
    }

    It 'returns the fragment with -PassThru' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $result = Export-OpmApplicationFragment -Fragment $app -SourceFolder $script:work -PassThru
        $result.PSObject.TypeNames[0] | Should -BeExactly 'PacKit.ApplicationFragment'
        $result.AppId | Should -BeExactly $app.AppId
    }

    It 'throws when the fragment Name is empty' {
        $app = New-OpmApplicationFragment -Name 'placeholder'
        $app.Name = ''
        { Export-OpmApplicationFragment -Fragment $app -SourceFolder $script:work } | Should -Throw
    }

    It 'throws when the fragment AppId is not a valid PacKit GUID' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $app.AppId = 'not-a-guid'
        { Export-OpmApplicationFragment -Fragment $app -SourceFolder $script:work } | Should -Throw
    }

    It 'rewrites an absolute package Path relative to .opm with -RelativizePaths' {
        $abs = Join-Path $script:work 'installers\app.msi'
        $app = New-OpmApplicationFragment -Name 'Acme' -AppId '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
        $pkg = InModuleScope OpenPackageManifest -Parameters @{ p = $abs } {
            param($p)
            $o = New-OpmPackageObject
            $o.PackageId = '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}'
            $o.Path = $p
            $o.Type = 'msi'
            $o
        }
        $app.Packages = @($pkg)
        Export-OpmApplicationFragment -Fragment $app -SourceFolder $script:work -RelativizePaths | Out-Null
        $reloaded = Import-OpmApplicationFragment -SourceFolder $script:work
        # .opm is <work>\.opm ; installer is <work>\installers\app.msi ; relative = ..\installers\app.msi
        $reloaded.Packages[0].Path | Should -BeExactly '..\installers\app.msi'
    }

    It 'does not mutate the caller fragment when -RelativizePaths is used' {
        $abs = Join-Path $script:work 'installers\app.msi'
        $app = New-OpmApplicationFragment -Name 'Acme'
        $pkg = InModuleScope OpenPackageManifest -Parameters @{ p = $abs } {
            param($p)
            $o = New-OpmPackageObject
            $o.PackageId = '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}'
            $o.Path = $p
            $o.Type = 'msi'
            $o
        }
        $app.Packages = @($pkg)
        Export-OpmApplicationFragment -Fragment $app -SourceFolder $script:work -RelativizePaths | Out-Null
        $app.Packages[0].Path | Should -BeExactly $abs
    }
}
