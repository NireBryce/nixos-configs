# Cap the coredump store, which nothing else does.
#
# Found on 2026-08-11 with 76,171 coredumps and 1.1G in
# /var/lib/systemd/coredump on tenacity. systemd's default is MaxUse=10% of the
# filesystem, and on an 836G disk that ceiling is never reached, so the store
# only ever grows.
#
# It matters more here than on an ordinary host because
# WARN-impermanence.nix persists /var/lib/systemd/coredump -- deliberately, so a
# crash is still debuggable after the /root wipe. That also means nothing ever
# clears it, and the wipe cannot be relied on to.
#
# The cost is not just disk. drkonqi-coredump-processor walks the store, so a
# large backlog means it spends every boot reprocessing dumps from months ago --
# on 2026-08-11 it was still working through boot -3's, which is noise that
# hides whatever crashed this boot.
#
# 256M keeps enough to debug something that happened last week and bounds the
# damage of a crash loop. Anything already over the limit is only vacuumed as
# new dumps arrive, so the existing backlog needs clearing by hand once:
#
#     sudo find /var/lib/systemd/coredump -type f -delete
#
# settings.Coredump, not extraConfig: `systemd.coredump.extraConfig` is
# deprecated in 26.11 and errors by name, the same way systemd.sleep.extraConfig
# did.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "keep /var/lib/systemd/coredump from growing without bound";
            systemd.coredump.settings.Coredump = {
                MaxUse  = "256M";
                KeepFree = "1G";
            };
        };
}
