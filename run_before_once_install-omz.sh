#!/usr/bin/env bash

# If Oh My Zsh isn't installed, install it
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing Oh My Zsh..."

  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
else
  echo "Oh My Zsh is already present. Skipping."
fi
