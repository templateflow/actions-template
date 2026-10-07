# Individual template action

This action propagates a push on a template repository (`templateflow/tpl-<Name>`) to the TemplateFlow Archive:
it syncs the template to g-Node/GIN, exports its tree to the `templateflow` S3 bucket, and points the
superdataset (`templateflow/templateflow`) at the pushed commit.

## Inputs

The action reads its inputs from the environment and stops early if a required one is missing:

- `SECRET_KEY`: SSH private key with push access to `templateflow/templateflow` and the template repository on GitHub, and to the template's mirror on GIN.
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`: credentials with write access to the `templateflow` S3 bucket.

## Example usage

The canonical caller workflow lives in [templateflow/gha-workflow-superdataset](https://github.com/templateflow/gha-workflow-superdataset):

```YAML
name: Sync with G-Node, update Superdataset and export to S3
on:
  push:
    branches: [ master, main ]
  workflow_dispatch:

jobs:
  update_superdataset:
    runs-on: ubuntu-latest
    steps:
      - name: "Sync with GIN, update TemplateFlow's superdataset and export to S3"
        uses: templateflow/actions-template@main
        env:
          SECRET_KEY: ${{ secrets.TEMPLATEFLOW_SSH_KEY }}
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```
