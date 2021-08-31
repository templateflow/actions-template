#!/bin/bash

git config --global user.name "$1"
git config --global user.email "$2"

datalad install git@github.com:templateflow/templateflow.git
cd templateflow/
datalad install ${GITHUB_REPOSITORY##*/}
datalad update -r --merge any .
datalad save -m "auto(${GITHUB_REPOSITORY##*/}): content update"
datalad push --to origin