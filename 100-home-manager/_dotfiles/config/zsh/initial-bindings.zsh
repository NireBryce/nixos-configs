# Manjaro defaults:
  # Keybindings section
  bindkey -e
  bindkey '^[[7~' beginning-of-line                               # Home key
  bindkey '^[[H' beginning-of-line                                # Home key
  if [[ "${terminfo[khome]}" != "" ]]; then
  bindkey "${terminfo[khome]}" beginning-of-line                # [Home] - Go to beginning of line
  fi
  bindkey '^[[8~' end-of-line                                     # End key
  bindkey '^[[F' end-of-line                                      # End key
  if [[ "${terminfo[kend]}" != "" ]]; then
  bindkey "${terminfo[kend]}" end-of-line                       # [End] - Go to end of line
  fi
  bindkey '^[[2~' overwrite-mode                                  # Insert key
  bindkey '^[[3~' delete-char                                     # Delete key
  bindkey '^[[C'  forward-char                                    # Right key
  bindkey '^[[D'  backward-char                                   # Left key
  bindkey '^[[5~' history-beginning-search-backward               # Page up key
  bindkey '^[[6~' history-beginning-search-forward                # Page down key

  # Navigate words with ctrl+arrow keys
  bindkey '^[Oc' forward-word                                     #
  bindkey '^[Od' backward-word                                    #
  bindkey '^[[1;5D' backward-word                                 #
  bindkey '^[[1;5C' forward-word                                  #
  bindkey '^H' backward-kill-word                                 # delete previous word with ctrl+backspace
  bindkey '^[[Z' undo                                             # Shift+tab undo last action
  
# prezto
  # # Enable fish style features
    # bind UP and DOWN arrow keys to history substring search
    # bindkey "$terminfo[kcuu1]" history-substring-search-up
    # bindkey "$terminfo[kcud1]" history-substring-search-down
    # bindkey '^[[A' history-substring-search-up
    # bindkey '^[[B' history-substring-search-down

# zsh4humans
    'bindkey' '-d'
    'bindkey' '-e'

    'bindkey' '-s' '^[OM'    '^M'
    'bindkey' '-s' '^[Ok'    '+'
    'bindkey' '-s' '^[Om'    '-'
    'bindkey' '-s' '^[Oj'    '*'
    'bindkey' '-s' '^[Oo'    '/'
    'bindkey' '-s' '^[OX'    '='
    'bindkey' '-s' '^[OH'    '^[[H'
    'bindkey' '-s' '^[OF'    '^[[F'
    'bindkey' '-s' '^[OA'    '^[[A'
    'bindkey' '-s' '^[OB'    '^[[B'
    'bindkey' '-s' '^[OD'    '^[[D'
    'bindkey' '-s' '^[OC'    '^[[C'
    'bindkey' '-s' '^[[1~'   '^[[H'
    'bindkey' '-s' '^[[4~'   '^[[F'
    'bindkey' '-s' '^[Od'    '^[[1;5D'
    'bindkey' '-s' '^[Oc'    '^[[1;5C'
    'bindkey' '-s' '^[^[[D'  '^[[1;3D'
    'bindkey' '-s' '^[^[[C'  '^[[1;3C'
    'bindkey' '-s' '^[[7~'   '^[[H'
    'bindkey' '-s' '^[[8~'   '^[[F'
    'bindkey' '-s' '^[[3\^'  '^[[3;5~'
    'bindkey' '-s' '^[^[[3~' '^[[3;3~'
    'bindkey' '-s' '^[[1;9D' '^[[1;3D'
    'bindkey' '-s' '^[[1;9C' '^[[1;3C'
    
    'bindkey' '^[[H'    'beginning-of-line'
    'bindkey' '^[[F'    'end-of-line'
    'bindkey' '^[[3~'   'delete-char'
    'bindkey' '^[[3;5~' 'kill-word'
    'bindkey' '^[[3;3~' 'kill-word'
    'bindkey' '^[k'     'backward-kill-line'
    'bindkey' '^[K'     'backward-kill-line'
    'bindkey' '^[j'     'kill-buffer'
    'bindkey' '^[J'     'kill-buffer'
    'bindkey' '^[/'     'redo'                          # Alt + /
    'bindkey' '^[[1;3D' 'backward-word'
    'bindkey' '^[[1;5D' 'backward-word'
    'bindkey' '^[[1;3C' 'forward-word'
    'bindkey' '^[[1;5C' 'forward-word'
