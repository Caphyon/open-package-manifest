<#
  PSScriptAnalyzer settings for the OpenPackageManifest PowerShell module.

  The runtime module (OpenPackageManifest\Public, OpenPackageManifest\Private) is expected to be entirely
  clean. A few default rules are excluded repo-wide with justification:

  - PSUseShouldProcessForStateChangingFunctions
      The Add-/Set-/Remove-/New-Opm* cmdlets mutate an in-memory fragment
      object, NOT system/persistent state, so ShouldProcess is not appropriate.
      The cmdlets that DO touch the file system (Export-OpmApplicationFragment,
      Initialize-OpmFolder) implement SupportsShouldProcess explicitly.

  - PSAvoidUsingWriteHost
      The build script, test runner and example use Write-Host for user-facing
      console output (not pipeline data); the shipped module never uses it.

  - PSUseSingularNouns
      Only fires on the private helpers Write-OpmBytes and
      Get-OpmItemAttributes, whose nouns are legitimately plural. Every
      EXPORTED cmdlet already uses a singular noun.
#>
@{
    IncludeDefaultRules = $true
    Severity            = @('Error', 'Warning')
    ExcludeRules        = @(
        'PSUseShouldProcessForStateChangingFunctions'
        'PSAvoidUsingWriteHost'
        'PSUseSingularNouns'
    )
}
