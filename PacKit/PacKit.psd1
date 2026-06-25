@{
    RootModule           = 'PacKit.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'a9b076ba-a6b6-4fa2-9fe9-9e3d11440757'
    Author               = 'Caphyon'
    CompanyName          = 'Caphyon'
    Copyright            = '(c) Caphyon. All rights reserved.'
    Description          = 'Authoring utilities for PacKit application fragments and the .packit metadata folder. Create, load, modify and save the per-application XML that the PacKit app consumes. Designed for CI/CD pipelines.'

    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    # Explicit public surface (13 cmdlets). Files are auto-discovered by PacKit.psm1;
    # this list is the authoritative export filter.
    FunctionsToExport    = @(
        'New-PacKitApplicationFragment'
        'Import-PacKitApplicationFragment'
        'Export-PacKitApplicationFragment'
        'Set-PacKitApplication'
        'Set-PacKitDetectionRule'
        'Add-PacKitPackage'
        'Set-PacKitPackage'
        'Remove-PacKitPackage'
        'Add-PacKitWinGetScanResult'
        'Add-PacKitAssignment'
        'Remove-PacKitAssignment'
        'Initialize-PacKitFolder'
        'Test-PacKitApplicationFragment'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @('PacKit', 'Deployment', 'Intune', 'CICD', 'XML', 'Packaging')
            ProjectUri   = 'https://www.getpackit.com/'
            LicenseUri   = 'https://www.getpackit.com/eula/'
            ReleaseNotes = 'Initial release. See CHANGELOG.md for details.'
        }
    }
}
