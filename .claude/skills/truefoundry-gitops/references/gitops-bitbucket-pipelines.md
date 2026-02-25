# GitOps: Bitbucket Pipelines

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
