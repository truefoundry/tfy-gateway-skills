# Guardrail Providers Reference

All supported guardrail provider integration types for TrueFoundry AI Gateway.

## Provider Table

| Provider Type | Operation | Required Config | Description |
|---|---|---|---|
| `integration/guardrail/openai-moderations` | validate | `api_key` | OpenAI Moderations API for content safety classification |
| `integration/guardrail/aws-bedrock` | validate | `aws_access_key_id`, `aws_secret_access_key`, `aws_region` | AWS Bedrock Guardrails for content filtering and topic denial |
| `integration/guardrail/custom` | validate, mutate | `endpoint_url`, `headers` (optional) | Custom HTTP endpoint for user-defined guardrail logic |
| `integration/guardrail/azure-pii` | validate, mutate | `azure_endpoint`, `azure_api_key` | Azure AI Language PII detection and redaction |
| `integration/guardrail/azure-content-safety` | validate | `azure_endpoint`, `azure_api_key` | Azure AI Content Safety for harmful content detection |
| `integration/guardrail/azure-prompt-shield` | validate | `azure_endpoint`, `azure_api_key` | Azure Prompt Shield for prompt injection and jailbreak detection |
| `integration/guardrail/enkrypt-ai` | validate | `api_key` | Enkrypt AI guardrails for content safety and compliance |
| `integration/guardrail/palo-alto-prisma-airs` | validate | `api_key`, `endpoint_url` | Palo Alto Prisma AIRS for AI security scanning |
| `integration/guardrail/promptfoo` | validate | `api_key` (optional) | Promptfoo red-teaming and guardrail evaluation |
| `integration/guardrail/fiddler` | validate | `api_key`, `endpoint_url` | Fiddler AI observability and guardrails |
| `integration/guardrail/pangea` | validate, mutate | `api_key`, `domain` | Pangea security services for AI content protection |
| `integration/guardrail/patronus` | validate | `api_key` | Patronus AI guardrails for hallucination and safety detection |
| `integration/guardrail/secret-detection` | validate | _(none)_ | Built-in secret and credential detection in inputs/outputs |
| `integration/guardrail/code-safety-linter` | validate | _(none)_ | Built-in code safety linter for dangerous code patterns |
| `integration/guardrail/sql-sanitizer` | validate, mutate | _(none)_ | Built-in SQL injection detection and sanitization |
| `integration/guardrail/regex` | validate, mutate | `patterns` | Regex-based pattern matching for custom content rules |
| `integration/guardrail/tfy-pii` | validate, mutate | _(none)_ | TrueFoundry built-in PII detection and redaction |
| `integration/guardrail/tfy-content-moderation` | validate | _(none)_ | TrueFoundry built-in content moderation |
| `integration/guardrail/tfy-prompt-injection` | validate | _(none)_ | TrueFoundry built-in prompt injection detection |
| `integration/guardrail/cedar` | validate | `policy_store_id`, `endpoint_url` | Cedar policy engine for fine-grained authorization decisions |
| `integration/guardrail/opa` | validate | `endpoint_url`, `policy_path` | Open Policy Agent for policy-as-code guardrail evaluation |
| `integration/guardrail/google-model-armor` | validate | `project_id`, `location`, `credentials` | Google Model Armor for AI safety and content filtering |
| `integration/guardrail/grayswan-cygnal` | validate | `api_key` | GraySwan Cygnal for adversarial robustness and safety testing |

## Operation Types

- **validate** — Checks content and returns pass/fail. Used to block or flag requests.
- **mutate** — Modifies content in-place (e.g., redacting PII, sanitizing SQL). Can also validate.

## Built-in Providers (No Config Required)

These providers run locally within the gateway and need no external credentials:

- `secret-detection` — Detects API keys, tokens, passwords in text
- `code-safety-linter` — Flags dangerous code patterns (eval, exec, shell commands)
- `sql-sanitizer` — Detects and sanitizes SQL injection attempts
- `tfy-pii` — Detects and redacts personally identifiable information
- `tfy-content-moderation` — Flags harmful, toxic, or inappropriate content
- `tfy-prompt-injection` — Detects prompt injection and jailbreak attempts
- `regex` — Custom regex patterns (requires `patterns` config but no external credentials)

## External Providers (Credentials Required)

These providers call external APIs and require authentication:

- **Cloud Provider**: `aws-bedrock`, `azure-pii`, `azure-content-safety`, `azure-prompt-shield`, `google-model-armor`
- **Third-party SaaS**: `openai-moderations`, `enkrypt-ai`, `palo-alto-prisma-airs`, `promptfoo`, `fiddler`, `pangea`, `patronus`, `grayswan-cygnal`
- **Self-hosted**: `custom`, `cedar`, `opa`

## Integration Config Example

```json
{
  "type": "integration/guardrail/azure-pii",
  "config": {
    "azure_endpoint": "https://my-resource.cognitiveservices.azure.com",
    "azure_api_key": "your-api-key"
  }
}
```

For built-in providers with no config:

```json
{
  "type": "integration/guardrail/tfy-pii",
  "config": {}
}
```
