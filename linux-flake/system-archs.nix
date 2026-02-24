# Declares which systems flake-parts will evaluate perSystem outputs for.
# Add a new entry here when adding a host with a different CPU architecture.
{
    systems = [
        "x86_64-linux"   # nire-durandal (workstation)
        "aarch64-darwin" # nire-lysithea (macOS)
    ];
}
