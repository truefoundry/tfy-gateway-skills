# Intent Clarification Templates

Use these prompts when a user request can map to multiple valid workflows.

## Rules

- Ask at most one short clarifying question.
- Present the recommended/default option first.
- Continue immediately after user chooses; do not ask multiple follow-ups at once.
- If only one path is technically valid, explain why and proceed with that path.
- **Attach/add flows (gateway, MCP, etc.):** Do not assume missing details. If the user says "attach X to gateway" or "add Y" without enough info, ask for the required inputs (e.g. URL, provider, credentials, model name, transport) until you have clarity. Then proceed.

## Generic Template

```text
This can be done in two ways: <Option A> or <Option B>. Which path do you want?
```

## Onboarding / Getting Started

```text
Do you already have a TrueFoundry account? If not, run `tfy register` to create one. If you already have credentials, I can check your connection with the `status` skill.
```

## Deployment Templates

### Database / Postgres / Redis

```text
I can deploy this as a Helm chart or as a containerized service. Which one do you want?
```

### LLM Serving

```text
Do you want dedicated model serving (`llm-deploy`) or a generic service deployment (`deploy`)?
```

### Manual Deploy vs GitOps

```text
Do you want a one-time/manual deployment now, or GitOps CI/CD setup for automatic deploys on push?
```

### Logs vs Status

```text
Do you want runtime logs for debugging, or deployment/pod status only?
```

## Tie-Breaking Guidance

- If user says "production-ready database", recommend Helm first.
- If user says "quick local test", recommend the simpler path with fewer required inputs.
- If user says "docker", "container image", "dockerfile", or similar for a database deploy, choose the containerized `deploy` path directly (do not default to Helm).
- If the user mentions an exact tool (for example, "helm", "gitops", "tfy apply"), honor it directly.
