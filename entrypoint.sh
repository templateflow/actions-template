#!/bin/bash

git config --global user.name "$1"
git config --global user.email "$2"

# Create ~/.ssh folder
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Add github as trusted host
ssh-keyscan -t rsa -H github.com | install -m 600 /dev/stdin /root/.ssh/known_hosts

# Start ssh agent
eval "$(ssh-agent -s)"

# Add key to ssh agent
ssh-add - <<< "${SECRET_KEY}"

datalad install git@github.com:templateflow/templateflow.git
cd templateflow/
datalad install ${GITHUB_REPOSITORY##*/}
datalad update --merge any .
datalad update -d ${GITHUB_REPOSITORY##*/} --merge any .
datalad save -m "auto(${GITHUB_REPOSITORY##*/}): content update"

# Update GIN
datalad siblings configure -d ${GITHUB_REPOSITORY##*/}/ --name gin \
        --pushurl git@gin.g-node.org:/templateflow/${GITHUB_REPOSITORY##*/}.git \
        --url https://gin.g-node.org/templateflow/${GITHUB_REPOSITORY##*/}
git config --unset-all remote.gin.annex-ignore
datalad siblings configure --name gin --as-common-datasrc gin-src

datalad push --to gin
datalad push --to origin

# Update S3
datalad siblings -d ${GITHUB_REPOSITORY##*/}/ enable -s s3
pushd ${GITHUB_REPOSITORY##*/}
datalad get -r *
git annex export master --to s3
popd
