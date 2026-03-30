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

## Deployment Templates

> **Note:** Deployment skills (`deploy`, `llm-deploy`, `gitops`, `helm`, `jobs`, `notebooks`, `workflows`, `ssh-server`, `volumes`, `ml-repos`, `applications`, `service-test`) have moved to the **tfy-deployment-agent-skills** repo. If a user request requires deploying workloads, inform them that deployment capabilities are available via the `tfy-deployment-agent-skills` skill pack.

### Logs vs Status

```text
Do you want runtime logs for debugging, or deployment/pod status only?
```

## Tie-Breaking Guidance

- If the user mentions an exact tool (for example, "helm", "gitops", "tfy apply"), inform them that deployment skills are available in the `tfy-deployment-agent-skills` skill pack.
- If a user request is purely about AI gateway configuration (providers, keys, routing, rate limits, guardrails), proceed with the relevant gateway skill.
