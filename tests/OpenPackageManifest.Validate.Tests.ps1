<#
  Tests for Test-OpmApplicationFragment (validation).
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'OpenPackageManifest\OpenPackageManifest.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module OpenPackageManifest -Force -ErrorAction SilentlyContinue
}

Describe 'Test-OpmApplicationFragment' {

    It 'passes a freshly created fragment' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Test-OpmApplicationFragment -Fragment $app | Should -BeTrue
    }

    It 'fails an empty Name' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $app.Name = ''
        Test-OpmApplicationFragment -Fragment $app | Should -BeFalse
    }

    It 'fails an invalid AppId' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $app.AppId = 'not-a-guid'
        Test-OpmApplicationFragment -Fragment $app | Should -BeFalse
    }

    It 'fails an invalid package PackageId' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Add-OpmPackage -Fragment $app -Path 'app.msi' | Out-Null
        $app.Packages[0].PackageId = 'bad'
        Test-OpmApplicationFragment -Fragment $app | Should -BeFalse
    }

    It 'fails an invalid assignment group id' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Add-OpmAssignment -Fragment $app -MsEntraGroupId '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}' -AssignmentType 'Required' | Out-Null
        $app.IntuneAssignments[0].MsEntraGroupId = 'bad'   # corrupt directly (Add normalises/rejects on input)
        Test-OpmApplicationFragment -Fragment $app | Should -BeFalse
    }

    It 'returns a detailed report with Errors and Warnings' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $app.Name = ''
        Add-OpmPackage -Fragment $app -Path 'setup.bin' -Type 'weirdtype' | Out-Null
        $report = Test-OpmApplicationFragment -Fragment $app -Detailed
        $report.IsValid | Should -BeFalse
        ($report.Errors -join ' ') | Should -Match 'Name is empty'
        ($report.Warnings -join ' ') | Should -Match 'weirdtype'
    }

    It 'does not fail validation for an unrecognised package Type (soft warning only)' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Add-OpmPackage -Fragment $app -Path 'setup.bin' -Type 'weirdtype' | Out-Null
        Test-OpmApplicationFragment -Fragment $app | Should -BeTrue
    }

    It 'fails text containing an XML-invalid control character' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $app.Name = 'Bad' + [char]1 + 'Name'   # SOH (0x01) is not a valid XML 1.0 character
        Test-OpmApplicationFragment -Fragment $app | Should -BeFalse
    }

    It 'allows TAB, CR and LF in text fields' {
        $app = New-OpmApplicationFragment -Name ('Line1' + [char]10 + 'Line2' + [char]9 + 'Tab' + [char]13)
        Test-OpmApplicationFragment -Fragment $app | Should -BeTrue
    }

    It 'flags an XML-invalid control character in a package field via -Detailed' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Add-OpmPackage -Fragment $app -Path 'app.msi' | Out-Null
        $app.Packages[0].InstallCmdLine = 'x' + [char]11 + 'y'   # vertical tab (0x0B) is invalid XML 1.0
        $report = Test-OpmApplicationFragment -Fragment $app -Detailed
        $report.IsValid | Should -BeFalse
        ($report.Errors -join ' ') | Should -Match 'control character'
    }

    It 'fails a lone high surrogate in the Name (Expat would reject &#55296;)' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $app.Name = 'x' + [char]0xD800 + 'y'   # lone high surrogate -> not a valid XML 1.0 character
        Test-OpmApplicationFragment -Fragment $app | Should -BeFalse
    }

    It 'fails a lone low surrogate in a package field' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Add-OpmPackage -Fragment $app -Path 'app.msi' | Out-Null
        $app.Packages[0].InstallCmdLine = 'a' + [char]0xDC00 + 'b'   # lone low surrogate
        Test-OpmApplicationFragment -Fragment $app | Should -BeFalse
    }

    It 'allows a valid surrogate pair (emoji) in text' {
        $emoji = [string]::new([char[]]@([char]0xD83D, [char]0xDE00))   # U+1F600
        $app = New-OpmApplicationFragment -Name ('Acme ' + $emoji)
        Test-OpmApplicationFragment -Fragment $app | Should -BeTrue
    }
}
