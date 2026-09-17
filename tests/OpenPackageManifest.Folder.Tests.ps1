<#
  Tests for Initialize-OpmFolder and the relative/absolute path helpers.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'OpenPackageManifest\OpenPackageManifest.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module OpenPackageManifest -Force -ErrorAction SilentlyContinue
}

Describe 'Initialize-OpmFolder' {

    BeforeEach {
        $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ("opm-init-{0}" -f ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path $script:work -Force | Out-Null
    }

    AfterEach {
        Remove-Item -LiteralPath $script:work -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'creates .opm and the seven managed subfolders' {
        $opmFolder = Initialize-OpmFolder -SourceFolder $script:work
        $opmFolder | Should -BeExactly (Join-Path $script:work '.opm')
        Test-Path -LiteralPath $opmFolder | Should -BeTrue
        foreach ($sub in @('icons', 'detection-scripts', 'psadt', 'intunewin', 'mecm', 'downloads', 'temp')) {
            Test-Path -LiteralPath (Join-Path $opmFolder $sub) | Should -BeTrue
        }
    }

    It 'is idempotent on a second run' {
        Initialize-OpmFolder -SourceFolder $script:work | Out-Null
        { Initialize-OpmFolder -SourceFolder $script:work } | Should -Not -Throw
        Test-Path -LiteralPath (Join-Path $script:work '.opm\icons') | Should -BeTrue
    }

    It 'creates nothing under -WhatIf' {
        Initialize-OpmFolder -SourceFolder $script:work -WhatIf | Out-Null
        Test-Path -LiteralPath (Join-Path $script:work '.opm') | Should -BeFalse
    }

    It 'accepts the source folder from the pipeline' {
        $script:work | Initialize-OpmFolder | Out-Null
        Test-Path -LiteralPath (Join-Path $script:work '.opm') | Should -BeTrue
    }
}

Describe 'Get-OpmRelativePath / Get-OpmAbsolutePath' {

    It 'relativises a sibling path against the .opm folder' {
        $rel = InModuleScope OpenPackageManifest {
            Get-OpmRelativePath -BaseDirectory 'C:\src\Acme\.opm' -Path 'C:\src\Acme\app.msi'
        }
        $rel | Should -BeExactly '..\app.msi'
    }

    It 'relativises a nested resource path' {
        $rel = InModuleScope OpenPackageManifest {
            Get-OpmRelativePath -BaseDirectory 'C:\src\Acme\.opm' -Path 'C:\src\Acme\.opm\icons\app.png'
        }
        $rel | Should -BeExactly 'icons\app.png'
    }

    It 'leaves an already-relative path untouched' {
        $rel = InModuleScope OpenPackageManifest {
            Get-OpmRelativePath -BaseDirectory 'C:\src\Acme\.opm' -Path 'icons\app.png'
        }
        $rel | Should -BeExactly 'icons\app.png'
    }

    It 'resolves a relative path back to absolute' {
        $abs = InModuleScope OpenPackageManifest {
            Get-OpmAbsolutePath -BaseDirectory 'C:\src\Acme\.opm' -Path '..\app.msi'
        }
        $abs | Should -BeExactly 'C:\src\Acme\app.msi'
    }

    It 'keeps a different-drive path absolute (no corruption)' {
        $rel = InModuleScope OpenPackageManifest {
            Get-OpmRelativePath -BaseDirectory 'C:\src\Acme\.opm' -Path 'D:\installers\app.msi'
        }
        $rel | Should -BeExactly 'D:\installers\app.msi'
    }

    It 'relativises a same-host UNC sibling path' {
        $rel = InModuleScope OpenPackageManifest {
            Get-OpmRelativePath -BaseDirectory '\\srv1\share\app\.opm' -Path '\\srv1\share\app\file.msi'
        }
        $rel | Should -BeExactly '..\file.msi'
    }

    It 'keeps a cross-host UNC path absolute (no file:\\ corruption)' {
        $rel = InModuleScope OpenPackageManifest {
            Get-OpmRelativePath -BaseDirectory '\\srv1\share\app\.opm' -Path '\\srv2\share\app\file.msi'
        }
        $rel | Should -BeExactly '\\srv2\share\app\file.msi'
    }

    It 'returns "." when the target is the base .opm folder itself (matches C++ ToRelative)' {
        $rel = InModuleScope OpenPackageManifest {
            Get-OpmRelativePath -BaseDirectory 'C:\src\Acme\.opm' -Path 'C:\src\Acme\.opm'
        }
        $rel | Should -BeExactly '.'
    }
}
