{
    config,
    pkgs,
    ...
}:
let packageList = with pkgs; [
        adjustor
];

in
{
    environment.systemPackages = packageList;


    # needed for tdp adjustor
    boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];

    services.handheld-daemon = {
    # if you're coming here from github search looking for ways to make HHD work,
    #     I need you to understand that the TDP control is currently mired in nixpkgs
    #     if you want it to work, it needs some work that I cannot do.
    #     https://github.com/NixOS/nixpkgs/pull/347279
        enable      = true;
        user        = "elly";
        ui.enable   = true;
        adjustor = {
            enable = true;
            loadAcpiCallModule = true;
        };

    };

    systemd.services."power-profiles-daemon" = {
        enable = false;
    };

    # TODO: remove when https://github.com/NixOS/nixpkgs/pull/347279 is merged
    # nixpkgs.overlays = [
    #     (self: super: {
    #         handheld-daemon = super.handheld-daemon.overridePythonAttrs (o: {
    #             dependencies = with super; with python3Packages; o.dependencies ++ [
    #                 (buildPythonPackage rec {
    #                     pname = "adjustor";
    #                     version = "3.6.1";
    #                     pyproject = true;
    #                     src = fetchFromGitHub {
    #                         owner = "hhd-dev";
    #                         repo = "adjustor";
    #                         rev = "refs/tags/v${version}";
    #                         hash = "sha256-A5IdwuhsK9umMtsUR7CpREGxbTYuJNPV4MT+6wqcWT8=";
    #                     };
    #                     postPatch = ''
    #                         substituteInPlace src/adjustor/core/acpi.py \
    #                             --replace-fail '"modprobe"' '"${lib.getExe' kmod "modprobe"}"'
    #                         substituteInPlace src/adjustor/fuse/utils.py \
    #                             --replace-fail 'f"mount' 'f"${lib.getExe' util-linux "mount"}'
    #                     '';
    #                     doCheck = false;
    #                     build-system = [ setuptools ];
    #                     dependencies = [
    #                         rich
    #                         pyroute2
    #                         fuse
    #                         pygobject3
    #                         dbus-python
    #                         kmod
    #                     ];
    #                 })
    #             ];
    #         });
    #     })
    # ];
}
