---
name: preferences
description: Manages user deployment preferences (default workspace, resources, environment). Persists settings locally so other skills skip repeated questions. NOT for storing secrets or API keys.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# User Preferences

Persist user deployment preferences to avoid asking the same questions repeatedly. Preferences are stored locally and can be read by any skill before prompting.

## When to Use

Save, view, update, or reset default deployment settings (workspace, resources, environment). Also used proactively by other skills to check for saved preferences before prompting.

## When NOT to Use

- User is making a one-time override ("deploy to workspace X this time")
- Storing secrets or API keys → use `secrets` skill or env vars

</objective>

<context>

## Preferences File

**Location:** `~/.config/truefoundry/preferences.yml`

The file is YAML for readability. Example:

```yaml
# TrueFoundry Deployment Preferences
# Managed by truefoundry-preferences skill
# Last updated: 2026-02-14

# Default workspace — skills will use this instead of asking
workspace_fqn: "my-cluster:my-workspace"

# Default resource profiles
resources:
  dev:
    cpu_request: 0.25
    cpu_limit: 0.5
    memory_request: 256
    memory_limit: 512
  prod:
    cpu_request: 1.0
    cpu_limit: 2.0
    memory_request: 1024
    memory_limit: 2048

# Current environment (dev, staging, prod)
# Skills use this to pick resource profile and naming conventions
environment: dev

# Service naming convention
# Options: plain (my-app), prefixed (dev-my-app), suffixed (my-app-dev)
naming: plain

# Default exposure — should new services be public or internal?
expose_services: false

# Default secret group for new deployments
secret_group: ""

# App name prefix — prepended to all service names in multi-service deployments
app_prefix: ""

# Preferred base domain (if cluster has multiple)
base_domain: ""

# Docker compose defaults
compose:
  # Default db storage size for Helm charts
  db_storage: "10Gi"
  # Default Redis architecture
  redis_architecture: "standalone"
```

</context>

<instructions>

## Reading Preferences

**Every deploy-related skill should check preferences before asking questions.**

### Check if preferences file exists

```bash
PREFS_FILE=~/.config/truefoundry/preferences.yml

if [ -f "$PREFS_FILE" ]; then
  cat "$PREFS_FILE"
fi
```

### Use in decision-making

When a skill needs a value (e.g., workspace FQN):

1. **Check preferences file** — if the value exists, use it
2. **Confirm with user** — "I see your default workspace is `my-cluster:my-workspace`. Should I use it, or deploy somewhere else?"
3. **If no preference** — ask the user normally

**IMPORTANT: Never silently use a preference without mentioning it.** Always say:
```
Using your saved preference: workspace = my-cluster:my-workspace
(Change with: "update my default workspace")
```

This gives the user a chance to override without being asked every time.

## Writing Preferences

### First-time setup

If no preferences file exists and the user is deploying for the first time, offer to create one:

```
I noticed you don't have saved preferences yet.
Would you like me to remember your choices for next time?

I can save:
- Default workspace: my-cluster:my-workspace
- Environment: dev
- Resource profile: dev (0.25 CPU, 256MB)
- Expose services: no (internal only)

This saves to ~/.config/truefoundry/preferences.yml
You can update or delete it anytime.
```

**Only create the file if the user agrees.**

### After deployment

After a successful deployment, if some choices were new:

```
Deployment successful! Would you like me to save these settings as your defaults?
- Workspace: my-cluster:my-workspace (currently not saved)
```

### Update a preference

```bash
# Create directory if needed
mkdir -p ~/.config/truefoundry

# Write or update the preferences file
# Use the Write tool to create/update the YAML file
```

### User commands

| User says | Action |
|-----------|--------|
| "remember my workspace" | Save `workspace_fqn` |
| "always deploy to dev" | Save `environment: dev` |
| "default resources for prod" | Save `resources.prod` profile |
| "make services public by default" | Save `expose_services: true` |
| "forget my preferences" | Delete the preferences file |
| "show my preferences" | Display the file contents |
| "update my default workspace" | Update `workspace_fqn` |
| "reset preferences" | Delete and start fresh |

## Preference Keys Reference

| Key | Type | What It Controls | Used By Skills |
|-----|------|-----------------|----------------|
| `workspace_fqn` | string | Default deploy target | deploy, multi-service, helm, llm-deploy, mcp-server |
| `environment` | string | dev/staging/prod — affects resources and naming | deploy, multi-service |
| `resources.dev` | object | CPU/memory defaults for dev deployments | deploy, multi-service |
| `resources.prod` | object | CPU/memory defaults for prod deployments | deploy, multi-service |
| `naming` | string | Service naming convention | multi-service |
| `expose_services` | bool | Default public/internal exposure | deploy, multi-service |
| `secret_group` | string | Default secret group name | deploy, multi-service, secrets |
| `app_prefix` | string | Prefix for service names | multi-service |
| `base_domain` | string | Preferred base domain for public URLs | deploy, multi-service |
| `compose.db_storage` | string | Default DB persistence size | multi-service |
| `compose.redis_architecture` | string | Redis standalone vs. replication | multi-service |

## Integration with Other Skills

Skills should add this at the beginning of their workflow:

```
## Check User Preferences

Before asking the user for configuration, check for saved preferences:

1. Read ~/.config/truefoundry/preferences.yml (if it exists)
2. For each value you need (workspace, resources, etc.):
   - If a preference exists: use it, but tell the user you're using it
   - If no preference: ask the user as normal
3. After deployment: offer to save any new choices
```

## Privacy and Security

- **Preferences are local only** — stored on the user's machine, never sent anywhere
- **No secrets in preferences** — API keys, passwords, tokens go in env vars or TrueFoundry secrets
- **User controls everything** — preferences are only created with explicit consent
- **Easy to delete** — `rm ~/.config/truefoundry/preferences.yml`

</instructions>

<success_criteria>

## Success Criteria

- The user can save default deployment preferences (workspace, environment, resources) to a local YAML file
- The user can view, update, and delete individual preference keys on demand
- The agent has confirmed preferences with the user before silently applying them
- The agent has offered to save new choices after a successful deployment
- The user can reset all preferences with a single command

</success_criteria>

<troubleshooting>

## Error Handling

### Preferences file is malformed
```
Your preferences file (~/.config/truefoundry/preferences.yml) has a syntax error.
I'll ignore it and ask you directly. Want me to fix or recreate it?
```

### Preference value is stale
```
Your saved workspace (my-cluster:old-ws) doesn't exist anymore.
Want me to update your default workspace?
```

### Permission denied
```
Can't read/write preferences file. Check permissions on ~/.config/truefoundry/
```

</troubleshooting>
