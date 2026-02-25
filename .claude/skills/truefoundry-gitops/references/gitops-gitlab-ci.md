# GitOps: GitLab CI Pipeline

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
