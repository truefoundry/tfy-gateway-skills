---
name: prompts
description: This skill should be used when the user asks "list prompts", "show my prompts", "get prompt version", or wants to manage TrueFoundry prompt registry prompts and their versions.
allowed-tools: Bash(*/tfy-api.sh *)
---

# Prompts

List and inspect TrueFoundry prompt registry prompts and versions.

## When to Use

- User asks "list prompts", "show prompts"
- User wants to get a specific prompt and its versions
- User asks for a specific prompt version
- Working with LLM prompt management

## List Prompts

When using direct API, use the **full path** to this skill's `scripts/tfy-api.sh`. The path depends on which agent is installed (e.g. `~/.claude/skills/truefoundry-prompts/scripts/tfy-api.sh` for Claude Code, `~/.cursor/skills/truefoundry-prompts/scripts/tfy-api.sh` for Cursor). In the examples below, replace `TFY_API_SH` with the full path.

### Via MCP

```
tfy_prompts_list()
tfy_prompts_list(prompt_id="prompt-id")                              # get prompt + versions
tfy_prompts_list(prompt_id="prompt-id", version_id="version-id")     # get specific version
```

### Via Direct API

```bash
# Set the path to tfy-api.sh for your agent (example for Claude Code):
TFY_API_SH=~/.claude/skills/truefoundry-prompts/scripts/tfy-api.sh

# List all prompts
$TFY_API_SH GET /api/ml/v1/prompts

# Get prompt by ID
$TFY_API_SH GET /api/ml/v1/prompts/PROMPT_ID

# List versions
$TFY_API_SH GET '/api/ml/v1/prompt-versions?prompt_id=PROMPT_ID'

# Get specific version
$TFY_API_SH GET /api/ml/v1/prompt-versions/VERSION_ID
```

## Presenting Prompts

```
Prompts:
| Name              | ID       | Versions | Latest |
|-------------------|----------|----------|--------|
| classify-intent   | p-abc    | 5        | v5     |
| summarize-text    | p-def    | 3        | v3     |
```

## Composability

- **With ML repos**: Use `mlrepos` skill to find related ML repositories
- **For versioning**: List prompt versions to track changes

## Error Handling

### Prompt Not Found
```
Prompt ID not found. List prompts first to find the correct ID.
```
