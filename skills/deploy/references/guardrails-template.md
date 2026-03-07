# Guardrails Server Template Bootstrap

When the user asks to deploy a **Guardrails server**, start from the official scaffold repo:

- Template repo: `https://github.com/truefoundry/custom-guardrails-template`

Do not start from an empty service unless the user explicitly opts out.

## Flow

1. Confirm target workspace and deployment source (same mandatory checks as `deploy-service.md`)
2. Bootstrap from template:
   ```bash
   git clone https://github.com/truefoundry/custom-guardrails-template
   cd custom-guardrails-template
   ```
3. Ask user what to customize:
   - provider integrations
   - guardrail policy/rules
   - runtime settings, env vars, and secrets
4. Keep deployment manifest aligned with deploy defaults (`resources`, probes, secret references)
5. Deploy using standard deploy flow (`tfy deploy -f truefoundry.yaml --no-wait` or `tfy apply` for prebuilt image)
6. Verify status and return endpoint + next steps

## Guardrails-Specific Notes

- Treat provider credentials and policy secrets as sensitive: store in secret groups and reference via `tfy-secret://...`
- Keep policy/config files mounted via `mounts` when users ask for file-based configuration
- After deployment, if user wants enforcement on AI Gateway traffic, route them to the `guardrails` skill to attach rules to `gateway_ref`
