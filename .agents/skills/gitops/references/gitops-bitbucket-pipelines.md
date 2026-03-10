# GitOps: Bitbucket Pipelines

## Security Prerequisites

- **Pin the `truefoundry` package version exactly** (e.g., `truefoundry==0.5.3`) and update deliberately. Range specifiers allow untested versions to run in your pipeline.
- Store `TFY_HOST` and `TFY_API_KEY` as **secured** repository variables in Bitbucket (Settings → Repository variables → check "Secured"). Never store credentials as plain variables.
- Restrict the `main` branch deploy step to run only on **protected branches** with required approvals.
- Limit pipeline credentials to the minimum scope needed (deploy-only API key, restricted workspace).

## Pipeline Configuration

Create `bitbucket-pipelines.yml`:

```yaml
image: python:3.12-slim

pipelines:
  pull-requests:
    '**':
      - step:
          name: Validate TrueFoundry Specs
          script:
            # Pin exact version — update deliberately after testing
            - pip install 'truefoundry==0.5.3'
            - |
              for file in $(git diff --name-only origin/"$BITBUCKET_PR_DESTINATION_BRANCH"...HEAD -- '*.yaml'); do
                [ -z "$file" ] && continue
                [ -f "$file" ] || continue
                echo "Validating $file..."
                tfy apply --file "$file" --dry-run
              done

  branches:
    main:
      - step:
          name: Apply TrueFoundry Specs
          deployment: production
          script:
            # Pin exact version — update deliberately after testing
            - pip install 'truefoundry==0.5.3'
            - |
              for file in $(git diff --name-only --diff-filter=ACMR HEAD~1 HEAD -- '*.yaml'); do
                [ -z "$file" ] && continue
                [ -f "$file" ] || continue
                echo "Applying $file..."
                tfy apply --file "$file"
              done
```

> **Tip:** For stronger supply-chain protection, generate a `requirements.txt` with hashes (`pip install pip-tools && pip-compile --generate-hashes`) and install with `pip install --require-hashes -r requirements.txt`.

## Required Repository Variables

Set these as **secured** variables in Bitbucket (Settings → Repository variables):

| Variable | Secured | Description |
|----------|---------|-------------|
| `TFY_HOST` | Yes | TrueFoundry platform URL (e.g., `https://your-org.truefoundry.cloud`) |
| `TFY_API_KEY` | Yes | TrueFoundry API key with deploy scope only |
