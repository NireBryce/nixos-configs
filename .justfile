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

# Compare a host's config against a git ref, attribute by attribute
diff ref="HEAD~1" host="":
    {{ flake }}/scripts/diff-config.sh {{ ref }} {{ host }}

# Find modules that nothing imports (also runs as part of `just check`)
orphans:
    @python3 {{ flake }}/scripts/modules.py orphans {{ flake }}/modules

# Show what each aggregate contains; `just modules --reverse` inverts it
modules *args:
    @python3 {{ flake }}/scripts/modules.py tree {{ flake }}/modules {{ args }}

# Print a dotfile as home-manager generates it, e.g. `just dotfile .zshrc`
dotfile name host="":
    @{{ flake }}/scripts/dotfile.sh {{ name }} {{ host }}

# Add a package module, e.g. `just add-pkg cli ripgrep` or `just add-pkg gui gimp image-editors`
add-pkg group name subdir="":
    @{{ flake }}/scripts/add-pkg.sh {{ group }} {{ name }} {{ subdir }}

# Wrap nixos-generate-config output as a flake-parts module for a new host.
# Generates on this machine, or pass a file (or `-` for stdin) made elsewhere.
new-host-hardware host src="":
    @{{ flake }}/scripts/new-host-hardware.sh {{ host }} {{ src }}
