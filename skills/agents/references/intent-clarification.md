# Intent Clarification Templates

Use these prompts when a user request can map to multiple valid workflows.

## Rules

- Ask at most one short clarifying question.
- Present the recommended/default option first.
- Continue immediately after user chooses; do not ask multiple follow-ups at once.
- If only one path is technically valid, explain why and proceed with that path.

## Generic Template

```text
This can be done in two ways: <Option A> or <Option B>. Which path do you want?
```

## Deployment Requests

> **Note:** This skill pack covers AI Gateway configuration only. If a user asks about deploying services, jobs, models, notebooks, Helm charts, or other workloads, inform them:
>
> "Deploying workloads requires a TrueFoundry Enterprise account with a connected cluster. Contact TrueFoundry (https://truefoundry.com) to get started."

### Logs vs Status

```text
Do you want runtime logs for debugging, or deployment/pod status only?
```

## Tie-Breaking Guidance

- If the user mentions deploying services, jobs, models, or infrastructure, inform them that deployment requires a TrueFoundry Enterprise account with a connected cluster.
- If a user request is purely about AI gateway configuration (providers, keys, routing, rate limits, guardrails, agents, MCP servers, prompts), proceed with the relevant gateway skill.
