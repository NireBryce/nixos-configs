# From manjaro defaults:
  setopt correct                                                  # Auto correct mistakes
  setopt nocaseglob                                               # Case insensitive globbing
  setopt rcexpandparam                                            # Array expension with parameters
  setopt nocheckjobs                                              # Don't warn about running processes when exiting
  setopt numericglobsort                                          # Sort filenames numerically when it makes sense
  setopt nobeep                                                   # No beep
  setopt appendhistory                                            # Immediately append history instead of overwriting
  setopt histignorealldups                                        # If a new command is a duplicate, remove the older one
  setopt autocd                                                   # if only directory path is entered, cd there.
  setopt inc_append_history                                       # save commands are added to the history immediately, otherwise only when shell exits.
  setopt histignorespace                                          # Don't save commands that start with space
  # setopt extendedglob                                             # Extended globbing. Allows using regular expressions with *
  
# Prezto
  setopt COMPLETE_IN_WORD                                         # Complete from both ends of a word.
  setopt ALWAYS_TO_END                                            # Move cursor to the end of a completed word.
  setopt PATH_DIRS                                                # Perform path search even on command names with slashes.
  setopt AUTO_MENU                                                # Show completion menu on a successive tab press.
  setopt AUTO_LIST                                                # Automatically list choices on ambiguous completion.
  setopt AUTO_PARAM_SLASH                                         # If completed parameter is a directory, add a trailing slash.
  setopt EXTENDED_GLOB                                            # Needed for file modification glob modifiers with compinit.
  setopt extendedglob #belt and suspenders

# grabbed from zsh4humans
  setopt glob_dots
  setopt globdots #belt and suspenders                            # no special treatment for file names with a leading dot
  # setopt no_auto_menu                                             # require an extra TAB press to open the completion menu
  unsetopt MENU_COMPLETE                                          # Do not autoselect the first completion entry.
  unsetopt FLOW_CONTROL                                           # Disable start/stop characters in shell editor.
