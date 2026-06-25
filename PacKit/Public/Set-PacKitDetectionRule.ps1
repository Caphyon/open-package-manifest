<#
.SYNOPSIS
  Set the detection-rule fields on a PacKit application fragment (in place).

.DESCRIPTION
  The detection rule tells PacKit/Intune how to detect that the application is
  installed. All fields live as attributes on the app item. Only supplied
  parameters are changed. Use -PassThru to emit the fragment for chaining.

.EXAMPLE
  Set-PacKitDetectionRule -Fragment $app -Type 'MSI' -MsiValue '{PRODUCT-CODE}'

.EXAMPLE
  Set-PacKitDetectionRule -Fragment $app -Type 'File' -FilePath 'C:\Program Files\Acme' -FileName 'acme.exe'
#>
function Set-PacKitDetectionRule {
    [CmdletBinding()]
    [OutputType('PacKit.ApplicationFragment')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $Fragment,

        [Parameter()] [string] $Format,
        [Parameter()] [string] $Type,
        [Parameter()] [string] $MsiValue,
        [Parameter()] [string] $ScriptPath,
        [Parameter()] [string] $FilePath,
        [Parameter()] [string] $FileName,
        [Parameter()] [string] $RegKey,
        [Parameter()] [string] $RegValue,
        [Parameter()] [string] $FileDetectionType,
        [Parameter()] [string] $FileOperator,
        [Parameter()] [string] $FileValue,
        [Parameter()] [string] $RegDetectionType,
        [Parameter()] [string] $RegOperator,
        [Parameter()] [string] $RegDetectionValue,

        [Parameter()] [switch] $PassThru
    )

    process {
        foreach ($prop in @('Format', 'Type', 'MsiValue', 'ScriptPath', 'FilePath', 'FileName',
                'RegKey', 'RegValue', 'FileDetectionType', 'FileOperator', 'FileValue',
                'RegDetectionType', 'RegOperator', 'RegDetectionValue')) {
            if ($PSBoundParameters.ContainsKey($prop)) {
                $Fragment.DetectionRule.$prop = $PSBoundParameters[$prop]
            }
        }

        if ($PassThru) { return $Fragment }
    }
}
