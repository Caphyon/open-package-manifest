<#
  PSScriptAnalyzer settings for the PacKit PowerShell module.

  The runtime module (PacKit\Public, PacKit\Private) is expected to be entirely
  clean. A few default rules are excluded repo-wide with justification:

  - PSUseShouldProcessForStateChangingFunctions
      The Add-/Set-/Remove-/New-PacKit* cmdlets mutate an in-memory fragment
      object, NOT system/persistent state, so ShouldProcess is not appropriate.
      The cmdlets that DO touch the file system (Export-PacKitApplicationFragment,
      Initialize-PacKitFolder) implement SupportsShouldProcess explicitly.

  - PSAvoidUsingWriteHost
      The build script, test runner and example use Write-Host for user-facing
      console output (not pipeline data); the shipped module never uses it.

  - PSUseSingularNouns
      Only fires on the private helpers Write-PacKitBytes and
      Get-PacKitItemAttributes, whose nouns are legitimately plural. Every
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
