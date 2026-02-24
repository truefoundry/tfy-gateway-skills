---
name: prompts
description: This skill should be used when the user asks "list prompts", "show my prompts", "get prompt version", "show prompt registry", "what prompts do I have", "find prompt", "prompt versions", "view prompt template", "browse prompts", "check prompt history", or wants to manage TrueFoundry prompt registry prompts and their versions.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# Prompts

List and inspect TrueFoundry prompt registry prompts and versions.

## When to Use

- User asks "list prompts", "show prompts"
- User wants to get a specific prompt and its versions
- User asks for a specific prompt version
- Working with LLM prompt management

</objective>

<instructions>

## List Prompts

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

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

</instructions>

<success_criteria>

## Success Criteria

- The user can see a formatted table of all prompts in the registry
- The user can retrieve a specific prompt by ID and view its versions
- The user can inspect the content of a specific prompt version
- The agent has presented prompts in a clear, tabular format

</success_criteria>

<references>

## Composability

- **With deployments**: Use `applications` skill to check deployed services that consume prompts
- **For versioning**: List prompt versions to track changes

</references>

<troubleshooting>

## Error Handling

### Prompt Not Found
```
Prompt ID not found. List prompts first to find the correct ID.
```

</troubleshooting>
