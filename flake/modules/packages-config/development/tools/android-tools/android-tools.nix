# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # android-tools: Android SDK platform tools (adb, fastboot)
        home.packages = with pkgs; [
            android-tools
        ];
    };
}
