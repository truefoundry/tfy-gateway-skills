# GitOps: GitHub Actions Workflows

## Table of Contents

- [Security Prerequisites](#security-prerequisites)
- [Workflow 1: Validate on Pull Request](#workflow-1-validate-on-pull-request)
- [Workflow 2: Apply on Merge](#workflow-2-apply-on-merge)
- [Required GitHub Secrets](#required-github-secrets)

## Security Prerequisites

- **Pin the `truefoundry` package version exactly** (e.g., `truefoundry==0.5.3`) and update deliberately. Range specifiers allow untested versions to run in your pipeline.
- Store `TFY_HOST` and `TFY_API_KEY` as **GitHub Actions secrets** (never plain-text env vars).
- Use a **GitHub Environment** with required reviewers for the production deploy job to gate deployments.
- Limit the API key scope to deploy-only permissions for the target workspace.

## Workflow 1: Validate on Pull Request

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
        # Pin exact version — update deliberately after testing
        run: pip install 'truefoundry==0.5.3'

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
          while IFS= read -r file; do
            [ -z "$file" ] && continue
            [ -f "$file" ] || continue
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
          done <<< "${{ steps.changed.outputs.files }}"
```

## Workflow 2: Apply on Merge

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
    # Use a GitHub Environment with required reviewers to gate production deploys
    environment: production
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install TrueFoundry CLI
        # Pin exact version — update deliberately after testing
        run: pip install 'truefoundry==0.5.3'

      - name: Apply changed specs
        env:
          TFY_HOST: ${{ secrets.TFY_HOST }}
          TFY_API_KEY: ${{ secrets.TFY_API_KEY }}
        run: |
          # Apply modified/added files
          for file in $(git diff --name-only --diff-filter=ACMR HEAD~1 HEAD -- '*.yaml'); do
            [ -z "$file" ] && continue
            [ -f "$file" ] || continue
            echo "Applying $file..."
            tfy apply --file "$file"
          done < <(git diff --name-only --diff-filter=ACMR HEAD~1 HEAD -- '*.yaml')

          # Warn about deleted files
          for file in $(git diff --name-only --diff-filter=D HEAD~1 HEAD -- '*.yaml'); do
            [ -z "$file" ] && continue
            echo "::warning::$file was deleted. Remove the corresponding resource from TrueFoundry dashboard."
          done < <(git diff --name-only --diff-filter=D HEAD~1 HEAD -- '*.yaml')
```

> **Tip:** For stronger supply-chain protection, generate a `requirements.txt` with hashes (`pip install pip-tools && pip-compile --generate-hashes`) and install with `pip install --require-hashes -r requirements.txt`.

## Required GitHub Secrets

Set these in your repository settings (Settings → Secrets and variables → Actions):

| Secret | Description | Example |
|--------|-------------|---------|
| `TFY_HOST` | TrueFoundry platform URL | `https://your-org.truefoundry.cloud` |
| `TFY_API_KEY` | TrueFoundry API key (deploy scope only) | `tfy-...` |
