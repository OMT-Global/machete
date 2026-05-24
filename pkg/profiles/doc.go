/*
Package profiles manages machete profile lifecycle and path resolution.

Profiles allow multiple machine configurations to coexist:
  - "default": the repo root
  - "base": a shared base config at profiles/base/
  - custom: user-defined profiles at profiles/<name>/

Profile stacking means base config applies first, then custom overrides.
*/
package profiles
