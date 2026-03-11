# Automatic Deployment Debugging

After any deploy or apply, the agent must verify outcome and attempt to fix failures before handing off to the user.

## When This Applies

- After `tfy apply` or `tfy deploy` (or REST API equivalent), always check deployment status.
- If status is `DEPLOY_FAILED`, `BUILD_FAILED`, or the app never reaches `DEPLOY_SUCCESS`, follow this flow.

## Flow (Max 2 Runs)

1. **Verify status**  
   Use MCP `tfy_applications_list` or:
   ```bash
   bash $TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=SERVICE_NAME'
   ```
   Read `data[0].status` and, if present, `activeDeployment.status`.

2. **If failed (BUILD_FAILED / DEPLOY_FAILED):**
   - **Fetch logs** — Use the `logs` skill (or API) for the failing app/deployment. Focus on the last 50–100 lines and error lines.
   - **Identify cause** — Common causes:
     - Out of memory / OOMKilled → increase `memory_limit` (and optionally `memory_request`)
     - Missing or wrong env var → fix manifest `env` or add missing `tfy-secret://` reference
     - Secret group not found → create secret group with `secrets` skill, then reference in manifest
     - Image pull error → check image URI and registry auth
     - Health check failing → adjust probes in manifest or fix app startup
     - Port/host misconfiguration → align `ports` and `host` with cluster base domain
   - **Apply one fix** — Change manifest (or create missing secret), then run **one** retry:
     ```bash
     tfy apply -f tfy-manifest.yaml
     # or
     tfy deploy -f truefoundry.yaml --no-wait
     ```
   - **Verify again** — Poll status until `DEPLOY_SUCCESS` or a timeout (e.g. 5 minutes).

3. **If still failed after this single retry:**  
   **Stop and hand off to the user.** Do not retry again automatically.
   - Summarize what was tried (e.g. "Increased memory; deployment still failed").
   - Include a short logs excerpt (last 20–30 lines or the main error block).
   - Suggest next steps (e.g. "Check logs in UI", "Verify secret group exists", "Try with more memory or different image").

## Summary

| Step              | Action                                      |
|------------------|---------------------------------------------|
| After deploy     | Check status automatically                  |
| If failed        | Fetch logs → identify cause → fix → retry once |
| If still failed  | Report to user with summary + log excerpt   |

This keeps deployments self-healing for common issues while avoiding unbounded retries.
