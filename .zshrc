# End of lines configured by zsh-newuser-install
source $HOME/.aliases
source $HOME/.plugin.zsh

plugins=(
    zsh-users/zsh-completions
    rupa/z

    zdharma-continuum/fast-syntax-highlighting
    zsh-users/zsh-history-substring-search
    zsh-users/zsh-autosuggestions
)

plugin-load $plugins

eval "$(starship init zsh)"

