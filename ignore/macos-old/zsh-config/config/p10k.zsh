#! /usr/bin/env zsh
#TODO: p10k is abandoned, look into starship.  Stop caring about your prompt, you need agility-of-deploys and to have less darlings
# Enable Powerlevel10k instant prompt. 
  # Should stay close to the top of ~/.zshrc.
  # Initialization code that may require console input (password prompts, [y/n]
  # confirmations, etc.) must go above this block; everything else may go below.
    if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
        source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
    fi
