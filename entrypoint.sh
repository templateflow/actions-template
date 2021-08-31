#!/bin/bash

git config --global user.name "$1"
git config --global user.email "$2"

# Create ~/.ssh folder
mkdir -p $HOME/.ssh
chmod 700 $HOME/.ssh

# Ease github.com checking
echo -e "Host github.com\n\tStrictHostKeyChecking no\n" | install -m 600 /dev/stdin $HOME/.ssh/config

echo "Config:"
cat $HOME/.ssh/config

# Create key file, with permissions
echo "${SECRET_KEY}" | install -m 600 /dev/stdin $HOME/.ssh/id_rsa

# Add github as trusted host
ssh-keyscan -t rsa -H github.com | install -m 600 /dev/stdin $HOME/.ssh/known_hosts

# Start ssh agent
eval "$(ssh-agent -s)"

# Add key to ssh agent
ssh-add - <<< "${SECRET_KEY}"
# ssh-add $HOME/.ssh/id_rsa

datalad install git@github.com:templateflow/templateflow.git
cd templateflow/
datalad install ${GITHUB_REPOSITORY##*/}
datalad update -r --merge any .
datalad save -m "auto(${GITHUB_REPOSITORY##*/}): content update"
datalad push --to origin
