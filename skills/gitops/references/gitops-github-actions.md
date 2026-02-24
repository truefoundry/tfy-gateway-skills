# GitOps: GitHub Actions Workflows

## Table of Contents

- [Workflow 1: Validate on Pull Request](#workflow-1-validate-on-pull-request)
- [Workflow 2: Apply on Merge](#workflow-2-apply-on-merge)
- [Required GitHub Secrets](#required-github-secrets)

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

## Required GitHub Secrets

Set these in your repository settings (Settings -> Secrets and variables -> Actions):

| Secret | Description | Example |
|--------|-------------|---------|
| `TFY_HOST` | TrueFoundry platform URL | `https://your-org.truefoundry.cloud` |
| `TFY_API_KEY` | TrueFoundry API key | `tfy-...` |
