#!/usr/bin/env bash
#    3. My new favourite way: as @clot27 says, you can provide nixos-rebuild with a path to the config, allowing it to be entirely inside your dotfies, with zero bootstrapping of files required.
#       `nixos-rebuild switch -I nixos-config=path/to/configuration.nix`
#    4. If you uses a flake as your primary config, you can specify a path to `configuration.nix` in it and then `nixos-rebuild switch —flake` path/to/directory
# As I hope was clear from the video, I am new to nixos, and there may be other, better, options, in which case I'd love to know them! (I'll update the gist if so)

# A rebuild script that commits on a successful build
set -e

# cd to your config dir
pushd ~/.dotfiles/NixOs/
echo $(pwd)
if [ -n "$1" ]; then
  echo "Merging into master"
  git checkout dev
  git pull
  git checkout master
  git pull
  git diff dev
  git merge --squash dev
  git commit -m "$1"
  git push
  git branch --delete dev
  git push origin --delete dev
  git branch dev
  git checkout dev
  git push -u origin dev
  popd
  exit 0
fi

git checkout dev
git pull || true # ignore when the pull doesnt work due to local changes

# Edit your config
$EDITOR ~/.dotfiles/NixOs/configuration.nix


# Early return if no changes were detected (thanks @singiamtel!)
if git diff --quiet ; then
    echo "No changes detected, exiting."
    popd
    exit 0
fi

# Autoformat your nix files
alejandra . &>/dev/null \
  || ( alejandra . ; echo "formatting failed!" && exit 1)

# Shows your changes
git diff -U0

config_file=$(pwd)/configuration.nix
echo "NixOS Rebuilding... using file: $config_file"

# Rebuild, output simplified errors, log trackebacks
sudo nixos-rebuild switch -I nixos-config=$config_file --upgrade

# Get current generation metadata
current=$(nixos-rebuild list-generations | grep current)
# Commit all changes witih the generation metadata
git commit -am "$current"
git push

# Back to where you were
popd

# Notify all OK!
notify-send -e "NixOS Rebuilt OK!" --icon=software-update-available
