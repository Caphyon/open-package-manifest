# Rebrand to Open Package Manifest — deferred items

Not addressed during the PacKit -> OpenPackageManifest (OPM) rename. Revisit later.

- Internal object type names (e.g. `PacKit.ApplicationFragment`, `PacKit.DetectionRule`,
  `PacKit.Package`) are left unchanged for now. Decide whether these become `OPM.*` or
  `OpenPackageManifest.*` and update `New-PacKitObject.ps1` / schema / tests accordingly.
- References to the actual third-party **PacKit** app/website (getpackit.com) — e.g. in
  README.md, LICENSE.txt, CHANGELOG.md — describe a real external tool this module's output
  is consumed by. These were left as-is (not renamed/genericized). Decide if/how to describe
  the relationship to the external PacKit app under the new project name.
