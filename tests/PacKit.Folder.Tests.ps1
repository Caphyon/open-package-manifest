<#
  Tests for Initialize-PacKitFolder and the relative/absolute path helpers.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'PacKit\PacKit.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module PacKit -Force -ErrorAction SilentlyContinue
}

Describe 'Initialize-PacKitFolder' {

    BeforeEach {
        $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ("packit-init-{0}" -f ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path $script:work -Force | Out-Null
    }

    AfterEach {
        Remove-Item -LiteralPath $script:work -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'creates .packit and the seven managed subfolders' {
        $packit = Initialize-PacKitFolder -SourceFolder $script:work
        $packit | Should -BeExactly (Join-Path $script:work '.packit')
        Test-Path -LiteralPath $packit | Should -BeTrue
        foreach ($sub in @('icons', 'detection-scripts', 'psadt', 'intunewin', 'mecm', 'downloads', 'temp')) {
            Test-Path -LiteralPath (Join-Path $packit $sub) | Should -BeTrue
        }
    }

    It 'is idempotent on a second run' {
        Initialize-PacKitFolder -SourceFolder $script:work | Out-Null
        { Initialize-PacKitFolder -SourceFolder $script:work } | Should -Not -Throw
        Test-Path -LiteralPath (Join-Path $script:work '.packit\icons') | Should -BeTrue
    }

    It 'creates nothing under -WhatIf' {
        Initialize-PacKitFolder -SourceFolder $script:work -WhatIf | Out-Null
        Test-Path -LiteralPath (Join-Path $script:work '.packit') | Should -BeFalse
    }

    It 'accepts the source folder from the pipeline' {
        $script:work | Initialize-PacKitFolder | Out-Null
        Test-Path -LiteralPath (Join-Path $script:work '.packit') | Should -BeTrue
    }
}

Describe 'Get-PacKitRelativePath / Get-PacKitAbsolutePath' {

    It 'relativises a sibling path against the .packit folder' {
        $rel = InModuleScope PacKit {
            Get-PacKitRelativePath -BaseDirectory 'C:\src\Acme\.packit' -Path 'C:\src\Acme\app.msi'
        }
        $rel | Should -BeExactly '..\app.msi'
    }

    It 'relativises a nested resource path' {
        $rel = InModuleScope PacKit {
            Get-PacKitRelativePath -BaseDirectory 'C:\src\Acme\.packit' -Path 'C:\src\Acme\.packit\icons\app.png'
        }
        $rel | Should -BeExactly 'icons\app.png'
    }

    It 'leaves an already-relative path untouched' {
        $rel = InModuleScope PacKit {
            Get-PacKitRelativePath -BaseDirectory 'C:\src\Acme\.packit' -Path 'icons\app.png'
        }
        $rel | Should -BeExactly 'icons\app.png'
    }

    It 'resolves a relative path back to absolute' {
        $abs = InModuleScope PacKit {
            Get-PacKitAbsolutePath -BaseDirectory 'C:\src\Acme\.packit' -Path '..\app.msi'
        }
        $abs | Should -BeExactly 'C:\src\Acme\app.msi'
    }

    It 'keeps a different-drive path absolute (no corruption)' {
        $rel = InModuleScope PacKit {
            Get-PacKitRelativePath -BaseDirectory 'C:\src\Acme\.packit' -Path 'D:\installers\app.msi'
        }
        $rel | Should -BeExactly 'D:\installers\app.msi'
    }

    It 'relativises a same-host UNC sibling path' {
        $rel = InModuleScope PacKit {
            Get-PacKitRelativePath -BaseDirectory '\\srv1\share\app\.packit' -Path '\\srv1\share\app\file.msi'
        }
        $rel | Should -BeExactly '..\file.msi'
    }

    It 'keeps a cross-host UNC path absolute (no file:\\ corruption)' {
        $rel = InModuleScope PacKit {
            Get-PacKitRelativePath -BaseDirectory '\\srv1\share\app\.packit' -Path '\\srv2\share\app\file.msi'
        }
        $rel | Should -BeExactly '\\srv2\share\app\file.msi'
    }

    It 'returns "." when the target is the base .packit folder itself (matches C++ ToRelative)' {
        $rel = InModuleScope PacKit {
            Get-PacKitRelativePath -BaseDirectory 'C:\src\Acme\.packit' -Path 'C:\src\Acme\.packit'
        }
        $rel | Should -BeExactly '.'
    }
}
