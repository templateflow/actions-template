# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A Docker container GitHub Action (`templateflow/actions-template`) that each TemplateFlow template repository (`templateflow/tpl-<Name>`) runs on every push to its default branch. Its job is to keep both distribution channels of the TemplateFlow Archive consistent with the template's new state:

1. **DataLad**: the superdataset `templateflow/templateflow` (one git submodule per template) must point at the new template commit, and the annexed content must be retrievable from GIN (`gin.g-node.org/templateflow/<tpl>`).
2. **Direct S3 download**: the template tree must be exported to the `templateflow` bucket so that `https://templateflow.s3.amazonaws.com/<tpl>/<path>` resolves. The Python client (`templateflow/python-client`) falls back to these URLs when DataLad fails, or uses them exclusively when DataLad is disabled.

Background: Ciric et al. 2022, *Nature Methods*, https://doi.org/10.1038/s41592-022-01681-2. The paper describes OSF + S3 as the storage backends; this action uses GIN (not OSF) as the git-annex content host.

## Layout and commands

All logic is in `entrypoint.sh` (plain git and git-annex; DataLad is in the image but unused). `action.yml` passes the `name`/`email` inputs as positional args `$1`/`$2` (git identity). The `Dockerfile` copies the script onto `ghcr.io/templateflow/datalad:main`. That image was last built 2021-09-01 (Ubuntu 20.04, git 2.33, git-annex 8.20210803, datalad 0.14.7); the current `templateflow/datalad-docker` Dockerfile (Alpine) has never been published under that tag. Check versions with `docker run --rm --entrypoint git ghcr.io/templateflow/datalad:main annex version`.

There is no test suite or CI. Local checks:

- `bash -n entrypoint.sh` and `docker run --rm -v "$PWD:/mnt:ro" koalaman/shellcheck:stable /mnt/entrypoint.sh`
- `docker build -t actions-template .`

**There is no dry-run mode.** Running the container with real credentials pushes to production GitHub, GIN, and S3. Callers pin `templateflow/actions-template@main`, so every push to `main` here is deployed to all template repos on their next push. Test pieces by hand in the base image against HTTPS clones, without credentials.

## Runtime contract

The action reads everything from the environment of the calling workflow and exits early if a secret is missing:

- `GITHUB_REPOSITORY`, `GITHUB_REF_NAME`, `GITHUB_SHA`: template name, branch (`master` for most, `main` for `tpl-dhcpVol`/`tpl-dhcpSym`), and pushed commit. The template name must match the superdataset submodule path, the GitHub repo, and the GIN repo.
- `SECRET_KEY`: one SSH private key for both github.com (push to `templateflow/templateflow` and to the template repo's `git-annex` branch) and gin.g-node.org. The intended secret is the org-level `TEMPLATEFLOW_SSH_KEY` (2026-10), registered on GIN for user `nipreps-admin`. Older workflows pass `secrets.NIPREPS_BOT`, and a repo-level secret of that name (from 2020) shadows the org one in several template repos; GIN rejects that key.
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`: org secrets, but a Docker action only sees env vars the caller passes explicitly.

The canonical caller workflow is `update.yml` in `templateflow/gha-workflow-superdataset`, hand-copied into each template repo as `.github/workflows/update-superdataset.yml`. Copies drift; audit them with `gh api repos/templateflow/<tpl>/contents/.github/workflows/update-superdataset.yml`.

## Remote conventions (set by the 2025-11 cleanup, templateflow/templateflow#186)

Each template's `git-annex` branch should hold exactly one live S3 remote named `s3` (`type=S3 bucket=templateflow exporttree=yes versioning=yes fileprefix=<tpl>/`, no `public=` since the bucket policy is public) and a `type=git` special remote `gin-src` pointing at `https://gin.g-node.org/templateflow/<tpl>`. Older S3 remotes were marked dead and renamed `bad-<uuid>`; some are still live and `autoenable=true`, so `git annex init` enables them too. Export only ever with `--to s3`.

GIN answers 403 to HTTPS requests from GitHub runners (it works from elsewhere), so the script sets a global `url."git@gin.g-node.org:/".insteadOf "https://gin.g-node.org/"`. git-annex honors it for content transfers too, so `gin-src` keeps its public HTTPS location in `remote.log` while the runner talks SSH.

## Pipeline in `entrypoint.sh` (order matters)

1. Clone the template from GitHub and check out `GITHUB_SHA` on `GITHUB_REF_NAME`. `git annex init` auto-enables `gin-src` and `s3`; `gin-src` is registered if a template lacks it.
2. Fetch and merge GIN's `git-annex` branch (it diverges from GitHub's when people push to GIN directly), `git annex get .` (export needs all content locally), copy missing content to GIN, push the branch to GIN.
3. `git annex export <branch> --to s3`.
4. Push the `git-annex` branch to GIN and GitHub **after** the export. The export and location records (including S3 version IDs) live only in that branch; pushing it earlier silently discards them (actions-template#3), after which `get` from `s3` fails with "unknown export location".
5. Bump the superdataset gitlink with `git update-index --cacheinfo` (no submodule checkout, so `.gitmodules` is never touched), skipping if the current pointer already contains the commit, and retrying the push on races.

The superdataset push triggers `build-skeleton.yml` (skeleton zip to OSF, Python client update) and `check-s3.yml` there. Because the superdataset is updated last, it never points at commits whose content is missing from GIN or S3.

## Verifying the outcome

A green run under the pre-2026-10 script meant nothing (no `set -e`). Check effects directly:

- S3: `curl -sI https://templateflow.s3.amazonaws.com/<tpl>/<file>` (look at `Last-Modified`), or the superdataset's `.github/scripts/check-s3.py`, which HEAD-checks every annexed file git-annex lists at `[s3]`.
- git-annex records: `git show origin/git-annex:export.log` must contain an entry for the live `s3` UUID (`git show origin/git-annex:remote.log`).
- Superdataset: `gh api repos/templateflow/templateflow/contents/<tpl> --jq .sha` must equal the template's branch tip.
- DataLad: from a fresh anonymous `datalad clone https://github.com/templateflow/templateflow`, `datalad get <tpl>/<file>` must succeed.
