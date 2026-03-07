# CI/CD Integration Examples

## GitHub Actions

```yaml
name: Deploy to TrueFoundry
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install tfy CLI
        run: pip install 'truefoundry==0.5.0'

      - name: Login to TrueFoundry
        env:
          TFY_BASE_URL: ${{ secrets.TFY_BASE_URL }}
          TFY_API_KEY: ${{ secrets.TFY_API_KEY }}
        run: tfy login --host "$TFY_BASE_URL" --api-key "$TFY_API_KEY"

      - name: Preview changes
        run: |
          export IMAGE_TAG="${{ github.sha }}"
          export TFY_WORKSPACE_FQN="${{ vars.TFY_WORKSPACE_FQN }}"
          envsubst < manifest.yaml | tfy apply -f - --dry-run --show-diff

      - name: Apply manifest
        run: |
          export IMAGE_TAG="${{ github.sha }}"
          export TFY_WORKSPACE_FQN="${{ vars.TFY_WORKSPACE_FQN }}"
          envsubst < manifest.yaml | tfy apply -f -
```

## GitLab CI

```yaml
deploy:
  stage: deploy
  image: python:3.12-slim
  before_script:
    - pip install 'truefoundry==0.5.0'
    - tfy login --host "$TFY_BASE_URL" --api-key "$TFY_API_KEY"
  script:
    - export IMAGE_TAG="$CI_COMMIT_SHA"
    - envsubst < manifest.yaml | tfy apply -f -
  only:
    - main
```

## Generic CI/CD Pattern

```bash
#!/bin/bash
# deploy.sh -- generic CI/CD deploy script
set -euo pipefail

# 1. Install CLI
pip install 'truefoundry==0.5.0'

# 2. Authenticate
tfy login --host "$TFY_BASE_URL" --api-key "$TFY_API_KEY"

# 3. Substitute environment variables
envsubst < manifest.yaml > manifest-resolved.yaml

# 4. Preview changes
echo "=== Dry Run ==="
tfy apply -f manifest-resolved.yaml --dry-run --show-diff

# 5. Apply
echo "=== Applying ==="
tfy apply -f manifest-resolved.yaml

# 6. Cleanup
rm -f manifest-resolved.yaml
```
