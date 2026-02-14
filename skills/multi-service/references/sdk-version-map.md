# TrueFoundry SDK Version Compatibility Map

<!-- Check this after running tfy-version.sh to determine which SDK patterns to use.
     This document maps SDK versions to known breaking changes and compatibility notes.
     If the detected version is newer than anything listed here, see the Freshness Note. -->

## Version Compatibility Table

| Version Range | Status | Key Changes | Action |
|---------------|--------|-------------|--------|
| `>= 0.5.0` | **Current** | `replicas` accepts `int` directly. `TFY_BASE_URL` is the standard env var. | Use `sdk-patterns.md` as-is. No adjustments needed. |
| `0.4.x` | Supported | `replicas` requires `Replicas(min=N, max=N)` object. Reads `TFY_HOST` env var (not `TFY_BASE_URL`). | Apply compat patterns from this doc before using `sdk-patterns.md`. |
| `0.3.x` | Legacy | Missing newer resource/port features. Limited GPU type support. | Consider upgrading. If not possible, apply compat patterns or fall back to REST API. |
| `< 0.3.0` | Unsupported | Too old for reliable SDK-based deployment. | Fall back to REST API via `tfy-api.sh` + JSON manifest. |

---

## Breaking Changes Detail

### `replicas` parameter

- **>= 0.5.0:** Accepts a plain `int`.
  ```python
  service = Service(name="my-app", ..., replicas=1)
  ```
- **0.4.x and below:** Requires a `Replicas` object.
  ```python
  from truefoundry.deploy import Replicas
  service = Service(name="my-app", ..., replicas=Replicas(min=1, max=1))
  ```

### `TFY_HOST` vs `TFY_BASE_URL`

- **>= 0.5.0:** Reads `TFY_BASE_URL`.
- **0.4.x and below:** Reads `TFY_HOST`.
- The `deploy-template.py` includes a shim that copies `TFY_BASE_URL` to `TFY_HOST` when only the former is set, so both SDK generations work:
  ```python
  if os.environ.get("TFY_BASE_URL") and not os.environ.get("TFY_HOST"):
      os.environ["TFY_HOST"] = os.environ["TFY_BASE_URL"].strip().rstrip("/")
  ```
  Always keep this shim in generated deploy scripts.

### Import paths

No import path changes between 0.4.x and 0.5.x. All deploy classes remain under `truefoundry.deploy`. If a future version moves imports, this section will be updated.

---

## Decision Flow

When the agent detects (or fails to detect) the TrueFoundry SDK, follow this flow:

```
SDK not installed
  --> Fall back to REST API (tfy-api.sh + JSON manifest)

SDK installed, version < 0.3.0
  --> Fall back to REST API (tfy-api.sh + JSON manifest)

SDK installed, version 0.3.x - 0.4.x
  --> Use sdk-patterns.md BUT apply compat adjustments:
      - Replace `replicas=N` with `replicas=Replicas(min=N, max=N)`
      - Ensure TFY_HOST shim is present in deploy script
      - Import `Replicas` from truefoundry.deploy

SDK installed, version >= 0.5.0
  --> Use sdk-patterns.md as-is, no changes needed

SDK installed, version newer than documented here
  --> WebFetch TrueFoundry docs or PyPI page for latest patterns
      before proceeding (see Freshness Note below)
```

---

## Freshness Note

If the detected SDK version is **newer than any version documented here**, the agent should WebFetch the TrueFoundry SDK changelog or PyPI page to check for new breaking changes before proceeding. Do not assume forward compatibility -- new major or minor versions may introduce breaking changes to resource definitions, deploy methods, or import paths.

Useful URLs to check:
- PyPI: `https://pypi.org/project/truefoundry/`
- Docs: `https://docs.truefoundry.com/docs/deploy-service-using-python-sdk`
