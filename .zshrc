# End of lines configured by zsh-newuser-install
source $HOME/.aliases
source $HOME/.plugin.zsh
source $HOME/.profile

LOCAL_ALIASES=$HOME/.local_aliases

if [ -f $LOCAL_ALIASES ]; then
    source $LOCAL_ALIASES
fi

plugins=(
    # marlonrichert/zsh-autocomplete
    zsh-users/zsh-completions
    # rupa/z
    ajeetdsouza/zoxide

    zdharma-continuum/fast-syntax-highlighting
    zsh-users/zsh-history-substring-search
    zsh-users/zsh-autosuggestions
)

plugin-load $plugins

eval "$(starship init zsh)"

autoload -Uz compinit
compinit
