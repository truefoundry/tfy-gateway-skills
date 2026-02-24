# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added
- Production validation script: `scripts/validate-skills.sh`.
- Runtime failure-mode tests: `scripts/test-tfy-api.sh`.
- OSS governance docs: `SECURITY.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`.

### Changed
- Hardened `skills/_shared/scripts/tfy-api.sh` to fail on HTTP errors and use stricter shell settings.
- CI now enforces validation and runtime tests.

### Fixed
- Consistent explicit-only skill policy across docs.
