@{
    RootModule           = 'OpenPackageManifest.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'a9b076ba-a6b6-4fa2-9fe9-9e3d11440757'
    Author               = 'Caphyon'
    CompanyName          = 'Caphyon'
    Copyright            = '(c) Caphyon. All rights reserved.'
    Description          = 'Authoring utilities for PacKit application fragments and the .opm metadata folder. Create, load, modify and save the per-application XML that the PacKit app consumes. Designed for CI/CD pipelines.'

    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    # Explicit public surface (13 cmdlets). Files are auto-discovered by OpenPackageManifest.psm1;
    # this list is the authoritative export filter.
    FunctionsToExport    = @(
        'New-OpmApplicationFragment'
        'Import-OpmApplicationFragment'
        'Export-OpmApplicationFragment'
        'Set-OpmApplication'
        'Set-OpmDetectionRule'
        'Add-OpmPackage'
        'Set-OpmPackage'
        'Remove-OpmPackage'
        'Add-OpmWinGetScanResult'
        'Add-OpmAssignment'
        'Remove-OpmAssignment'
        'Initialize-OpmFolder'
        'Test-OpmApplicationFragment'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @('OpenPackageManifest', 'Deployment', 'Intune', 'CICD', 'XML', 'Packaging')
            ProjectUri   = 'https://www.getpackit.com/'
            LicenseUri   = 'https://www.getpackit.com/eula/'
            ReleaseNotes = 'Initial release. See CHANGELOG.md for details.'
        }
    }
}
