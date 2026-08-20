#!/bin/bash

###
# Determine how to run privileged commands
###

if [[ $(id -u) -eq 0 ]]; then
  SUDO=""
elif command -v sudo &>/dev/null; then
  SUDO="sudo"
else
  printf "Error: not running as root and sudo is not available.\n" >&2
  exit 1
fi

###
# install tools
###

if command -v apt-get &>/dev/null; then
  $SUDO apt-get update -q
else
  printf "Warning: apt-get not available, skipping apt-get update.\n" >&2
fi


###
# Copilot instructions
###

mkdir -p ~/.copilot/instructions
cp .copilot/instructions/writing-style.instructions.md ~/.copilot/instructions/


###
# Enable tools and set up aliases
###

printf "\n\n# Shell extras from aliceptve/dotfiles-gu\n\n" >> ~/.bash_aliases
cat shell_extras.sh >> ~/.bash_aliases
