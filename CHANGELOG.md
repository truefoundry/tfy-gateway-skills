# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added
- Production validation script: `scripts/validate-skills.sh`.
- Runtime failure-mode tests: `scripts/test-tfy-api.sh`.
- OSS governance docs: `SECURITY.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`.
- Shared intent-clarification reference templates: `skills/_shared/references/intent-clarification.md`.

### Changed
- Hardened `skills/_shared/scripts/tfy-api.sh` to fail on HTTP errors and use stricter shell settings.
- CI now enforces validation and runtime tests.
- Updated docs for OSS readiness: corrected shared reference file list in `AGENTS.md`, expanded testing steps in `CONTRIBUTING.md`, improved PR checklist accuracy, clarified prerequisites and policy links in `README.md`, and tightened reporting guidance in `SECURITY.md`/`SUPPORT.md`/`CODE_OF_CONDUCT.md`.
- Skill routing guidance now uses clarifying questions for ambiguous intents (for example, Postgres: Helm vs containerized service).

### Fixed
- Consistent primary deployment skill policy across docs.
