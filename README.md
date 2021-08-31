# Individual template action

This action updates the super-dataset with any changes to an individual template

## Inputs

The action takes environment variables as inputs (`GITHUB_REPOSITORY`) and a secret access token (with write permissions to `templateflow/templateflow`)

## Example usage

```YAML
uses: actions/update-superdataset@v1.0.0
with:
  name: NiPreps Bot
  email: nipreps@gmail.com
  ssh-private-key: ${{ secrets.GITHUB_PAT }}
```
