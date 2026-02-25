# tfy-api.sh Setup

When MCP is unavailable, skills use `tfy-api.sh` for direct API calls. This is an authenticated curl wrapper that handles credentials, headers, and error formatting.

## Script Location

The path depends on which agent you are using:

| Agent | Path |
|-------|------|
| Claude Code | `~/.claude/skills/truefoundry-{skill}/scripts/tfy-api.sh` |
| Cursor | `~/.cursor/skills/truefoundry-{skill}/scripts/tfy-api.sh` |
| OpenAI Codex | `~/.codex/skills/truefoundry-{skill}/scripts/tfy-api.sh` |
| OpenCode | `~/.config/opencode/skill/truefoundry-{skill}/scripts/tfy-api.sh` |
| Windsurf | `~/.windsurf/skills/truefoundry-{skill}/scripts/tfy-api.sh` |
| Cline | `~/.cline/skills/truefoundry-{skill}/scripts/tfy-api.sh` |
| Roo Code | `~/.roo-code/skills/truefoundry-{skill}/scripts/tfy-api.sh` |

## Usage

```bash
# Set once at the start — replace {skill} with the current skill name:
TFY_API_SH=~/.claude/skills/truefoundry-{skill}/scripts/tfy-api.sh

# Then use throughout:
$TFY_API_SH GET /api/svc/v1/...
$TFY_API_SH POST /api/svc/v1/... '{"key": "value"}'
```

## Note

When skills are installed, `scripts/` is symlinked to `_shared/scripts/`, so `tfy-api.sh` is the same file regardless of which skill path you use.
