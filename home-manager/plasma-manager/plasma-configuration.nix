{
    plasma-manager,
    ...
}:

{
    # `nix run github:nix-community/plasma-manager` to generate a config
  
    # programs.plasma = {
    #     enable = true;
    #     workspace = {
    #         clickItemTo = "select";
    #         lookAndFeel = "org.kde.breezedark.desktop";
    #         # cursor.theme = "";
    #         # iconTheme = "";
    #     };
    
    # hotkeys.commands."launch-konsole" = {
    #     name = "Launch Konsole";
    #     key = "Meta+Alt+K";
    #     command = "konsole";
    # };

    # panels = [
    #   # Windows-like panel at the bottom
    #     {
    #         location = "bottom";
    #         widgets = [
    #             "org.kde.plasma.kickoff"
    #             "org.kde.plasma.icontasks"
    #             "org.kde.plasma.marginsseparator"
    #             "org.kde.plasma.systemtray"
    #             "org.kde.plasma.digitalclock"
    #         ];
    #     }
    #   # Global menu at the top
    #     {
    #         location = "top";
    #         height = 26;
    #         widgets = [ "org.kde.plasma.appmenu" ];
    #     }
    # ];

    # shortcuts = {
    #     ksmserver = {
    #         "Lock Session" = [
    #             "Screensaver"
    #             "Meta+Ctrl+Alt+L"
    #         ];
    # };

    #   kwin = {
    #     "Expose" = "Meta+,";
    #     "Switch Window Down" = "Meta+J";
    #     "Switch Window Left" = "Meta+H";
    #     "Switch Window Right" = "Meta+L";
    #     "Switch Window Up" = "Meta+K";
    #   };
    # };

    #
    # Some low-level settings:
    #
#     configFile = {
#       "baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
#       "baloofilerc"."General"."dbVersion" = 2;
#       "baloofilerc"."General"."exclude filters" = "*~,*.part,*.o,*.la,*.lo,*.loT,*.moc,moc_*.cpp,qrc_*.cpp,ui_*.h,cmake_install.cmake,CMakeCache.txt,CTestTestfile.cmake,libtool,config.status,confdefs.h,autom4te,conftest,confstat,Makefile.am,*.gcode,.ninja_deps,.ninja_log,build.ninja,*.csproj,*.m4,*.rej,*.gmo,*.pc,*.omf,*.aux,*.tmp,*.po,*.vm*,*.nvram,*.rcore,*.swp,*.swap,lzo,litmain.sh,*.orig,.histfile.*,.xsession-errors*,*.map,*.so,*.a,*.db,*.qrc,*.ini,*.init,*.img,*.vdi,*.vbox*,vbox.log,*.qcow2,*.vmdk,*.vhd,*.vhdx,*.sql,*.sql.gz,*.ytdl,*.tfstate*,*.class,*.pyc,*.pyo,*.elc,*.qmlc,*.jsc,*.fastq,*.fq,*.gb,*.fasta,*.fna,*.gbff,*.faa,po,CVS,.svn,.git,_darcs,.bzr,.hg,CMakeFiles,CMakeTmp,CMakeTmpQmake,.moc,.obj,.pch,.uic,.npm,.yarn,.yarn-cache,__pycache__,node_modules,node_packages,nbproject,.terraform,.venv,venv,core-dumps,lost+found";
#       "baloofilerc"."General"."exclude filters version" = 9;
#     };
#   };
}

