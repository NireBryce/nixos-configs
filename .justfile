flake := justfile_directory() / "linux-flake"

# List available recipes
default:
    @just --list

# Update all flake inputs, then check that every host still evaluates
update:
    {{ flake }}/update-flake.sh

# Evaluate every host (catches evaluation errors without building)
check:
    nix flake check {{ flake }}

# Build and activate this host. Home Manager is applied as part of the system.
switch host=`hostname`:
    nh os switch --hostname {{ host }} {{ flake }}

# Build this host without activating
build host=`hostname`:
    nh os build --hostname {{ host }} {{ flake }}

# Format every .nix file (see modules/formatter.nix before the first run)
fmt:
    nix fmt {{ flake }}
