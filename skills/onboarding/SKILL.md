---
name: truefoundry-onboarding
description: Guides new users through TrueFoundry setup — account registration, email verification, credential configuration, and first deployment. Use when the user says "get started", "set up truefoundry", "new account", "register", "onboard", "I'm new", or has no credentials configured.
license: MIT
compatibility: Requires Bash, curl, and Python (uv or pip)
allowed-tools: Bash(*/tfy-api.sh *) Bash(uv *) Bash(pip *) Bash(tfy*) Bash(curl*)
---

> Routing note: For ambiguous user intents, use the shared clarification templates in [references/intent-clarification.md](references/intent-clarification.md).

<objective>

# TrueFoundry Onboarding

Guide a new user from zero to a working TrueFoundry setup: account creation, credential configuration, and first successful API call.

## When to Use

- User has no TrueFoundry account yet
- User says "get started", "set up", "register", "onboard", or "I'm new to TrueFoundry"
- Credentials (`TFY_BASE_URL`, `TFY_API_KEY`) are missing and the user hasn't set them up before
- User explicitly asks how to create an account or get an API key

## When NOT to Use

- User already has credentials and wants to check status → prefer `status` skill
- User wants to manage existing tokens → prefer `access-tokens` skill
- User wants to deploy → deploying workloads requires a TrueFoundry Enterprise account with a connected cluster. See https://truefoundry.com
- User wants to list workspaces → prefer `workspaces` skill

</objective>

<instructions>

## Step 1: Detect Current State

Before starting the registration flow, check if the user already has credentials configured.

```bash
echo "TFY_BASE_URL: ${TFY_BASE_URL:-(not set)}"
echo "TFY_HOST: ${TFY_HOST:-(not set)}"
echo "TFY_API_KEY: ${TFY_API_KEY:+(set)}${TFY_API_KEY:-(not set)}"
[ -f .env ] && grep -c '^TFY_' .env 2>/dev/null && echo ".env has TFY_ vars" || echo "No .env with TFY_ vars"
```

**If credentials are already set**, skip to [Step 5: Verify Connection](#step-5-verify-connection).

**If credentials are missing**, ask the user:

> Do you already have a TrueFoundry account? If yes, I'll help you configure credentials. If not, I'll walk you through creating one.

- **Has account** → skip to [Step 3: Configure Credentials](#step-3-configure-credentials)
- **No account** → continue to Step 2

## Step 2: Register a New Account

Run the TrueFoundry registration CLI:

```bash
tfy register
```

If `tfy` is not installed yet, use:

```bash
uv run --from truefoundry tfy register
```

> **IMPORTANT:** `tfy register` is fully interactive — it requires terminal input. Let the user drive this step. Do not attempt to pipe or automate the prompts.

### What the CLI does (4-step wizard)

1. **Choose account details** — prompts for:
   - **Tenant name** (3-15 chars, lowercase alphanumeric + dashes, e.g., `acme-ai`)
   - **Work email** (company email recommended)
   - **Password** (min 8 characters, confirmed twice)
   - **Primary use case** — "ai gateway" or "llm ops"

2. **Confirm terms** — displays links to Privacy Policy and Terms of Service; requires acceptance

3. **Complete human verification if required** — some registration servers may open a browser for CAPTCHA or similar anti-abuse checks; let the user complete that step manually

4. **Create account** — the CLI calls the TrueFoundry registration service and retries individual fields on validation errors

5. **Email verification** — user must check their inbox, click the verification link, then press Enter to continue

### After registration

The CLI outputs:
- The **tenant URL** (e.g., `https://acme-ai.truefoundry.cloud`)
- Instructions to create a **Personal Access Token (PAT)**
- Optionally offers to install TrueFoundry agent skills

If the registration server is configured to require CAPTCHA, the CLI may also need a browser-based verification step before registration completes. Do not try to script or bypass that step.

Tell the user:

> Your TrueFoundry tenant is ready at `<tenant-url>`.
> Next, create your first API key:
> 1. Open `<tenant-url>` in your browser
> 2. Go to **Settings** → **Access** → **Personal Access Tokens** → **Generate New Token**
> 3. Copy the token — you'll need it in the next step
>
> See: https://docs.truefoundry.com/docs/generate-api-key

## Step 3: Configure Credentials

Once the user has their tenant URL and API key, set up the environment.

### Option A: Environment Variables (recommended for development)

```bash
export TFY_BASE_URL="https://your-org.truefoundry.cloud"
export TFY_API_KEY="tfy-..."
export TFY_HOST="${TFY_BASE_URL}"
```

### Option B: .env File (recommended for project-scoped config)

```bash
cat > .env << 'EOF'
TFY_BASE_URL=https://your-org.truefoundry.cloud
TFY_API_KEY=tfy-...
EOF
```

> **Security:** Never commit `.env` files with API keys to Git. Ensure `.env` is in `.gitignore`.

Ask the user which option they prefer, then help them set the values with their actual tenant URL and API key.

## Step 4: Install the CLI (Optional)

The CLI is recommended but not required — all skills fall back to the REST API.

```bash
tfy --version 2>/dev/null || echo "CLI not installed"
```

If not installed:

```bash
pip install 'truefoundry==0.5.0'
```

If `TFY_API_KEY` is set and the user will use CLI commands, ensure `TFY_HOST` is also set:

```bash
export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"
```

## Step 5: Verify Connection

Test that credentials work with a lightweight API call. Set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

```bash
~/.claude/skills/truefoundry-onboarding/scripts/tfy-api.sh GET '/api/svc/v1/workspaces?limit=1'
```

Present the result:

```
TrueFoundry Status:
- Base URL: https://your-org.truefoundry.cloud ✓
- API Key: configured ✓
- Connection: OK ✓

You're all set!
```

If the connection fails, see [Troubleshooting](#error-handling).

## Step 6: What's Next?

After successful setup, guide the user based on what they want to do:

> You're connected to TrueFoundry! Here's what you can do next:
>
> **AI Gateway**
> - Configure LLM routing → `ai-gateway` skill
> - Add safety guardrails → `guardrails` skill
> - Register MCP servers → `mcp-servers` skill
>
> **Manage**
> - List workspaces → `workspaces` skill
> - Check logs → `logs` skill
>
> **Deploy & Run** (requires TrueFoundry Enterprise with a connected cluster — see https://truefoundry.com)
> - Deploy services, LLMs, jobs, and notebooks via the TrueFoundry dashboard or CLI
>
> What would you like to do?

</instructions>

<success_criteria>

- The user has a TrueFoundry account (either pre-existing or newly created via `tfy register`)
- `TFY_BASE_URL` and `TFY_API_KEY` are configured (via env vars or `.env`)
- A test API call has confirmed connectivity
- The user knows what they can do next and which skill to use
- No credentials have been logged, echoed, or stored by the agent

</success_criteria>

<troubleshooting>

## Error Handling

### `tfy register` fails

```
If tfy CLI is not installed:
  uv run --from truefoundry tfy register
  # or: pip install 'truefoundry>=0.5.0' && tfy register

If registration service is unreachable:
  Check network connectivity to https://registration.truefoundry.com

If a field validation error occurs (e.g., tenant name taken, invalid email):
  The CLI will retry only the failed field — follow the prompts.

If the CLI says CAPTCHA or human verification is required:
  Let it open the browser and complete the verification there.
  If the browser does not open automatically, copy the URL shown by the CLI into your browser.
```

### Email verification not received

```
Check spam/junk folder. Try registering again with the same email.
If the problem persists, contact support@truefoundry.com.
```

### 401 Unauthorized after setting credentials

```
API key is invalid or expired. Generate a new one:
1. Open your tenant URL in browser
2. Go to Settings → API Keys → Generate New Key
3. Update TFY_API_KEY with the new value

See: https://docs.truefoundry.com/docs/generate-api-key
```

### Connection Refused / Timeout

```
Cannot reach TFY_BASE_URL. Check:
- URL is correct (include https://)
- Network/VPN is connected
- No trailing slash in the URL
```

### `.env` not picked up

```
The .env file must be in the current working directory.
Variable names must match exactly: TFY_BASE_URL, TFY_API_KEY (no quotes around values).
The tfy-api.sh script handles .env parsing — never use `source .env`.
```

### CLI host error: "TFY_HOST env must be set"

```
When using tfy CLI with TFY_API_KEY, TFY_HOST is also required:
  export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"
```

</troubleshooting>

<references>

## Composability

- **After onboarding** → Use `status` skill to re-verify credentials at any time
- **Token management** → Use `access-tokens` skill to create additional PATs
- **First deployment** → deploying workloads requires a TrueFoundry Enterprise account with a connected cluster. See https://truefoundry.com
- **Workspace selection** → Use `workspaces` skill to list and pick a workspace
- **Read the docs** → Use `docs` skill to search TrueFoundry documentation

## Related Documentation

- [Prerequisites](references/prerequisites.md) — full credential reference
- [CLI Fallback](references/cli-fallback.md) — how skills work without the CLI
- [API Endpoints](references/api-endpoints.md) — full REST API reference
- [Generate API Key](https://docs.truefoundry.com/docs/generate-api-key)

</references>
