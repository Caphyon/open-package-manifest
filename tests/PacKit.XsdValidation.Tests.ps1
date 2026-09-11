<#
  Validates real Export-PacKitApplicationFragment output against
  PacKit\Schema\PackitModuleFragment.xsd, which documents exactly what this
  module can emit. Every fragment here is built through the public cmdlets
  only (New-/Set-/Add-/Export-PacKitApplication*), never through the internal
  object factories, so this is also a smoke test of the public API surface.
#>

BeforeAll {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $repoRoot 'PacKit\PacKit.psd1') -Force
    $script:xsdPath = Join-Path $repoRoot 'PacKit\Schema\PackitModuleFragment.xsd'

    # Validates an on-disk XML file against $script:xsdPath; returns the list of
    # validation messages (empty array = the document is schema-valid).
    function Test-XmlAgainstXsd {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)] [string] $XmlPath,
            [Parameter(Mandatory)] [string] $XsdPath
        )

        $messages = New-Object System.Collections.Generic.List[string]
        $settings = New-Object System.Xml.XmlReaderSettings
        [void]$settings.Schemas.Add($null, $XsdPath)
        $settings.ValidationType = [System.Xml.ValidationType]::Schema
        $settings.add_ValidationEventHandler({ param($s, $e) $messages.Add($e.Message) }.GetNewClosure())

        $reader = [System.Xml.XmlReader]::Create($XmlPath, $settings)
        try {
            while ($reader.Read()) {}
        }
        finally {
            $reader.Close()
        }

        return , $messages.ToArray()
    }
}

AfterAll {
    Remove-Module PacKit -Force -ErrorAction SilentlyContinue
}

Describe 'PacKit fragments vs PackitModuleFragment.xsd' {

    BeforeEach {
        $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ("packit-xsd-{0}" -f ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path $script:work -Force | Out-Null
    }

    AfterEach {
        Remove-Item -LiteralPath $script:work -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'validates a full fragment (app + package + scan result + assignment)' {
        # -- exact commands a caller would run --
        $app = New-PacKitApplicationFragment -Name 'Acme Reader' -Vendor 'Acme Corporation' `
            -Description 'Reads PDFs' -IconPath 'icons\app.png' -OperatingSys 'Windows' -OperatingSysArchitecture 'x64'

        Set-PacKitApplication -Fragment $app -ReturnCodesJson '[0,3010]' -ScopeTagId '1' `
            -WinGetAppScannedAt 1737000000 -Unseen $false

        Set-PacKitDetectionRule -Fragment $app -Format 'Manually configure detection rules' -Type 'MSI' `
            -MsiValue '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'

        $pkg = Add-PacKitPackage -Fragment $app -Path 'app.msi' -InstallCmdLine '/qn' -Version '1.0.0' -PassThru

        Add-PacKitWinGetScanResult -Fragment $app -PackageId $pkg.PackageId `
            -CatalogPackageId 'Acme.Reader' -MatchScore 0.95 -Vendor 'Acme' | Out-Null

        Add-PacKitAssignment -Fragment $app -MsEntraGroupId ([guid]::NewGuid().ToString()) `
            -AssignmentType 'Required' -InclusionType 'Include' | Out-Null

        Test-PacKitApplicationFragment -Fragment $app | Should -BeTrue

        $target = Join-Path $script:work 'full.xml'
        Export-PacKitApplicationFragment -Fragment $app -LiteralPath $target | Out-Null

        $messages = Test-XmlAgainstXsd -XmlPath $target -XsdPath $script:xsdPath
        $messages | Should -BeNullOrEmpty -Because ($messages -join '; ')
    }

    It 'validates a minimal fragment (no packages, no assignments)' {
        $app = New-PacKitApplicationFragment -Name 'Empty'

        $target = Join-Path $script:work 'minimal.xml'
        Export-PacKitApplicationFragment -Fragment $app -LiteralPath $target | Out-Null

        $messages = Test-XmlAgainstXsd -XmlPath $target -XsdPath $script:xsdPath
        $messages | Should -BeNullOrEmpty -Because ($messages -join '; ')
    }

    It 'validates a fragment with multiple packages and zero scan results' {
        $app = New-PacKitApplicationFragment -Name 'Multi Package App'
        Add-PacKitPackage -Fragment $app -Path 'setup.exe' -InstallCmdLine '/silent' | Out-Null
        Add-PacKitPackage -Fragment $app -Path 'Deploy-Application.ps1' | Out-Null

        $target = Join-Path $script:work 'multi.xml'
        Export-PacKitApplicationFragment -Fragment $app -LiteralPath $target | Out-Null

        $messages = Test-XmlAgainstXsd -XmlPath $target -XsdPath $script:xsdPath
        $messages | Should -BeNullOrEmpty -Because ($messages -join '; ')
    }

    It 'rejects a fragment whose AppId is not a braced UPPERCASE GUID' {
        $app = New-PacKitApplicationFragment -Name 'Bad AppId'
        $target = Join-Path $script:work 'bad-appid.xml'
        Export-PacKitApplicationFragment -Fragment $app -LiteralPath $target | Out-Null

        # Corrupt the on-disk AppId the way a hand-edited fragment might.
        (Get-Content -LiteralPath $target -Raw) -replace 'AppId="\{[^}]+\}"', 'AppId="not-a-guid"' |
            Set-Content -LiteralPath $target -NoNewline

        $messages = Test-XmlAgainstXsd -XmlPath $target -XsdPath $script:xsdPath
        $messages | Should -Not -BeNullOrEmpty
    }
}
