{ ... }:
{
  programs.fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
        "--inline-info"
        "--color 'fg:#\${vars.colors.base05}'" # Text
        "--color 'bg:#\${vars.colors.base00}'" # Background
        "--color 'preview-fg:#\${vars.colors.base05}'" # Preview window text
        "--color 'preview-bg:#\${vars.colors.base02}'" # Preview window background
        "--color 'hl:#\${vars.colors.base0A}'" # Highlighted substrings
        "--color 'fg+:#\${vars.colors.base0D}'" # Text (current line)
        "--color 'bg+:#\${vars.colors.base02}'" # Background (current line)
        "--color 'gutter:#\${vars.colors.base02}'" # Gutter on the left (defaults to bg+)
        "--color 'hl+:#\${vars.colors.base0E}'" # Highlighted substrings (current line)
        "--color 'info:#\${vars.colors.base0E}'" # Info line (match counters)
        "--color 'border:#\${vars.colors.base0D}'" # Border around the window (--border and --preview)
        "--color 'prompt:#\${vars.colors.base05}'" # Prompt
        "--color 'pointer:#\${vars.colors.base0E}'" # Pointer to the current line
        "--color 'marker:#\${vars.colors.base0E}'" # Multi-select marker
        "--color 'spinner:#\${vars.colors.base0E}'" # Streaming input indicator
        "--color 'header:#\${vars.colors.base05}'" # Header
      ];
  };
}
