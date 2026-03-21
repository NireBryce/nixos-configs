#! /usr/bin/env bash

# Bootstraps a flake from the flake-file, see https://flake-file.oeiuwq.com/tutorials/migrate-flake-parts/
nix-shell https://github.com/vic/flake-file/archive/main.zip -A flake-file.sh --run bootstrap
