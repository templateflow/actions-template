#!/bin/bash
set -euo pipefail

: "${SECRET_KEY:?SECRET_KEY (SSH private key) is not set}"
: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID is not set}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY is not set}"

TPL="${GITHUB_REPOSITORY##*/}"
BRANCH="${GITHUB_REF_NAME}"
SHA="${GITHUB_SHA}"

git config --global user.name "$1"
git config --global user.email "$2"

# GIN answers 403 to HTTPS requests from GitHub runners: route every GIN URL over SSH
git config --global url."git@gin.g-node.org:/".insteadOf "https://gin.g-node.org/"

# Create ~/.ssh folder
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Add github and gin.g-node.org as trusted hosts
ssh-keyscan -H github.com | install -m 600 /dev/stdin /root/.ssh/known_hosts
ssh-keyscan -H gin.g-node.org >> /root/.ssh/known_hosts

# Start ssh agent
eval "$(ssh-agent -s)"

# Clear all existing identities
ssh-add -D

# Add key to ssh agent
ssh-add - <<< "${SECRET_KEY}"

# Push the git-annex branch, merging in whatever landed on the remote meanwhile
push_annex_branch() {
    for _ in 1 2 3; do
        git push "$1" git-annex && return 0
        git fetch "$1"
        git annex merge
    done
    return 1
}

echo "Cloning template ${TPL} at ${SHA} ..."
git clone "git@github.com:templateflow/${TPL}.git" "${TPL}"
cd "${TPL}"
git checkout -B "${BRANCH}" "${SHA}"
# Auto-enables the gin-src and s3 special remotes
git annex init "templateflow/actions-template run ${GITHUB_RUN_ID:-local}"

echo "Configuring g-Node/GIN remote ..."
if ! grep -q ' name=gin-src ' <<< "$(git show git-annex:remote.log)"; then
    git annex initremote gin-src type=git autoenable=true \
        location="https://gin.g-node.org/templateflow/${TPL}"
fi
git fetch gin-src
git annex merge

echo "Retrieving annexed content ..."
git annex enableremote s3
git annex get .

echo "Pushing to g-Node/GIN ..."
git annex copy --to gin-src --not --in gin-src .
git push gin-src "${BRANCH}"

echo "Exporting to S3 bucket ..."
git annex export "${BRANCH}" --to s3

# Publish the export and location records, or clones won't know what S3 and GIN hold
echo "Pushing git-annex branch ..."
push_annex_branch gin-src
push_annex_branch origin
cd ..

echo "Updating super-dataset ..."
git clone git@github.com:templateflow/templateflow.git superdataset
cd superdataset
for _ in 1 2 3; do
    CURRENT=$(git rev-parse "HEAD:${TPL}")
    # Never move the pointer backwards if a later run already advanced it
    if git -C "../${TPL}" merge-base --is-ancestor "${SHA}" "${CURRENT}"; then
        echo "Super-dataset already points at ${CURRENT}, which contains ${SHA}."
        exit 0
    fi
    git update-index --cacheinfo "160000,${SHA},${TPL}"
    git commit -m "update(${TPL}): template action"
    git push origin HEAD && exit 0
    git fetch origin
    git reset --hard "@{u}"
done
exit 1
