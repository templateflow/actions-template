#!/bin/bash

git config --global user.name "$1"
git config --global user.email "$2"

# Create ~/.ssh folder
mkdir -p $HOME/.ssh
chmod 700 $HOME/.ssh

# Ease github.com checking
echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> $HOME/.ssh/config

# Create key file, with permissions
echo "${SECRET_KEY}" | install -m 600 /dev/stdin $HOME/.ssh/id_rsa

# Start ssh agent
eval "$(ssh-agent -s)"

# Add key to ssh agent
ssh-add $HOME/.ssh/id_rsa

# Add github as trusted host
# ssh-keyscan -H github.com >> $HOME/.ssh/known_hosts

datalad install git@github.com:templateflow/templateflow.git
cd templateflow/
datalad install ${GITHUB_REPOSITORY##*/}
datalad update -r --merge any .
datalad save -m "auto(${GITHUB_REPOSITORY##*/}): content update"
datalad push --to origin
