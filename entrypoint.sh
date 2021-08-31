#!/bin/bash

git config --global user.name "$1"
git config --global user.email "$2"

# Start ssh agent
eval "$(ssh-agent -s)"

# Create ~/.ssh folder
mkdir -p $HOME/.ssh
chmod 700 $HOME/.ssh
# Create key file, with permissions
echo $SECRET_KEY | install -m 600 /dev/stdin $HOME/.ssh/id_rsa

# Prepare ssh client settings
echo "Host *" > $HOME/.ssh/config
echo "  AddKeysToAgent yes" >> $HOME/.ssh/config
echo "  IdentityFile ~/.ssh/id_rsa" >> $HOME/.ssh/config

# Add key to ssh agent
ssh-add - <<< "${SECRET_KEY}"

datalad install git@github.com:templateflow/templateflow.git
cd templateflow/
datalad install ${GITHUB_REPOSITORY##*/}
datalad update -r --merge any .
datalad save -m "auto(${GITHUB_REPOSITORY##*/}): content update"
datalad push --to origin
