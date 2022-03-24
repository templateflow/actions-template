# Individual template action

This action updates the super-dataset with any changes to an individual template

## Inputs

The action takes environment variables as inputs (`GITHUB_REPOSITORY`) and a secret access token (with write permissions to `templateflow/templateflow`)

## Example usage

```YAML
name: "Update TemplateFlow's superdataset"
uses: templateflow/actions-template@main
env:
  SECRET_KEY: ${{ secrets.SUPER_SECRET_SSH_KEY }}
```
