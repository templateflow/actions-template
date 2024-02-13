#!/bin/bash

git config --global user.name "$1"
git config --global user.email "$2"

# Create ~/.ssh folder
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Add github and gin.g-node.org as trusted hosts
ssh-keyscan -H github.com | install -m 600 /dev/stdin /root/.ssh/known_hosts
ssh-keyscan -H gin.g-node.org >> /root/.ssh/known_hosts

# Start ssh agent
eval "$(ssh-agent -s)"

# Add key to ssh agent
ssh-add - <<< "${SECRET_KEY}"

echo "Installing TemplateFlow Archive super-dataset ..."
datalad install git@github.com:templateflow/templateflow.git

echo "Installing template ${GITHUB_REPOSITORY##*/} ..."
cd templateflow/
git submodule set-url -- ${GITHUB_REPOSITORY##*/} git@github.com:templateflow/${GITHUB_REPOSITORY##*/}.git
datalad install ${GITHUB_REPOSITORY##*/}

echo "Updating template ${GITHUB_REPOSITORY##*/} ..."
datalad update -d ${GITHUB_REPOSITORY##*/} --merge any .

# Update GIN
echo "Configuring g-Node/GIN remote ..."
pushd ${GITHUB_REPOSITORY##*/}
datalad siblings configure -d . --name gin \
        --pushurl git@gin.g-node.org:/templateflow/${GITHUB_REPOSITORY##*/}.git \
        --url https://gin.g-node.org/templateflow/${GITHUB_REPOSITORY##*/}
git config --unset-all remote.gin.annex-ignore
datalad siblings configure --name gin --as-common-datasrc gin-src
datalad save -m "up: template action after content change"

echo "Pushing to g-Node/GIN ..."
datalad push --to gin .

echo "Pushing to GitHub ..."
datalad push --to origin .

echo "Pushing super-dataset ..."
popd
git submodule set-url -- ${GITHUB_REPOSITORY##*/} https://github.com/templateflow/${GITHUB_REPOSITORY##*/}
datalad save -m "update(${GITHUB_REPOSITORY##*/}): template action"
datalad push --to origin .

# Update S3
echo "Exporting to S3 bucket ..."
datalad siblings -d ${GITHUB_REPOSITORY##*/}/ enable -s s3
pushd ${GITHUB_REPOSITORY##*/}
datalad get -r *
git annex export master --to s3
popd
