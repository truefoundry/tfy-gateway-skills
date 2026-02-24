---
name: gitops
description: This skill should be used when the user asks "setup gitops", "CI/CD pipeline", "deploy on push", "github actions truefoundry", "gitlab CI truefoundry", "gitops deployment", "tfy apply", "deploy from git", "automate deployments", "infrastructure as code", "continuous deployment", "deploy on merge", "bitbucket pipeline truefoundry", "auto deploy from repo", or wants to set up automated deployments from a Git repository.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# GitOps with TrueFoundry

Set up GitOps-style deployments with TrueFoundry. Store deployment configurations as YAML specs in Git and auto-deploy on push using `tfy apply` in CI/CD pipelines.

## When to Use

- User says "setup gitops", "CI/CD pipeline", "deploy on push"
- User says "github actions truefoundry", "gitlab CI truefoundry"
- User wants automated deployments triggered by Git pushes
- User wants to store TrueFoundry deployment configs in a Git repository
- User wants to use `tfy apply` in a CI/CD pipeline
- User wants infrastructure-as-code for TrueFoundry resources

## When NOT to Use

- User wants to deploy manually from local code → use `deploy` skill
- User wants to deploy an LLM model → use `llm-deploy` skill
- User wants to check what's deployed → use `applications` skill
- User wants to deploy a Helm chart → use `helm` skill
- User just wants to check TrueFoundry connection → use `status` skill

</objective>

<context>

## Prerequisites

**Always verify before setting up GitOps:**

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **TrueFoundry CLI** — `tfy` CLI must be available in the CI/CD environment (installed via `pip install truefoundry`)
3. **Git repository** — A Git repo to store deployment specs

For credential check commands and .env setup, see `references/prerequisites.md`. Use the `status` skill to verify connection before proceeding.

</context>

<instructions>

## How GitOps Works with TrueFoundry

GitOps treats Git as the single source of truth for deployment configurations. The workflow is:

1. **Store specs in Git** — All TrueFoundry resource YAML specs live in the repository
2. **Review via pull requests** — Changes are reviewed before merging, with `tfy apply --dry-run` validating specs in CI
3. **Auto-deploy on merge** — When specs are merged to the default branch, `tfy apply` deploys them automatically
4. **Full audit trail** — Git history tracks every change, who made it, and when

## Repository Organization

Organize your repo with directories for each resource type:

```
truefoundry-configs/
├── clusters/
│   └── my-cluster/
│       ├── dev-workspace/
│       │   ├── my-api-service.yaml
│       │   ├── my-worker.yaml
│       │   └── my-llm.yaml
│       ├── staging-workspace/
│       │   ├── my-api-service.yaml
│       │   └── my-worker.yaml
│       └── prod-workspace/
│           ├── my-api-service.yaml
│           └── my-worker.yaml
├── gateway/
│   ├── models.yaml
│   ├── guardrails.yaml
│   └── mcp-servers.yaml
├── integrations/
│   └── custom-integration.yaml
├── teams/
│   └── my-team.yaml
└── virtualaccounts/
    └── my-account.yaml
```

### Key Principles

- **One YAML file per resource** — Each TrueFoundry resource (service, job, model, etc.) gets its own file
- **Filename matches resource name** — The YAML filename should match the `name` field inside the spec
- **Separate directories per workspace** — Keep dev, staging, and prod configs in separate directories
- **Extract specs from the UI** — Use "Edit -> Apply Using YAML" in the TrueFoundry dashboard to get the YAML spec for any existing resource

## Manifest File Structure

Each YAML spec follows the standard TrueFoundry manifest format. For example, a service spec:

```yaml
type: service
name: my-api-service
image:
  type: image
  image_uri: my-registry/my-app:latest
  command: uvicorn main:app --host 0.0.0.0 --port 8000
ports:
  - port: 8000
    expose: true
    protocol: TCP
    app_protocol: http
    host: my-api-dev.ml.example.truefoundry.cloud
workspace_fqn: my-cluster:dev-workspace
env:
  APP_ENV: development
  LOG_LEVEL: debug
replicas:
  min: 1
  max: 3
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
```

## Environment-Specific Configs (Dev / Staging / Prod)

Maintain separate YAML files per environment. Common differences:

| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| `replicas.min` | 1 | 1 | 2+ |
| `replicas.max` | 1 | 3 | 10+ |
| `resources.cpu_request` | 0.25 | 0.5 | 1.0+ |
| `resources.memory_request` | 256 | 512 | 1024+ |
| `env.LOG_LEVEL` | debug | info | warn |
| `ports.host` | `*-dev.*` | `*-staging.*` | `*-prod.*` |
| `workspace_fqn` | `cluster:dev-ws` | `cluster:staging-ws` | `cluster:prod-ws` |

Example directory layout:

```
clusters/my-cluster/
├── dev-workspace/
│   └── my-service.yaml       # min resources, 1 replica, debug logging
├── staging-workspace/
│   └── my-service.yaml       # moderate resources, autoscaling, info logging
└── prod-workspace/
    └── my-service.yaml        # full resources, HA replicas, warn logging
```

## Using `tfy apply` in CI/CD Pipelines

The `tfy apply` command is the core of GitOps with TrueFoundry.

### Basic Usage

```bash
# Install TrueFoundry CLI
pip install truefoundry

# Authenticate (uses TFY_HOST and TFY_API_KEY env vars)
# TFY_HOST is the TrueFoundry platform URL (same as TFY_BASE_URL)

# Dry run — validate without deploying
tfy apply --file path/to/spec.yaml --dry-run

# Apply — deploy the spec
tfy apply --file path/to/spec.yaml
```

### Applying Multiple Files

To apply all changed files in a CI/CD pipeline, detect which files were modified in the commit or PR:

```bash
# Get list of changed YAML files
CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD -- '*.yaml')

# Apply each changed file
for file in $CHANGED_FILES; do
  echo "Applying $file..."
  tfy apply --file "$file"
done
```

### Handling Deleted Files

When a YAML spec file is deleted from the repo, the corresponding resource should be removed. The CI/CD pipeline should detect deleted files and handle them:

```bash
# Get deleted files
DELETED_FILES=$(git diff --name-only --diff-filter=D HEAD~1 HEAD -- '*.yaml')

for file in $DELETED_FILES; do
  echo "WARNING: $file was deleted. Remove the resource manually from the TrueFoundry dashboard."
done
```

## CI/CD Integration: GitHub Actions

### Workflow 1: Validate on Pull Request

Create `.github/workflows/dry_run_on_pr.yaml`:

```yaml
name: TrueFoundry Dry Run

on:
  pull_request:
    branches: [main]
    paths:
      - '**.yaml'

jobs:
  dry-run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install TrueFoundry CLI
        run: pip install truefoundry

      - name: Get changed files
        id: changed
        run: |
          FILES=$(git diff --name-only origin/${{ github.base_ref }}...HEAD -- '*.yaml')
          echo "files=$FILES" >> $GITHUB_OUTPUT

      - name: Validate YAML specs
        env:
          TFY_HOST: ${{ secrets.TFY_HOST }}
          TFY_API_KEY: ${{ secrets.TFY_API_KEY }}
        run: |
          for file in ${{ steps.changed.outputs.files }}; do
            echo "Validating $file..."

            # Check valid YAML syntax
            python -c "import yaml; yaml.safe_load(open('$file'))"

            # Verify filename matches internal name field
            FILE_BASE=$(basename "$file" .yaml)
            SPEC_NAME=$(python -c "import yaml; print(yaml.safe_load(open('$file')).get('name', ''))")
            if [ "$FILE_BASE" != "$SPEC_NAME" ]; then
              echo "WARNING: filename '$FILE_BASE' does not match spec name '$SPEC_NAME'"
            fi

            # Dry run validation
            tfy apply --file "$file" --dry-run
          done
```

### Workflow 2: Apply on Merge

Create `.github/workflows/apply_on_merge.yaml`:

```yaml
name: TrueFoundry Apply

on:
  push:
    branches: [main]
    paths:
      - '**.yaml'

jobs:
  apply:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install TrueFoundry CLI
        run: pip install truefoundry

      - name: Apply changed specs
        env:
          TFY_HOST: ${{ secrets.TFY_HOST }}
          TFY_API_KEY: ${{ secrets.TFY_API_KEY }}
        run: |
          # Apply modified/added files
          CHANGED=$(git diff --name-only --diff-filter=ACMR HEAD~1 HEAD -- '*.yaml')
          for file in $CHANGED; do
            echo "Applying $file..."
            tfy apply --file "$file"
          done

          # Warn about deleted files
          DELETED=$(git diff --name-only --diff-filter=D HEAD~1 HEAD -- '*.yaml')
          for file in $DELETED; do
            echo "::warning::$file was deleted. Remove the corresponding resource from TrueFoundry dashboard."
          done
```

### Required GitHub Secrets

Set these in your repository settings (Settings -> Secrets and variables -> Actions):

| Secret | Description | Example |
|--------|-------------|---------|
| `TFY_HOST` | TrueFoundry platform URL | `https://your-org.truefoundry.cloud` |
| `TFY_API_KEY` | TrueFoundry API key | `tfy-...` |

## CI/CD Integration: GitLab CI

Create `.gitlab-ci.yml`:

```yaml
stages:
  - validate
  - deploy

variables:
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"

cache:
  paths:
    - .cache/pip

.tfy-setup: &tfy-setup
  image: python:3.12-slim
  before_script:
    - pip install truefoundry

dry-run:
  <<: *tfy-setup
  stage: validate
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        - "**/*.yaml"
  script:
    - |
      CHANGED=$(git diff --name-only origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME...HEAD -- '*.yaml')
      for file in $CHANGED; do
        echo "Validating $file..."
        tfy apply --file "$file" --dry-run
      done

apply:
  <<: *tfy-setup
  stage: deploy
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      changes:
        - "**/*.yaml"
  script:
    - |
      CHANGED=$(git diff --name-only --diff-filter=ACMR HEAD~1 HEAD -- '*.yaml')
      for file in $CHANGED; do
        echo "Applying $file..."
        tfy apply --file "$file"
      done
```

Set `TFY_HOST` and `TFY_API_KEY` as CI/CD variables in GitLab (Settings -> CI/CD -> Variables).

## CI/CD Integration: Bitbucket Pipelines

Create `bitbucket-pipelines.yml`:

```yaml
image: python:3.12-slim

pipelines:
  pull-requests:
    '**':
      - step:
          name: Validate TrueFoundry Specs
          script:
            - pip install truefoundry
            - |
              CHANGED=$(git diff --name-only origin/$BITBUCKET_PR_DESTINATION_BRANCH...HEAD -- '*.yaml')
              for file in $CHANGED; do
                echo "Validating $file..."
                tfy apply --file "$file" --dry-run
              done

  branches:
    main:
      - step:
          name: Apply TrueFoundry Specs
          script:
            - pip install truefoundry
            - |
              CHANGED=$(git diff --name-only --diff-filter=ACMR HEAD~1 HEAD -- '*.yaml')
              for file in $CHANGED; do
                echo "Applying $file..."
                tfy apply --file "$file"
              done
```

Set `TFY_HOST` and `TFY_API_KEY` as repository variables in Bitbucket.

## Step-by-Step: Setting Up GitOps (Summary)

1. **Verify TrueFoundry connection** — Use the `status` skill to confirm credentials
2. **Create the repo structure** — Set up directories for your resource types (clusters, gateway, etc.)
3. **Export existing specs** — In the TrueFoundry dashboard, go to each resource -> Edit -> Apply Using YAML. Save each spec as a YAML file in the repo.
4. **Add CI/CD workflows** — Copy the appropriate workflow files for your CI provider (see above)
5. **Set repository secrets** — Add `TFY_HOST` and `TFY_API_KEY` as secrets/variables in your CI provider
6. **Test with a dry run** — Open a PR with a small change to verify the validation pipeline works
7. **Merge and deploy** — Merge the PR and confirm the apply pipeline deploys successfully

</instructions>

<success_criteria>

## Success Criteria

- The user has a Git repository with TrueFoundry YAML specs organized by environment (dev/staging/prod)
- The CI/CD pipeline validates specs on pull requests using `tfy apply --dry-run`
- The CI/CD pipeline auto-deploys specs on merge to the default branch using `tfy apply`
- The agent has provided the user with the correct CI workflow files for their CI provider (GitHub Actions, GitLab CI, or Bitbucket Pipelines)
- Repository secrets (`TFY_HOST`, `TFY_API_KEY`) are configured in the CI provider
- The user can verify the pipeline works by opening a PR with a small YAML change and seeing validation pass

</success_criteria>

<references>

## Composability

- **Verify connection first**: Use `status` skill to check TrueFoundry credentials
- **Find workspace FQN**: Use `workspaces` skill to get workspace FQNs for your specs
- **Check existing deployments**: Use `applications` skill to see what is already deployed
- **Deploy LLM models via GitOps**: Use `llm-deploy` skill to generate the manifest YAML, then store it in Git
- **Manage secrets**: Use `secrets` skill to set up secret groups referenced in your specs
- **View deployment logs**: Use `logs` skill to debug deployments after apply

</references>

<troubleshooting>

## Error Handling

### tfy apply Failed — Invalid Spec

```
tfy apply returned a validation error.
Check:
- YAML syntax is valid (no tabs, proper indentation)
- Required fields are present (type, name, workspace_fqn)
- Resource references exist (workspace, secrets, etc.)
Run: tfy apply --file spec.yaml --dry-run
```

### tfy apply Failed — Authentication Error

```
401 Unauthorized from tfy apply.
Check:
- TFY_HOST is set correctly (the platform URL, e.g., https://your-org.truefoundry.cloud)
- TFY_API_KEY is valid and not expired
- Secrets are configured correctly in your CI provider
```

### tfy apply Failed — Workspace Not Found

```
Workspace FQN in the spec does not exist.
Check:
- workspace_fqn field matches an existing workspace
- Use the workspaces skill to list available workspaces
```

### CI Pipeline Not Triggering

```
Workflow not running on push/PR.
Check:
- File path filters match your YAML file locations
- Branch filters match your default branch name
- CI provider secrets are set (TFY_HOST, TFY_API_KEY)
```

### Filename / Spec Name Mismatch

```
The YAML filename should match the 'name' field inside the spec.
Example: my-service.yaml should contain name: my-service
This is a convention for clarity — tfy apply uses the internal name, not the filename.
```

</troubleshooting>
