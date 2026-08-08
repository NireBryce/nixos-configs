# A comparable fingerprint of one host's evaluated config, so a refactor meant
# to preserve behaviour can be checked attribute by attribute rather than only
# by "it still evaluates". Used by scripts/diff-config.sh.
#
# Lives outside modules/ deliberately: import-tree would otherwise pick it up
# and try to evaluate it as a flake-parts module.
#
# FLAKE_PATH and HOST come from the environment so the same file can be pointed
# at a git worktree of an older commit.
let
  flakePath = builtins.getEnv "FLAKE_PATH";
  host = builtins.getEnv "HOST";
  cfg = (builtins.getFlake "path:${flakePath}").nixosConfigurations.${host}.config;
  # GREP NOTE: `cfg.nire.primaryUser` on the sibling branch. There is no
  # nire.primaryUser option here -- the account name is hardcoded throughout
  # this tree (users.users.elly, home.username, home-manager.users.elly).
  user = "elly";
  sortStr = builtins.sort (a: b: a < b);
  names = ps: sortStr (map (p: p.name or "?") ps);
in
{
  toplevel = cfg.system.build.toplevel.drvPath;

  # sorted: set membership, insensitive to module import order
  systemPackages = names cfg.environment.systemPackages;
  homePackages = names cfg.home-manager.users.${user}.home.packages;
  systemdServices = builtins.attrNames cfg.systemd.services;
  systemdUserServices = builtins.attrNames cfg.systemd.user.services;
  users = builtins.attrNames cfg.users.users;
  userGroups = sortStr cfg.users.users.${user}.extraGroups;
  fileSystems = builtins.attrNames cfg.fileSystems;
  etc = builtins.attrNames cfg.environment.etc;
  fonts = names cfg.fonts.packages;
  kernelModules = sortStr cfg.boot.kernelModules;
  sessionVariables = builtins.attrNames cfg.environment.sessionVariables;
  homeFiles = builtins.attrNames cfg.home-manager.users.${user}.home.file;

  # Names alone are not enough: the shell modules churn *content*, so a change to
  # .zshrc or .blerc moved the toplevel while every sampled attribute matched and
  # this reported "the change is outside what the fingerprint samples". Hashing
  # the text says which file moved. Entries built from .source rather than .text
  # have no text to hash and are marked instead.
  homeFileHashes = builtins.mapAttrs
    (_: f: if f.text or null == null then "<source>" else builtins.hashString "sha256" f.text)
    cfg.home-manager.users.${user}.home.file;

  # unsorted: order-sensitive, so a pure reordering still shows up somewhere
  systemPackagesOrdered = map (p: p.name or "?") cfg.environment.systemPackages;

  hostName = cfg.networking.hostName;
  stateVersion = cfg.system.stateVersion;
}
