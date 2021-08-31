#!/bin/bash

git config --global user.name "$1"
git config --global user.email "$2"

# Start ssh agent
eval "$(ssh-agent -s)"

# Store key
mkdir -p $HOME/.ssh
chmod 700 $HOME/.ssh
touch $HOME/.ssh/id_rsa
chmod 600 $HOME/.ssh/id
echo $SECRET_KEY > $HOME/.ssh/id_rsa

# Prepare ssh client settings
echo "Host *" > $HOME/.ssh/config
echo "  AddKeysToAgent yes" >> $HOME/.ssh/config
echo "  IdentityFile ~/.ssh/id_rsa" >> $HOME/.ssh/config

ssh-add -k $HOME/.ssh/id_rsa

datalad install git@github.com:templateflow/templateflow.git
cd templateflow/
datalad install ${GITHUB_REPOSITORY##*/}
datalad update -r --merge any .
datalad save -m "auto(${GITHUB_REPOSITORY##*/}): content update"
datalad push --to origin
