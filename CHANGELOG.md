# Changelog

All notable changes to the **OpenPackageManifest** PowerShell module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `Import-OpmApplicationFragment` now accepts a `-ResolvePaths` switch that
  resolves `IconPath`, `DetectionRule.ScriptPath`, and package `Path` /
  `SourceFolder` values to full, absolute paths (anchored at the `.packit`
  folder) on the returned object. Without it, path-bearing attributes are
  still returned exactly as stored on disk (relative to `.packit`), which is
  easy to misuse in automation scripts that need to open the referenced file.

### Changed
- Rebranded the project and PowerShell module from **PacKit** to
  **OpenPackageManifest**. All 13 public cmdlets moved from the `PacKit`
  prefix to `Opm` (e.g. `New-PacKitApplicationFragment` -> `New-OpmApplicationFragment`).
  The module folder/manifest/loader are now `OpenPackageManifest/OpenPackageManifest.psd1`
  / `.psm1`. The generated metadata folder remains `.packit`.

## [1.0.0] - 2026-06-25

### Added
- Initial release of the PacKit PowerShell module — author, load, modify and save
  PacKit **application fragments** and the `.packit` metadata folder from CI/CD.
- 13 public cmdlets:
  - `New-PacKitApplicationFragment`, `Import-PacKitApplicationFragment`,
    `Export-PacKitApplicationFragment`
  - `Set-PacKitApplication`, `Set-PacKitDetectionRule`
  - `Add-PacKitPackage`, `Set-PacKitPackage`, `Remove-PacKitPackage`
  - `Add-PacKitWinGetScanResult`
  - `Add-PacKitAssignment`, `Remove-PacKitAssignment`
  - `Initialize-PacKitFolder`, `Test-PacKitApplicationFragment`
- **Byte-identical** output to the PacKit C++ writer: `<FRAGMENT Version="23.8">`
  with one inline `<ITEM>`, UTF-8 with no BOM, CRLF line endings, 2-space indent,
  custom XML escaping, braced-UPPERCASE GUIDs, paths stored relative to `.packit`.
- Lossless load → modify → save round-trip (idempotent re-export).
- `Test-PacKitApplicationFragment` validation, including full XML 1.0 character
  checking (rejects disallowed control characters and lone/broken surrogates that
  PacKit's XML reader would refuse).
- Build tooling (`build.ps1`), Pester 5 test suite, PSScriptAnalyzer settings,
  GitHub Actions + GitLab CI pipelines, and a self-verifying example.

[Unreleased]: https://www.getpackit.com/
[1.0.0]: https://www.getpackit.com/
