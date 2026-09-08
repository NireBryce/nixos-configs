# Tenacity's live Plasma/KDE state (theme, kwin behavior, input devices,
# global shortcuts), captured from this machine's own ~/.config on
# 2026-09-01 and turned into plasma-manager declarations.
#
# Home-manager class, but deliberately NOT part of `ellyHomeManager` --
# imported only via tenacityConfiguration's `home-manager.users.elly.imports`
# (see the bottom of tenacity-configuration.nix), so plasma-manager's own HM
# module never loads on durandal, lysithea or cube. Filed under
# tenacity/configuration/ rather than a shared `desktop-env`-style category:
# this is one host's live preferences, not something a second KDE host would
# necessarily want verbatim.
#
# Deliberately a CURATED subset, not a 1:1 dump of every rc file:
#
#   - plasma-org.kde.plasma.desktop-appletsrc (panel/widget layout) is left
#     out. plasma-manager can express panels/widgets, but the live layout
#     here is two floating panels the user still rearranges by hand; pinning
#     it declaratively would just fight that.
#   - kwinrulesrc's one window rule is keyed by a random per-install UUID and
#     isn't even referenced by [General] rules= in the live file (orphaned
#     even in the state being captured) -- not worth carrying forward.
#   - kwinrc's [Tiling][<uuid>] sections are per-virtual-desktop generated
#     layouts, not preferences; [Desktops] Id_N uuids are generated identity,
#     not configuration -- only Number/Rows are.
#
# A second pass (still 2026-09-01) swept every other file under ~/.config
# matching kde/plasma-*/k* for anything missed the first time -- found
# powerdevilrc (real power-button/lid/sleep behavior, below) and kaccessrc's
# StickyKeys. Also found and deliberately left out:
#   - the desktop wallpaper (plasma-org.kde.plasma.desktop-appletsrc's
#     Containments/1/Wallpaper) points at ~/Downloads/"vim motion wallpaper
#     less good.png" -- a personal file outside the repo, not something a
#     Nix path can reference reproducibly, and its own filename says it's
#     still being decided anyway.
#   - kactivitymanagerd-statsrc's kickoff favorites ordering -- this is
#     launcher/widget config, the same category as the appletsrc panel
#     layout already excluded above.
#   - bluedevilglobalrc's per-adapter powered= state is keyed by this
#     machine's Bluetooth adapter MAC addresses, not portable; kwalletrc's
#     "never auto-lock the wallet" settings and plasma-nm's connection
#     applet settings both read as plausible stock defaults for Plasma 6,
#     not confidently a deliberate customization one way or the other, so
#     left out rather than guessed at.
#
# kglobalshortcutsrc itself is ~350 lines because KDE dumps the *entire*
# default shortcut set to disk the first time anything touches it, not
# because the user rebound 350 actions -- BUT each line is actually
# `active,default,description`, so the file records its own upstream default
# right next to whatever's live. Diffing column 1 against column 2 (rather
# than guessing at stock KDE from memory) turned up the real story: almost
# every default Meta-based kwin/plasmashell shortcut on this machine has been
# deliberately unbound, not left alone. Nothing in this repo says why (not a
# jovian/gamescope Meta-key claim -- grepped for one, found nothing); this
# only captures the fact of it, observed on 2026-09-01. All of those are
# still worth pinning: an unbind is as much a real customization as a
# rebind, and both currently live only in this machine's mutable state.
{ lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

            programs.plasma = {
                enable = true;

                workspace = {
                    # kdeglobals [KDE] LookAndFeelPackage
                    lookAndFeel = "org.kde.breezedark.desktop";
                };

                kwin = {
                    # kwinrc [Desktops] Number=4 Rows=2 -- four virtual desktops,
                    # laid out 2x2 rather than one long row.
                    virtualDesktops = {
                        number = 4;
                        rows = 2;
                    };
                };

                # powerdevilrc [AC|Battery|LowBattery][SuspendAndShutdown] --
                # numeric enums decoded against plasma-manager's own mapping
                # (LidAction=64 -> "turnOffScreen", PowerButtonAction=1 ->
                # "sleep", SleepMode=1 -> "standby"). Deliberately not
                # "hibernate"/"standbyThenHibernate" anywhere, including at
                # low battery -- this machine suspends-to-RAM only, on AC,
                # battery, or low battery alike. LidAction is set on AC and
                # battery but not recorded for lowBattery in the live file, so
                # that one's left at plasma-manager's own default rather than
                # guessed at.
                powerdevil = {
                    AC = {
                        powerButtonAction   = "sleep";
                        whenLaptopLidClosed = "turnOffScreen";
                        whenSleepingEnter   = "standby";
                    };
                    battery = {
                        powerButtonAction   = "sleep";
                        whenLaptopLidClosed = "turnOffScreen";
                        whenSleepingEnter   = "standby";
                        # powerdevilrc [Battery][Display]
                        # TurnOffDisplayIdleTimeoutWhenLockedSec=20 -- screen
                        # off 20s after locking, to save battery
                        turnOffDisplay.idleTimeoutWhenLocked = 20;
                    };
                    lowBattery.whenSleepingEnter = "standby";
                };

                # One `input` attrset rather than separate input.keyboard/
                # input.mice/input.touchpads assignments -- statix flags three
                # assignments to the same top-level key as "repeated keys",
                # and the lint ratchet (`just lint`) turns that into a hard
                # failure for anything new. Same reasoning below for `kwin`
                # and `plasmashell` inside `shortcuts`.
                input = {
                    # kxkbrc [Layout] -- both the model and the two xkb options
                    # (ctrl+alt+backspace to kill X, alt as a menu key) are
                    # hand-set, not what a fresh install picks.
                    keyboard = {
                        model = "microsoftinet";
                        options = [
                            "terminate:ctrl_alt_bksp"
                            "altwin:menu"
                        ];
                    };

                    # kcminputrc [Libinput][<vendor>][<product>][<name>]
                    # sections -- vendorId/productId here are the decimal
                    # values kcminputrc itself uses as the group key (matches
                    # plasma-manager's own touchpad example verbatim:
                    # 2321/21128 is 0x911/0x5288). 1133/49738 is the Logitech
                    # G600; 1118/9 is a Microsoft-branded mouse.
                    mice = [
                        {
                            # Gaming mouse: raw/1:1 movement, no acceleration curve.
                            name                = "Logitech Gaming Mouse G600";
                            vendorId            = "1133";
                            productId           = "49738";
                            accelerationProfile = "none";
                        }
                        {
                            # A spare mouse kept configured left-handed; name is
                            # copied verbatim from kcminputrc, leading spaces included.
                            name       = "  Mouse for Windows";
                            vendorId   = "1118";
                            productId  = "9";
                            leftHanded = true;
                        }
                    ];

                    touchpads = [
                        {
                            name         = "HTIX5288:00 0911:5288 Touchpad";
                            vendorId     = "2321";
                            productId    = "21128";
                            pointerSpeed = 0.200;
                        }
                    ];
                };

                shortcuts = {
                    # ── real additions: apps with no upstream default to diff against ──
                    #
                    # vicinae is this repo's own command-runner package
                    # (nirePackages/gui-other/command-runners/vicinae). Its
                    # Meta+Backspace alternate is the exact key kwin's own "Window
                    # Restore" gave up below -- reassigned, not a coincidence.
                    "services/net.local.vicinae.desktop"."_launch" = [
                        "Menu"
                        "Meta+Backspace"
                    ];
                    "services/org.kde.plasma.emojier.desktop"."_launch" = "Meta+.";
                    "services/org.kde.spectacle.desktop"."_launch"      = "Meta+%";

                    # ── real edit: default is "Battery\tMeta+B", live is "Battery"
                    # only -- the Meta+B alternate was dropped, not added.
                    org_kde_powerdevil.powerProfile = "Battery";

                    # ── everything below: default exists, live is unbound (`none`),
                    # except the four called out inline. This is the bulk of the real
                    # customization on this machine -- nearly every stock Meta-based
                    # kwin/plasmashell binding, plus a few elsewhere, explicitly
                    # turned off.
                    "KDE Keyboard Layout Switcher" = {
                        "Switch to Last-Used Keyboard Layout" = [ ];
                        "Switch to Next Keyboard Layout"      = [ ];
                    };

                    kaccess."Toggle Screen Reader On and Off" = [ ];

                    ksmserver."Lock Session" = [ ];

                    kwin = {
                        # real edits: both keep their primary key but drop the
                        # Meta+Tab / Meta+Shift+Tab alternate every other
                        # default in this group also carries
                        "Walk Through Windows"           = "Alt+Tab";
                        "Walk Through Windows (Reverse)" = "Alt+Shift+Tab";

                        "Activate Window Demanding Attention"                   = [ ];
                        "Edit Tiles"                                            = [ ];
                        "Expose"                                                = [ ];
                        "ExposeAll"                                             = [ ];
                        "ExposeClass"                                           = [ ];
                        "Grid View"                                             = [ ];
                        "Kill Window"                                           = [ ];
                        "MoveMouseToCenter"                                     = [ ];
                        "MoveMouseToFocus"                                      = [ ];
                        "Overview"                                              = [ ];
                        "Show Desktop"                                          = [ ];
                        "Suspend Compositing"                                   = [ ];
                        "Switch One Desktop Down"                               = [ ];
                        "Switch One Desktop Up"                                 = [ ];
                        "Switch One Desktop to the Left"                        = [ ];
                        "Switch One Desktop to the Right"                       = [ ];
                        "Switch Window Down"                                    = [ ];
                        "Switch Window Left"                                    = [ ];
                        "Switch Window Right"                                   = [ ];
                        "Switch Window Up"                                      = [ ];
                        "Switch to Desktop 1"                                   = [ ];
                        "Switch to Desktop 2"                                   = [ ];
                        "Switch to Desktop 3"                                   = [ ];
                        "Switch to Desktop 4"                                   = [ ];
                        "Walk Through Windows of Current Application"          = [ ];
                        "Walk Through Windows of Current Application (Reverse)" = [ ];
                        "Window Maximize"                                       = [ ];
                        "Window Minimize"                                       = [ ];
                        "Window One Desktop Down"                               = [ ];
                        "Window One Desktop Up"                                 = [ ];
                        "Window One Desktop to the Left"                        = [ ];
                        "Window One Desktop to the Right"                       = [ ];
                        "Window Operations Menu"                                = [ ];
                        "Window Quick Tile Bottom"                              = [ ];
                        "Window Quick Tile Left"                                = [ ];
                        "Window Quick Tile Right"                               = [ ];
                        "Window Quick Tile Top"                                 = [ ];
                        "Window Restore"                                        = [ ];
                        "Window to Next Screen"                                 = [ ];
                        "Window to Previous Screen"                             = [ ];
                        "disableInputCapture"                                   = [ ];
                        "view_actual_size"                                      = [ ];
                        "view_zoom_in"                                          = [ ];
                        "view_zoom_out"                                         = [ ];
                    };

                    plasmashell = {
                        # real addition: default is unbound, live binds the
                        # app launcher widget to Meta+Space
                        "activate widget 3" = "Meta+Space";

                        "activate application launcher" = [ ];
                        "activate task manager entry 1" = [ ];
                        "activate task manager entry 2" = [ ];
                        "activate task manager entry 3" = [ ];
                        "activate task manager entry 4" = [ ];
                        "activate task manager entry 5" = [ ];
                        "activate task manager entry 6" = [ ];
                        "activate task manager entry 7" = [ ];
                        "activate task manager entry 8" = [ ];
                        "activate task manager entry 9" = [ ];
                        "clipboard_action"               = [ ];
                        "cycle-panels"                    = [ ];
                        "manage activities"               = [ ];
                        "show dashboard"                  = [ ];
                        "stop current activity"           = [ ];
                    };
                };

                # Settings with no typed plasma-manager option -- written straight
                # to the rc files' own [group]/key shape.
                configFile = {
                    # kaccessrc [Keyboard] -- no dedicated plasma-manager module
                    # for accessibility. StickyKeys=true is the standout: sticky
                    # modifier keys, plausibly useful for chording Ctrl/Shift/Alt
                    # on a handheld's cramped keyboard. AccessXBeep and
                    # GestureConfirmation came along with it as one settings
                    # group; no recorded default to diff either against
                    # (kaccessrc doesn't carry one the way kglobalshortcutsrc does).
                    kaccessrc.Keyboard = {
                        AccessXBeep        = false;
                        GestureConfirmation = true;
                        StickyKeys          = true;
                    };

                    kwinrc = {
                        Plugins = {
                            # on-screen indicator when switching virtual desktops
                            desktopchangeosdEnabled = true;
                            # visualize touch input -- worth it on a touchscreen handheld
                            touchpointsEnabled = true;
                            # krohnkite is installed (kde-base.nix) but left off;
                            # explicit rather than relying on the package's own
                            # default
                            krohnkiteEnabled = false;
                        };
                        # alt-tab visual style
                        TabBoxAlternative.LayoutName = "coverswitch";
                        "org.kde.kdecoration2".BorderSizeAuto = false;
                        # HiDPI scaling for XWayland clients on this handheld's
                        # small high-density screen
                        Xwayland.Scale = 1.25;
                    };
                };
            };
        };
}
