# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # android-tools: Android SDK platform tools (adb, fastboot)
        home.packages = with pkgs; [
            android-tools
        ];
    };
}
