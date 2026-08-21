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
  # this reads `cfg.nire.primaryUser` on the sibling branch; there is no such
  # option here, the account name being hardcoded throughout this tree
  user = "elly";
  sortStr = builtins.sort (a: b: a < b);
  names = ps: sortStr (map (p: p.name or "?") ps);
in
{
  toplevel = cfg.system.build.toplevel.drvPath;

  # Sampled separately from the toplevel because a great deal can change in the
  # initrd without any other attribute here moving -- the impermanence root
  # rollback lives there. It is also how you tell a change reached the initrd at
  # all: a boot.initrd.systemd.services unit under scripted stage 1 leaves this
  # untouched, because it is never rendered.
  initrd = cfg.system.build.initialRamdisk.drvPath;

  # sorted: set membership, insensitive to module import order
  systemPackages = names cfg.environment.systemPackages;
  homePackages = names cfg.home-manager.users.${user}.home.packages;
  systemdServices = builtins.attrNames cfg.systemd.services;
  systemdUserServices = builtins.attrNames cfg.systemd.user.services;
  users = builtins.attrNames cfg.users.users;
  userGroups = sortStr cfg.users.users.${user}.extraGroups;

  # Blind spot found 2026-08-21: ssh.nix's `elly@nire-lysithea` key had no
  # private half left on that machine, so the laptop this repo is edited from
  # could not ssh to any host in the fleet -- ssh.nix is publickey-only, so a
  # mismatch is a refusal, not a fallback. Adding the right key moved the
  # toplevel and this file reported "no attribute in the fingerprint differs",
  # because nothing sampled who is allowed to log in.
  #
  # Every user, not just ${user}: a key appearing on `root` is precisely the
  # change worth seeing, and it would be invisible if this sampled one account.
  #
  # A flat list of "<user>: <key>" rather than an attrset of user -> keys,
  # because diff-config.sh prints dict entries as `changed 'root'` with no
  # values, while list entries print the added and removed items themselves.
  # The whole key line is kept rather than just its comment field: the bug that
  # prompted this was two DIFFERENT keys whose comments differed only by a
  # `.local` suffix, so a projection down to the comment would have shown
  # nothing at all.
  #
  # `openssh.authorizedKeys.keyFiles` is deliberately not sampled -- nothing in
  # this tree sets it, and a path there would serialize to a store path that
  # churns on every flake change, making this noisy for a case that does not
  # arise. If something ever does set it, sample it here too.
  authorizedKeys =
    let
      users = builtins.attrNames cfg.users.users;
      keysOf = n: map (k: "${n}: ${k}") cfg.users.users.${n}.openssh.authorizedKeys.keys;
    in
    sortStr (builtins.concatLists (map keysOf users));
  fileSystems = builtins.attrNames cfg.fileSystems;

  # Names alone missed a real change: options is `listOf str`, so two modules
  # declaring the same mount concatenate rather than override, and the
  # duplication that produced was invisible here. Order matters for mount, so
  # these are deliberately not sorted.
  fileSystemOptions = builtins.mapAttrs (_: fs: fs.options) cfg.fileSystems;
  # no `lib` in scope here -- this file is evaluated standalone with
  # `nix eval --file`, so only builtins are available
  fileSystemsNeededForBoot = sortStr (
    builtins.filter (n: cfg.fileSystems.${n}.neededForBoot)
      (builtins.attrNames cfg.fileSystems)
  );
  etc = builtins.attrNames cfg.environment.etc;

  # Blind spot found 2026-08-11: /etc/hhd held real state (fan curves, TDP
  # profiles) and was missing from WARN-impermanence.nix's persist list, so it
  # reset to the root-blank snapshot every boot -- and nothing here would have
  # shown that, because no attribute sampled environment.persistence at all.
  #
  # `.directory or d` / `.file or d`, not the raw attrset: each entry can be a
  # plain string or a submodule with `directory`/`file`, `user`, `group`, `mode`
  # -- and that submodule carries a deprecated `method` option that throws on
  # `--json` serialization the moment anything forces it, toJSON included. The
  # projection reads the path and drops the rest, same as this file already
  # does by not hashing fileSystemOptions' submodule internals.
  persistedDirectories = sortStr (
    map (d: d.directory or d) cfg.environment.persistence."/persist".directories
  );
  persistedFiles = sortStr (
    map (f: f.file or f) cfg.environment.persistence."/persist".files
  );
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
