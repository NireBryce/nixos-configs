# {
#     plasma-manager,
#     ...
# }:

# {
#     # `nix run github:nix-community/plasma-manager` to generate a config
  
#     # programs.plasma = {
#     #     enable = true;
#     #     workspace = {
#     #         clickItemTo = "select";
#     #         lookAndFeel = "org.kde.breezedark.desktop";
#     #         # cursor.theme = "";
#     #         # iconTheme = "";
#     #     };
    
#     # hotkeys.commands."launch-konsole" = {
#     #     name = "Launch Konsole";
#     #     key = "Meta+Alt+K";
#     #     command = "konsole";
#     # };

#     # panels = [
#     #   # Windows-like panel at the bottom
#     #     {
#     #         location = "bottom";
#     #         widgets = [
#     #             "org.kde.plasma.kickoff"
#     #             "org.kde.plasma.icontasks"
#     #             "org.kde.plasma.marginsseparator"
#     #             "org.kde.plasma.systemtray"
#     #             "org.kde.plasma.digitalclock"
#     #         ];
#     #     }
#     #   # Global menu at the top
#     #     {
#     #         location = "top";
#     #         height = 26;
#     #         widgets = [ "org.kde.plasma.appmenu" ];
#     #     }
#     # ];

#     # shortcuts = {
#     #     ksmserver = {
#     #         "Lock Session" = [
#     #             "Screensaver"
#     #             "Meta+Ctrl+Alt+L"
#     #         ];
#     # };

#     #   kwin = {
#     #     "Expose" = "Meta+,";
#     #     "Switch Window Down" = "Meta+J";
#     #     "Switch Window Left" = "Meta+H";
#     #     "Switch Window Right" = "Meta+L";
#     #     "Switch Window Up" = "Meta+K";
#     #   };
#     # };

#     #
#     # Some low-level settings:
#     #
# #     configFile = {
# #       "baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
# #       "baloofilerc"."General"."dbVersion" = 2;
# #       "baloofilerc"."General"."exclude filters" = "*~,*.part,*.o,*.la,*.lo,*.loT,*.moc,moc_*.cpp,qrc_*.cpp,ui_*.h,cmake_install.cmake,CMakeCache.txt,CTestTestfile.cmake,libtool,config.status,confdefs.h,autom4te,conftest,confstat,Makefile.am,*.gcode,.ninja_deps,.ninja_log,build.ninja,*.csproj,*.m4,*.rej,*.gmo,*.pc,*.omf,*.aux,*.tmp,*.po,*.vm*,*.nvram,*.rcore,*.swp,*.swap,lzo,litmain.sh,*.orig,.histfile.*,.xsession-errors*,*.map,*.so,*.a,*.db,*.qrc,*.ini,*.init,*.img,*.vdi,*.vbox*,vbox.log,*.qcow2,*.vmdk,*.vhd,*.vhdx,*.sql,*.sql.gz,*.ytdl,*.tfstate*,*.class,*.pyc,*.pyo,*.elc,*.qmlc,*.jsc,*.fastq,*.fq,*.gb,*.fasta,*.fna,*.gbff,*.faa,po,CVS,.svn,.git,_darcs,.bzr,.hg,CMakeFiles,CMakeTmp,CMakeTmpQmake,.moc,.obj,.pch,.uic,.npm,.yarn,.yarn-cache,__pycache__,node_modules,node_packages,nbproject,.terraform,.venv,venv,core-dumps,lost+found";
# #       "baloofilerc"."General"."exclude filters version" = 9;
# #     };
# #   };
#   programs.plasma = {
#     enable = true;
#     shortcuts = {
#       # empty entries unbind
#       ActivityManager = { 
#         "switch-to-activity-daf90919-d39f-4c34-b74a-19645ebad89a" 
#           = [ ];
#       };
#       "KDE Keyboard Layout Switcher" = {
#         "Switch to Last-Used Keyboard Layout" 
#           = "none,Meta+Alt+L,Switch to Last-Used Keyboard Layout";
#         "Switch to Next Keyboard Layout" 
#           = "none,Meta+Alt+K,Switch to Next Keyboard Layout";
#       };
#       kaccess = {
#         "Toggle Screen Reader On and Off" 
#         = "none,Meta+Alt+S,Toggle Screen Reader On and Off";
#       };
#       kcm_touchpad = {
#         "Disable Touchpad" = "Touchpad Off";
#         "Enable Touchpad" = "Touchpad On";
#         "Toggle Touchpad" = ["Touchpad Toggle,Touchpad Toggle" "Touchpad Toggle" "Meta+Ctrl+Touchpad Toggle" "Meta+Ctrl+Zenkaku Hankaku,Toggle Touchpad"];
#       };
#       kwin = {
#         "Activate Window Demanding Attention" 
#           = "Meta+Ctrl+A";
        
#         "Cycle Overview" 
#           = [ ];
#         "Cycle Overview Opposite" 
#           = [ ];
        
#         "Decrease Opacity" 
#           = "none,,Decrease Opacity of Active Window by 5%";
        
#         "Expose" 
#           = "Meta+Alt+Down,Ctrl+F9,Toggle Present Windows (Current desktop)";
#         "ExposeAll" 
#           = ["Ctrl+F10,Ctrl+F10" "Launch (C),Toggle Present Windows (All desktops)"];
        
#         "Edit Tiles" 
#           = "none,Meta+T,Toggle Tiles Editor";
        
#         "ExposeClass" 
#           = "Ctrl+F7";
#         "ExposeClassCurrentDesktop" 
#           = [ ];

#         "Grid View" 
#           = "none,Meta+G,Toggle Grid View";

#         "Increase Opacity" 
#           = "none,,Increase Opacity of Active Window by 5%";
#         "Kill Window" 
#           = "Meta+Ctrl+Esc";
#         "Move Tablet to Next Output" 
#           = [ ];
#         "MoveMouseToCenter" 
#           = "none,Meta+F6,Move Mouse to Center";
#         "MoveMouseToFocus" 
#           = "none,Meta+F5,Move Mouse to Focus";
#         "MoveZoomDown"  
#          =  [ ];
#         "MoveZoomLeft"  
#          =  [ ];
#         "MoveZoomRight"  
#           = [ ];
#         "MoveZoomUp" 
#           = [ ];
#         "Overview" 
#           = "Meta+Alt+Up,Meta+W,Toggle Overview";
#         "Setup Window Shortcut" 
#           = "none,,Setup Window Shortcut";
#         "Show Desktop" 
#           = "Meta+D";
#         "Suspend Compositing" 
#           = "none,Alt+Shift+F12,Suspend Compositing";
#         "Switch One Desktop Down" 
#           = "none,Meta+Ctrl+Down,Switch One Desktop Down";
#         "Switch One Desktop Up" 
#           = "none,Meta+Ctrl+Up,Switch One Desktop Up";
#         "Switch One Desktop to the Left" 
#           = "none,Meta+Ctrl+Left,Switch One Desktop to the Left";
#         "Switch One Desktop to the Right" 
#           = "none,Meta+Ctrl+Right,Switch One Desktop to the Right";
#         "Switch Window Down" 
#           = "none,Meta+Alt+Down,Switch to Window Below";
#         "Switch Window Left" 
#           = "none,Meta+Alt+Left,Switch to Window to the Left";
#         "Switch Window Right" 
#           = "none,Meta+Alt+Right,Switch to Window to the Right";
#         "Switch Window Up" 
#           = "none,Meta+Alt+Up,Switch to Window Above";
#         "Switch to Desktop 1" 
#           = "none,Ctrl+F1,Switch to Desktop 1";
#         "Switch to Desktop 10" 
#           = "none,,Switch to Desktop 10";
#         "Switch to Desktop 11" 
#           = "none,,Switch to Desktop 11";
#         "Switch to Desktop 12" 
#           = "none,,Switch to Desktop 12";
#         "Switch to Desktop 13" 
#           = "none,,Switch to Desktop 13";
#         "Switch to Desktop 14" 
#           = "none,,Switch to Desktop 14";
#         "Switch to Desktop 15" 
#           = "none,,Switch to Desktop 15";
#         "Switch to Desktop 16" 
#           = "none,,Switch to Desktop 16";
#         "Switch to Desktop 17" 
#           = "none,,Switch to Desktop 17";
#         "Switch to Desktop 18" 
#           = "none,,Switch to Desktop 18";
#         "Switch to Desktop 19" 
#           = "none,,Switch to Desktop 19";
#         "Switch to Desktop 2" 
#           = "none,Ctrl+F2,Switch to Desktop 2";
#         "Switch to Desktop 20" 
#           = "none,,Switch to Desktop 20";
#         "Switch to Desktop 3" 
#           = "none,Ctrl+F3,Switch to Desktop 3";
#         "Switch to Desktop 4" 
#           = "none,Ctrl+F4,Switch to Desktop 4";
#         "Switch to Desktop 5" 
#           = "none,,Switch to Desktop 5";
#         "Switch to Desktop 6" 
#           = "none,,Switch to Desktop 6";
#         "Switch to Desktop 7" 
#           = "none,,Switch to Desktop 7";
#         "Switch to Desktop 8" 
#           = "none,,Switch to Desktop 8";
#         "Switch to Desktop 9" 
#           = "none,,Switch to Desktop 9";
        
        
#         "Switch to Next Desktop" 
#           = "Meta+Alt+Right,,Switch to Next Desktop";
#         "Switch to Next Screen" 
#           = "none,,Switch to Next Screen";
#         "Switch to Previous Desktop" 
#           = "Meta+Alt+Left,,Switch to Previous Desktop";
#         "Switch to Previous Screen" 
#           = "none,,Switch to Previous Screen";
        
        
#         "Switch to Screen 0" 
#           = "none,,Switch to Screen 0";
#         "Switch to Screen 1" 
#           = "none,,Switch to Screen 1";
#         "Switch to Screen 2" 
#           = "none,,Switch to Screen 2";
#         "Switch to Screen 3" 
#           = "none,,Switch to Screen 3";
#         "Switch to Screen 4" 
#           = "none,,Switch to Screen 4";
#         "Switch to Screen 5" 
#           = "none,,Switch to Screen 5";
#         "Switch to Screen 6" 
#           = "none,,Switch to Screen 6";
#         "Switch to Screen 7" 
#           = "none,,Switch to Screen 7";
#         "Switch to Screen Above" 
#           = "none,,Switch to Screen Above";
#         "Switch to Screen Below" 
#           = "none,,Switch to Screen Below";
#         "Switch to Screen to the Left" 
#           = "none,,Switch to Screen to the Left";
#         "Switch to Screen to the Right" 
#           = "none,,Switch to Screen to the Right";

#         "Toggle Night Color" 
#           = [ ];
        
#         "Toggle Window Raise/Lower" 
#           = "none,,Toggle Window Raise/Lower";
        
#         "Walk Through Windows" 
#           = "Alt+Tab";
#         "Walk Through Windows (Reverse)" 
#           = "Alt+Shift+Tab";
#         "Walk Through Windows Alternative" 
#           = "none,,Walk Through Windows Alternative";
#         "Walk Through Windows Alternative (Reverse)" 
#           = "none,,Walk Through Windows Alternative (Reverse)";
#         "Walk Through Windows of Current Application" 
#           = "Alt+`";
#         "Walk Through Windows of Current Application (Reverse)" 
#           = "Alt+~";
#         "Walk Through Windows of Current Application Alternative" 
#           = "none,,Walk Through Windows of Current Application Alternative";
#         "Walk Through Windows of Current Application Alternative (Reverse)" 
#           = "none,,Walk Through Windows of Current Application Alternative (Reverse)";
        
#         "Window Above Other Windows" 
#           = "none,,Keep Window Above Others";
#         "Window Below Other Windows" 
#           = "none,,Keep Window Below Others";
        
#         "Window Close" 
#           = "Alt+F4";
#         "Window Minimize" 
#           = "Meta+PgDown";
#         "Window Maximize" 
#           = "Meta+PgUp";
#         "Window Fullscreen"
#           = "none,,Make Window Fullscreen";
#         "Window Grow Horizontal"
#           = "none,,Expand Window Horizontally";
#         "Window Grow Vertical"
#           = "none,,Expand Window Vertically";
#         "Window Maximize Horizontal" 
#           = "none,,Maximize Window Horizontally";
#         "Window Maximize Vertical" 
#           = "none,,Maximize Window Vertically";
#         "Window Lower"
#           = "none,,Lower Window";

#         "Window Move" 
#           = "none,,Move Window";
#         "Window Move Center" 
#           = "none,,Move Window to the Center";
        
#         "Window Custom Quick Tile Bottom"
#           = "none,,Custom Quick Tile Window to the Bottom";
#         "Window Custom Quick Tile Left"
#           = "none,,Custom Quick Tile Window to the Left";
#         "Window Custom Quick Tile Right"
#           = "none,,Custom Quick Tile Window to the Right";
#         "Window Custom Quick Tile Top"
#           = "none,,Custom Quick Tile Window to the Top";
#         "Window Quick Tile Bottom" 
#           = "Meta+Down";
#         "Window Quick Tile Bottom Left" 
#           = "none,,Quick Tile Window to the Bottom Left";
#         "Window Quick Tile Bottom Right" 
#           = "none,,Quick Tile Window to the Bottom Right";
#         "Window Quick Tile Left"
#           = "Meta+Left";
#         "Window Quick Tile Right" 
#           = "Meta+Right";
#         "Window Quick Tile Top"
#           = "Meta+Up";
#         "Window Quick Tile Top Left" 
#           = "none,,Quick Tile Window to the Top Left";
#         "Window Quick Tile Top Right"
#           = "none,,Quick Tile Window to the Top Right";

#         "Window No Border" 
#           = "none,,Toggle Window Titlebar and Frame";

#         "Window On All Desktops" 
#           = "none,,Keep Window on All Desktops";
#         "Window One Desktop Down" 
#           = "none,Meta+Ctrl+Shift+Down,Window One Desktop Down";
#         "Window One Desktop Up" 
#           = "none,Meta+Ctrl+Shift+Up,Window One Desktop Up";
#         "Window One Desktop to the Left" 
#           = "none,Meta+Ctrl+Shift+Left,Window One Desktop to the Left";
#         "Window One Desktop to the Right" 
#           = "none,Meta+Ctrl+Shift+Right,Window One Desktop to the Right";
#         "Window One Screen Down" 
#           = "none,,Move Window One Screen Down";
#         "Window One Screen Up" 
#           = "none,,Move Window One Screen Up";
#         "Window One Screen to the Left" 
#           = "none,,Move Window One Screen to the Left";
#         "Window One Screen to the Right" 
#           = "none,,Move Window One Screen to the Right";

#         "Window Operations Menu" 
#           = "Alt+F3";

#         "Window Raise" 
#           = "none,,Raise Window";
#         "Window Resize" 
#           = "none,,Resize Window";
#         "Window Shade"
#           = "none,,Shade Window";

#         "Window to Desktop 1" 
#           = "none,,Window to Desktop 1";
#         "Window to Desktop 10" 
#           = "none,,Window to Desktop 10";
#         "Window to Desktop 11" 
#           = "none,,Window to Desktop 11";
#         "Window to Desktop 12" 
#           = "none,,Window to Desktop 12";
#         "Window to Desktop 13" 
#           = "none,,Window to Desktop 13";
#         "Window to Desktop 14" 
#           = "none,,Window to Desktop 14";
#         "Window to Desktop 15" 
#           = "none,,Window to Desktop 15";
#         "Window to Desktop 16" 
#           = "none,,Window to Desktop 16";
#         "Window to Desktop 17" 
#           = "none,,Window to Desktop 17";
#         "Window to Desktop 18" 
#           = "none,,Window to Desktop 18";
#         "Window to Desktop 19" 
#           = "none,,Window to Desktop 19";
#         "Window to Desktop 2" 
#           = "none,,Window to Desktop 2";
#         "Window to Desktop 20" 
#           = "none,,Window to Desktop 20";
#         "Window to Desktop 3" 
#           = "none,,Window to Desktop 3";
#         "Window to Desktop 4" 
#           = "none,,Window to Desktop 4";
#         "Window to Desktop 5" 
#           = "none,,Window to Desktop 5";
#         "Window to Desktop 6" 
#           = "none,,Window to Desktop 6";
#         "Window to Desktop 7" 
#           = "none,,Window to Desktop 7";
#         "Window to Desktop 8" 
#           = "none,,Window to Desktop 8";
#         "Window to Desktop 9" 
#           = "none,,Window to Desktop 9";

#         "Window to Next Desktop"
#           = "Meta+Ctrl+Alt+Right,,Window to Next Desktop";
#         "Window to Previous Desktop" 
#           = "Meta+Ctrl+Alt+Left,,Window to Previous Desktop";
#         "Window to Next Screen"
#           = "Meta+Shift+Right";
#         "Window to Previous Screen"
#           = "Meta+Shift+Left";

#         "disableInputCapture"
#           = "none,Meta+Shift+Esc,Disable Active Input Capture";
#         "view_actual_size"
#           = "Meta+0";
#         "view_zoom_in"
#           = ["Meta++" "Meta+=,Meta++" "Meta+=,Zoom In"];
#         "view_zoom_out" 
#           = "Meta+-";
      
#       };
#       plasmashell = {
#         "activate application launcher" 
#           = ["Meta+Space,Meta" "Alt+F1,Activate Application Launcher"];
        
#         "activate task manager entry 1" 
#           = "none,Meta+1,Activate Task Manager Entry 1";
#         "activate task manager entry 2" 
#           = "none,Meta+2,Activate Task Manager Entry 2";
#         "activate task manager entry 3" 
#         = "none,Meta+3,Activate Task Manager Entry 3";
#         "activate task manager entry 4"
#          = "none,Meta+4,Activate Task Manager Entry 4";
#         "activate task manager entry 5"
#          = "none,Meta+5,Activate Task Manager Entry 5";
#         "activate task manager entry 6"
#          = "none,Meta+6,Activate Task Manager Entry 6";
#         "activate task manager entry 7"
#          = "none,Meta+7,Activate Task Manager Entry 7";
#         "activate task manager entry 8" 
#           = "none,Meta+8,Activate Task Manager Entry 8";
#         "activate task manager entry 9" 
#           = "none,Meta+9,Activate Task Manager Entry 9";
#         "activate task manager entry 10" 
#           = "none,,Activate Task Manager Entry 10";
        
#         "clear-history"
#           = "none,,Clear Clipboard History";
#         "clipboard_action" = "none,Meta+Ctrl+X,Automatic Action Popup Menu";
#         "cycle-panels"
#           = "none,Meta+Alt+P,Move keyboard focus between panels";
#         "cycleNextAction"
#          = "none,,Next History Item";
#         "cyclePrevAction"
#          = "none,,Previous History Item";
#         "manage activities"
#          = "Meta+Q";
#         "next activity"
#          = [ ];
#         "previous activity"
#          = [ ];
#         "repeat_action"
#          = "none,,Manually Invoke Action on Current Clipboard";
#         "show dashboard"
#          = "none,Ctrl+F12,Show Desktop";
#         "show-barcode" 
#           = "none,,Show Barcode…";
#         "show-on-mouse-pos"
#           = "Meta+V";
#         "stop current activity"
#           = "none,Meta+S,Stop Current Activity";
#         "switch to next activity"
#           = "none,,Switch to Next Activity";
#         "switch to previous activity"
#           = "none,,Switch to Previous Activity";
#         "toggle do not disturb"
#           = "none,,Toggle do not disturb";
#       };
      
#       "services/org.kde.dolphin.desktop"."_launch" 
#           = [ ];
#       "services/org.kde.konsole.desktop"."_launch" 
#           = [ ];
#       "services/org.kde.krunner.desktop"."_launch" 
#           = "Alt+Space";
#       "services/org.kde.kscreen.desktop"."ShowOSD" 
#           = [ ];
#       "services/org.kde.plasma-systemmonitor.desktop"."_launch" 
#           = [ ];
#       "services/org.kde.spectacle.desktop"."ActiveWindowScreenShot"
#           = [ ];
#       "services/org.kde.spectacle.desktop"."FullScreenScreenShot"
#           = [ ];
#       "services/org.kde.spectacle.desktop"."RecordRegion"
#           = [ ];
#       "services/org.kde.spectacle.desktop"."RecordScreen"
#           = [ ];
#       "services/org.kde.spectacle.desktop"."RecordWindow"
#           = [ ];
#       "services/org.kde.spectacle.desktop"."RectangularRegionScreenShot"
#           = [ ];
#       "services/org.kde.spectacle.desktop"."WindowUnderCursorScreenShot"
#           = [ ];
#       "services/org.kde.spectacle.desktop"."_launch"
#           = "Meta+%";
#       "services/systemsettings.desktop"."_launch"
#           = "Meta+";
#     };
#     configFile = {
#       "baloofilerc"."General"."dbVersion" = 2;
#       "baloofilerc"."General"."exclude filters" = "*~,*.part,*.o,*.la,*.lo,*.loT,*.moc,moc_*.cpp,qrc_*.cpp,ui_*.h,cmake_install.cmake,CMakeCache.txt,CTestTestfile.cmake,libtool,config.status,confdefs.h,autom4te,conftest,confstat,Makefile.am,*.gcode,.ninja_deps,.ninja_log,build.ninja,*.csproj,*.m4,*.rej,*.gmo,*.pc,*.omf,*.aux,*.tmp,*.po,*.vm*,*.nvram,*.rcore,*.swp,*.swap,lzo,litmain.sh,*.orig,.histfile.*,.xsession-errors*,*.map,*.so,*.a,*.db,*.qrc,*.ini,*.init,*.img,*.vdi,*.vbox*,vbox.log,*.qcow2,*.vmdk,*.vhd,*.vhdx,*.sql,*.sql.gz,*.ytdl,*.tfstate*,*.class,*.pyc,*.pyo,*.elc,*.qmlc,*.jsc,*.fastq,*.fq,*.gb,*.fasta,*.fna,*.gbff,*.faa,po,CVS,.svn,.git,_darcs,.bzr,.hg,CMakeFiles,CMakeTmp,CMakeTmpQmake,.moc,.obj,.pch,.uic,.npm,.yarn,.yarn-cache,__pycache__,node_modules,node_packages,nbproject,.terraform,.venv,venv,core-dumps,lost+found";
#       "baloofilerc"."General"."exclude filters version" = 9;
      
#       "kded5rc"."Module-browserintegrationreminder"."autoload" = false;
#       "kded5rc"."Module-device_automounter"."autoload" = false;
      
#       "kdeglobals"."General"."UseSystemBell" = true;

#       "kdeglobals"."Shortcuts"."OpenContextMenu" = "Shift+F10";

#       "krunnerrc"
#         ."General"
#         ."ActivateWhenTypingOnDesktop"      = false;
#       "krunnerrc"
#         ."Plugins"
#         ."browserhistoryEnabled"            = false;
#       "krunnerrc"
#         ."Plugins"
#         ."browsertabsEnabled"               = false;
#       "krunnerrc"
#         ."Plugins"
#         ."krunner_appstreamEnabled"         = false;
#       "krunnerrc"
#         ."Plugins"
#         ."krunner_bookmarksrunnerEnabled"   = false;
#       "krunnerrc"
#         ."Plugins"
#         ."krunner_katesessionsEnabled"      = false;
#       "krunnerrc"
#         ."Plugins"
#         ."krunner_konsoleprofilesEnabled"   = false;
#       "krunnerrc"
#         ."Plugins"
#         ."krunner_sessionsEnabled"          = false;
#       "krunnerrc"
#         ."Plugins"
#         ."krunner_spellcheckEnabled"        = false;
      
#       "kscreenlockerrc"."Daemon"."LockGrace" = 0;
      
#       "kwinrc"."Desktops"."Id_1" = "b80c9d00-b12c-4ac9-810a-1334c6e24246";
#       "kwinrc"."Desktops"."Id_2" = "4187c3d7-6d92-4fcc-ac46-a2b149721ea5";
#       "kwinrc"."Desktops"."Id_3" = "703cf698-d01a-4861-a689-06b0a916f760";
#       "kwinrc"."Desktops"."Id_4" = "cb88ee92-44b6-431a-8873-632f066cf11f";
#       "kwinrc"."Desktops"."Number" = 4;
#       "kwinrc"."Desktops"."Rows" = 2;
#       "kwinrc"."Plugins"."desktopchangeosdEnabled" = true;
#       "kwinrc"."Plugins"."touchpointsEnabled" = true;
#       "kwinrc"."TabBoxAlternative"."LayoutName" = "coverswitch";

#       "kxkbrc"."Layout"."Options" = "terminate:ctrl_alt_bksp";


#       "plasma-localerc"."Formats"."LANG" = "en_US.UTF-8";
#       "plasmanotifyrc"."Notifications"."NormalAlwaysOnTop" = true;
#       "plasmanotifyrc"."Notifications"."PopupPosition" = "TopLeft";
#     };
#     dataFile = {

#     };
#   };

# }

