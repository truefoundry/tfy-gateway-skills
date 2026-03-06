# GitOps: GitLab CI Pipeline

## Security Prerequisites

- **Pin the `truefoundry` package version exactly** (e.g., `truefoundry==0.5.3`) and update deliberately. Range specifiers allow untested versions to run in your pipeline.
- Store `TFY_HOST` and `TFY_API_KEY` as **masked and protected** CI/CD variables in GitLab (Settings → CI/CD → Variables → check "Mask variable" and "Protect variable").
- Use a **protected environment** for the deploy stage to gate production deployments to approved runners and branches.
- Limit the API key scope to deploy-only permissions for the target workspace.

## Pipeline Configuration

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
    # Pin exact version — update deliberately after testing
    - pip install 'truefoundry==0.5.3'

dry-run:
  <<: *tfy-setup
  stage: validate
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        - "**/*.yaml"
  script:
    - |
      for file in $(git diff --name-only origin/"$CI_MERGE_REQUEST_TARGET_BRANCH_NAME"...HEAD -- '*.yaml'); do
        [ -z "$file" ] && continue
        [ -f "$file" ] || continue
        echo "Validating $file..."
        tfy apply --file "$file" --dry-run
      done

apply:
  <<: *tfy-setup
  stage: deploy
  # Use a protected environment to gate production deployments
  environment:
    name: production
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      changes:
        - "**/*.yaml"
  script:
    - |
      for file in $(git diff --name-only --diff-filter=ACMR HEAD~1 HEAD -- '*.yaml'); do
        [ -z "$file" ] && continue
        [ -f "$file" ] || continue
        echo "Applying $file..."
        tfy apply --file "$file"
      done
```

> **Tip:** For stronger supply-chain protection, generate a `requirements.txt` with hashes (`pip install pip-tools && pip-compile --generate-hashes`) and install with `pip install --require-hashes -r requirements.txt`.

## Required CI/CD Variables

Set these as **masked and protected** variables in GitLab (Settings → CI/CD → Variables):

| Variable | Masked | Protected | Description |
|----------|--------|-----------|-------------|
| `TFY_HOST` | Yes | Yes | TrueFoundry platform URL (e.g., `https://your-org.truefoundry.cloud`) |
| `TFY_API_KEY` | Yes | Yes | TrueFoundry API key with deploy scope only |
