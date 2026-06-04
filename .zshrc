# End of lines configured by zsh-newuser-install
source $HOME/.aliases
source $HOME/.plugin.zsh
source $HOME/.profile
source $HOME/.func.zsh

LOCAL_ALIASES=$HOME/.local_aliases

if [ -f $LOCAL_ALIASES ]; then
    source $LOCAL_ALIASES
fi

autoload -Uz compinit
compinit

# Disable autosuggest async mode to avoid leaking pipe fds (fd exhaustion)
ZSH_AUTOSUGGEST_USE_ASYNC=0

plugins=(
    marlonrichert/zsh-autocomplete
    zsh-users/zsh-completions
    # rupa/z
    ajeetdsouza/zoxide
    zsh-users/zsh-autosuggestions
)

plugin-load $plugins

plugin-load-deferred \
    zdharma-continuum/fast-syntax-highlighting \
    zsh-users/zsh-history-substring-search

eval "$(starship init zsh)"
