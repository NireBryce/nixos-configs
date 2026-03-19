#! /usr/bin/env bash

# Bootstraps a flake from the directory, see https://flake-file.oeiuwq.com/tutorials/migrate-flake-parts/
nix-shell https://github.com/vic/flake-file/archive/main.tar.gz \
  -A flake-file.sh --run write-flake \
  --arg modules ./modules --argstr outputs flake-parts
