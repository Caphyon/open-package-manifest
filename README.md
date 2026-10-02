<img width="548" height="259" alt="OPM_Logo_White" src="https://github.com/user-attachments/assets/44925473-4115-4ec8-9e0b-4ab4e83a2407" />


# Open Package Manifest PowerShell module

The Open Package Manifest can describe a Windows application package independently
of the tool that created it. The  vision is simple. Packaging information 
shouldn't live inside one product. Or spread across multiple ones. It should 
travel with the application itself.

We call a **fragment** the folder standing next to your application where all 
the metadata is stored. You can set your own custom name, for example ".opm".
We used ".packit" because the first application to adopt the OPM standard 
was PacKit.

This module enables to you author, load, modify and save **application fragments**
from the `.packit` metadata folder — the 
open package manifest that [PacKit](https://www.getpackit.com/) can consume. 

It's built for CI/CD: a third party instruments an application with a `.packit` 
folder, and you can later load it in PacKit or into another application 
using with the help of this PowerShell module.

The module produces output that is **byte-identical** to what PacKit itself
writes, so a load → modify → save round-trip is lossless and diffs stay clean.

---
<svg width="548" height="259" viewBox="0 0 548 259" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M61.6382 130.67C61.6382 80.6985 87.3642 54.5539 126.375 54.5539C165.386 54.5539 191.112 80.6985 191.112 130.67C191.112 180.642 165.386 206.785 126.375 206.785C87.3642 206.785 61.6382 180.64 61.6382 130.67ZM157.164 141.634V119.707C157.164 96.3029 145.566 83.0197 126.375 83.0197C107.184 83.0197 95.5862 96.3029 95.5862 119.707V141.634C95.5862 165.038 107.184 178.321 126.375 178.321C145.566 178.321 157.164 165.038 157.164 141.634Z" fill="white"/>
<path d="M212.619 204.257V57.0859H282.207C309.62 57.0859 326.912 76.2727 326.912 104.104C326.912 131.935 309.62 151.122 282.207 151.122H244.671V204.255L212.619 204.257ZM244.671 123.291H278.41C287.899 123.291 293.803 118.231 293.803 108.743V99.4655C293.803 89.9776 287.901 84.9173 278.41 84.9173H244.671V123.291Z" fill="white"/>
<path d="M455.751 107.688H455.118L444.364 129.194L415.685 181.275L387.64 129.405L376.462 106.213H375.831V204.257H345.677V57.0859H379.627L415.687 126.032H416.109L451.746 57.0859H485.909V204.257H455.755V107.688H455.751Z" fill="white"/>
<path d="M538.892 4.88257H507.652V255.421H538.892V4.88257Z" fill="white"/>
<path d="M538.888 224.183H452.326V255.421H538.888V224.183Z" fill="white"/>
<path d="M538.89 4.22858H452.328V35.4666H538.89V4.22858Z" fill="white"/>
<path d="M41.6506 4.22858H10.4107V254.767H41.6506V4.22858Z" fill="white"/>
<path d="M96.9744 4.22858H10.4126V35.4666H96.9744V4.22858Z" fill="white"/>
<path d="M96.9744 224.183H10.4127V255.421H96.9744V224.183Z" fill="white"/>
</svg>

## Requirements

- **Windows PowerShell 5.1** (Desktop) **or PowerShell 7+** (Core).
- No external modules or binaries are required at runtime — it is pure
  PowerShell + .NET. (Building/testing the repo additionally uses
  [Pester 5](https://pester.dev) and
  [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer).)

## Install

From the PowerShell Gallery:

```powershell
Install-Module -Name OpenPackageManifest -Scope CurrentUser
Import-Module OpenPackageManifest
```

Or vendor the self-contained `OpenPackageManifest` folder into your repo / pipeline and import
it by manifest path:

```powershell
Import-Module .\OpenPackageManifest\OpenPackageManifest.psd1
```

(You can also drop the `OpenPackageManifest` folder onto a `$env:PSModulePath` entry and
`Import-Module OpenPackageManifest`. A published release zip — `OpenPackageManifest-<version>.zip` —
extracts to exactly that layout.)

---

## Quick start — instrument an application

```powershell
Import-Module .\OpenPackageManifest\OpenPackageManifest.psd1

# 1. Author the application
$app = New-OpmApplicationFragment -Name 'Acme Reader' -Vendor 'Acme Corporation' `
        -Description 'Reads PDFs' -OperatingSysArchitecture '64-bit'

# 2. Add the installer (Type is derived from the file extension -> 'msi')
Add-OpmPackage -Fragment $app -Path 'app.msi' -InstallCmdLine '/qn' -Version '1.0.0'

# 3. Detection + Intune assignment (optional)
Set-OpmDetectionRule -Fragment $app -Type 'MSI' -MsiValue '{PRODUCT-CODE}'
Add-OpmAssignment   -Fragment $app -MsEntraGroupId '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}' `
                       -AssignmentType 'Required' -InclusionType 'included'

# 4. Validate, create the .packit folder, and save
if (-not (Test-OpmApplicationFragment -Fragment $app)) { throw 'invalid fragment' }
Initialize-OpmFolder -SourceFolder 'C:\src\Acme'
Export-OpmApplicationFragment -Fragment $app -SourceFolder 'C:\src\Acme'
# -> C:\src\Acme\.packit\{APP-ID}.xml
```

Load it back, change it, and re-save:

```powershell
$app = Import-OpmApplicationFragment -SourceFolder 'C:\src\Acme'
Set-OpmApplication -Fragment $app -Description 'Reads PDFs and forms'
Export-OpmApplicationFragment -Fragment $app -SourceFolder 'C:\src\Acme'
```

A complete, runnable example with self-verification is in
[`examples/Build-SampleApp.ps1`](examples/Build-SampleApp.ps1):

```powershell
powershell -NoProfile -File .\examples\Build-SampleApp.ps1 -OutDir C:\temp\opm-demo
```

---

## What gets written

`Export-OpmApplicationFragment -SourceFolder <dir>` writes:

```
<dir>\.packit\{APP-ID}.xml      # the application fragment (UTF-8 no BOM, CRLF)
```

`Initialize-OpmFolder -SourceFolder <dir>` additionally creates PacKit's
managed resource subfolders:

```
<dir>\.packit\
  icons\  detection-scripts\  psadt\  intunewin\  mecm\  downloads\  temp\
```

The fragment is a `<FRAGMENT Version="23.8">` document containing one `<ITEM>`
(the application), with `Packages` and `IntuneAssignments` child collections.
Path-bearing fields (icon, detection script, package path) are stored **relative
to the `.packit` folder**; pass `-RelativizePaths` to `Export` to rewrite
absolute inputs that way automatically.

---

## Commands

| Cmdlet | Purpose |
|--------|---------|
| `New-OpmApplicationFragment` | Create a new in-memory fragment (generates a braced-UPPERCASE AppId). |
| `Import-OpmApplicationFragment` | Load a fragment from `-SourceFolder` (`.packit\<AppId>.xml`, or the first `*.xml`) or `-LiteralPath`. |
| `Export-OpmApplicationFragment` | Save a fragment to `-SourceFolder` (`.packit\<AppId>.xml`) or `-LiteralPath`. Supports `-WhatIf`, `-RelativizePaths`, `-PassThru`. |
| `Set-OpmApplication` | Update application-level fields (Name, Vendor, Description, IconPath, OS, …). |
| `Set-OpmDetectionRule` | Set the detection-rule fields (MSI/File/Registry/Script). |
| `Add-OpmPackage` | Add an installer package; `Type` is derived from the path extension. |
| `Set-OpmPackage` | Update an existing package by `-PackageId`. |
| `Remove-OpmPackage` | Remove a package by `-PackageId`. |
| `Add-OpmWinGetScanResult` | Attach a WinGet catalog match to a package. |
| `Add-OpmAssignment` | Add an Intune (Entra group) assignment. |
| `Remove-OpmAssignment` | Remove an assignment by `-MsEntraGroupId`. |
| `Initialize-OpmFolder` | Create `.packit` + the managed subfolders (idempotent). |
| `Test-OpmApplicationFragment` | Validate a fragment (`-Detailed` for Errors/Warnings). Fails invalid GUIDs, an empty name, or any XML-invalid character (control chars / lone surrogates) in a text field. |

`Get-Help <cmdlet> -Full` has parameter details and examples for each.

### Object model

```
PacKit.ApplicationFragment
  AppId Name Vendor Description IconPath WinGetAppScannedAt Unseen
  OperatingSys OperatingSysArchitecture
  DetectionRule  -> PacKit.DetectionRule (Format, Type, MsiValue, ScriptPath, File*/Reg* …)
  Packages       -> PacKit.Package[]   (PackageId, Path, Type, Version, *CmdLine, Intune* …)
                       WinGetScanResults -> PacKit.WinGetScanResult[] (CatalogPackageId, MatchScore, Vendor)
  IntuneAssignments -> PacKit.Assignment[] (MsEntraGroupId, AssignmentType, InclusionType)
```

---

## Using it in a pipeline

The cmdlets are non-interactive and pipeline-friendly. `Export` honours
`-WhatIf`; `Test-OpmApplicationFragment` returns a boolean (and a `-Detailed`
report) for gating a build:

```powershell
$ErrorActionPreference = 'Stop'
Import-Module OpenPackageManifest   # or: Import-Module .\OpenPackageManifest\OpenPackageManifest.psd1

$app = New-OpmApplicationFragment -Name $env:APP_NAME -Vendor $env:APP_VENDOR
Add-OpmPackage -Fragment $app -Path $env:INSTALLER_PATH -InstallCmdLine $env:INSTALL_ARGS -Version $env:APP_VERSION

$report = Test-OpmApplicationFragment -Fragment $app -Detailed
if (-not $report.IsValid) { $report.Errors | Write-Error; exit 1 }

Export-OpmApplicationFragment -Fragment $app -SourceFolder $env:APP_SOURCE -RelativizePaths
```

---

## Build & test

Everything goes through [`build.ps1`](build.ps1) (the same entry point CI uses):

```powershell
# One-time: install build dependencies (Pester 5 + PSScriptAnalyzer, CurrentUser):
.\build.ps1 -Bootstrap -Task Lint

# Lint + test + package (the default):
.\build.ps1                       # == -Task All
.\build.ps1 -Task Lint
.\build.ps1 -Task Test
.\build.ps1 -Task Package
```

| Task | Does |
|------|------|
| `Clean` | Remove `output\`. |
| `Lint` | Run PSScriptAnalyzer with [`PSScriptAnalyzerSettings.psd1`](PSScriptAnalyzerSettings.psd1). |
| `Test` | Run the Pester 5 suite; writes `output\testResults.xml` (NUnit). |
| `Package` | Stage the runtime module to `output\OpenPackageManifest\` and zip it to `output\OpenPackageManifest-<version>.zip`. |
| `Publish` | `Publish-Module` the staged module to the PowerShell Gallery (needs an API key). |
| `All` | `Clean` + `Lint` + `Test` + `Package` (default). |

A quick test-only run (forces Pester 5, returns the failed count as the exit
code) is also available via [`Invoke-Tests.ps1`](Invoke-Tests.ps1):

```powershell
powershell -NoProfile -File .\Invoke-Tests.ps1
powershell -NoProfile -File .\Invoke-Tests.ps1 -TestPath .\tests\OpenPackageManifest.Emitter.Tests.ps1
```

`tests\fixtures\golden-fragment.xml` and `golden-empty.xml` are hand-built from
the PacKit on-disk contract; the emitter is verified byte-for-byte against them.

---

## Releasing

CI runs lint + test on every push/PR (Windows PowerShell 5.1 **and** PowerShell
7) via [GitHub Actions](.github/workflows/ci.yml) and
[GitLab CI](.gitlab-ci.yml).

To cut a release:

1. Bump `ModuleVersion` in [`OpenPackageManifest/OpenPackageManifest.psd1`](OpenPackageManifest/OpenPackageManifest.psd1) and update
   [`CHANGELOG.md`](CHANGELOG.md).
2. Tag the commit and push the tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. The release pipeline ([`.github/workflows/release.yml`](.github/workflows/release.yml)
   / the `publish` job in `.gitlab-ci.yml`) builds, tests, **publishes to the
   PowerShell Gallery**, and attaches `OpenPackageManifest-<version>.zip` to the release.

The publish step needs a PowerShell Gallery API key supplied as the
`PSGALLERY_API_KEY` secret (GitHub) or a protected CI/CD variable (GitLab). To
publish manually:

```powershell
.\build.ps1 -Task Publish -NuGetApiKey <your-psgallery-api-key>
# or: $env:PSGALLERY_API_KEY = '<key>'; .\build.ps1 -Task Publish
```

---

## Repository layout

```
open-package-manifest/
  OpenPackageManifest/             # the module (shipped)
    OpenPackageManifest.psd1       #   manifest (RootModule, exports, PS 5.1 + Core)
    OpenPackageManifest.psm1       #   loader (dot-sources Private + Public)
    Public/                        #   the 13 exported cmdlets (one per file)
    Private/                       #   schema, emitter, parser, escaping, GUID, path helpers
  tests/                           # Pester 5 suites + golden fixtures
  examples/Build-SampleApp.ps1     # runnable, self-verifying sample
  build.ps1                        # build / lint / test / package / publish
  Invoke-Tests.ps1                 # quick Pester-5 test runner
  PSScriptAnalyzerSettings.psd1    # lint configuration
  .github/workflows/               # GitHub Actions (ci.yml, release.yml)
  .gitlab-ci.yml                   # GitLab CI (lint / test / publish)
  README.md  CHANGELOG.md  LICENSE  .gitignore
```

---

## License

MIT — see [`LICENSE`](LICENSE).

