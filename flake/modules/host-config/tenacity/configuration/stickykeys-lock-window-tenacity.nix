# Sticky keys that tell a deliberate double-tap from a later second press.
#
# Upstream kwin locks a latched modifier on any second press, however long
# after the first (6.7.5 src/plugins/stickykeys/stickykeys.cpp, "A latched
# modifier was pressed, lock it"). stickykeys-lock-window.patch adds
# StickyKeysLockWindow to kaccessrc [Keyboard]: milliseconds within which a
# second press still locks; after the window it unlatches instead. 0 is
# upstream behavior. The key itself is set in plasma-tenacity.nix, next to
# StickyKeys=true.
#
# Only the plugin is rebuilt, never kwin. The patched source is compiled
# out-of-tree against the stock kwin's installed headers and libkwin, as a
# plugin with its own id (StickyKeysLockWindowPlugin), and the stock
# StickyKeysPlugin is switched off in kwinrc. Patching kwin itself -- the
# first version of this, an overrideScope overlay in kde-base.nix --
# changed kwin's hash and so every kdePackages member built against it
# (plasma-workspace, plasma-desktop, powerdevil, ...), none of them in the
# binary cache: a local rebuild of most of Plasma on every nixpkgs bump.
#
# Why a new id rather than a same-named replacement: kwin's PluginManager
# (src/pluginmanager.cpp) loads the FIRST plugin found per id and skips later
# duplicates, and kwin_wayland's own Qt wrapper prefixes kwin's plugin dir
# to QT_PLUGIN_PATH ahead of anything the session adds -- a same-named copy
# would always lose to the stock one. Both toggles below must stay together:
# with the stock plugin still on, two sticky-keys filters see every key.
#
# The patch is written against kwin 6.7.5; a kwin bump that moves its hunk
# fails this build loudly rather than silently dropping the feature. The
# plugin links the stock kwin's libkwin by store path, so a kwin bump
# rebuilds it (seconds) against the matching headers.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }:
            let
                kp = pkgs.kdePackages;

                stickykeysLockWindow = pkgs.stdenv.mkDerivation {
                    pname = "kwin-stickykeys-lock-window";
                    inherit (kp.kwin) version src;
                    patches = [ ./stickykeys-lock-window.patch ];

                    # Replaces the plugin's in-tree CMakeLists (which assumes
                    # kwin's own build: the `kwin` target, kwin's compiler
                    # settings) with a standalone one against the installed
                    # KWin package. CXX_STANDARD matches kwin's top-level
                    # CMakeLists; its headers need C++20 or later.
                    postPatch = ''
                        cd src/plugins/stickykeys
                        cat > CMakeLists.txt <<'EOF'
                        cmake_minimum_required(VERSION 3.16)
                        project(StickyKeysLockWindow CXX)
                        set(CMAKE_CXX_STANDARD 23)
                        set(CMAKE_CXX_STANDARD_REQUIRED ON)
                        find_package(ECM REQUIRED NO_MODULE)
                        set(CMAKE_MODULE_PATH ''${ECM_MODULE_PATH})
                        include(KDEInstallDirs)
                        include(KDECMakeSettings)
                        include(KDECompilerSettings NO_POLICY_SCOPE)
                        include(ECMQtDeclareLoggingCategory)
                        find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)
                        find_package(KWin REQUIRED)
                        find_package(KF6 REQUIRED COMPONENTS CoreAddons WindowSystem I18n Notifications)
                        find_package(XKB REQUIRED)
                        set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ''${CMAKE_BINARY_DIR}/bin)
                        kcoreaddons_add_plugin(StickyKeysLockWindowPlugin INSTALL_NAMESPACE "kwin/plugins")
                        ecm_qt_declare_logging_category(StickyKeysLockWindowPlugin
                            HEADER stickykeys_debug.h
                            IDENTIFIER KWIN_STICKYKEYS
                            CATEGORY_NAME kwin_stickykeys
                            DEFAULT_SEVERITY Warning
                        )
                        target_sources(StickyKeysLockWindowPlugin PRIVATE main.cpp stickykeys.cpp)
                        target_link_libraries(StickyKeysLockWindowPlugin PRIVATE KWin::kwin KF6::WindowSystem KF6::I18n KF6::Notifications XKB::XKB)
                        EOF
                    '';

                    nativeBuildInputs = with pkgs; [ cmake ninja pkg-config kp.extra-cmake-modules kp.qtbase.dev ];
                    buildInputs       = with pkgs; [ kp.kwin kp.kcoreaddons kp.kwindowsystem kp.ki18n kp.knotifications libxkbcommon ];
                    dontWrapQtApps    = true; # a plugin, nothing to wrap
                };
            in {
                # # description = "sticky keys lock only on a quick double-tap: patched kwin plugin, built alone"

                # lib/qt-6/plugins of the per-user profile is on the session's
                # QT_PLUGIN_PATH, where kwin's plugin search finds it.
                home.packages = [ stickykeysLockWindow ];

                programs.plasma.configFile.kwinrc.Plugins = {
                    StickyKeysPluginEnabled           = false;
                    StickyKeysLockWindowPluginEnabled = true;
                };
            };
}
