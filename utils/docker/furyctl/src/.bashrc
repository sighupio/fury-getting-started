# Prompt
export PS1="\[\e[31m\][\[\e[m\]\[\e[38;5;172m\]\u\[\e[m\]@\[\e[38;5;153m\]\h\[\e[m\] \[\e[38;5;214m\]\W\[\e[m\]\[\e[31m\]]\[\e[m\]\\$ "

# Completion
source /etc/profile.d/bash_completion.sh

# Custom aliases
alias k="kubectl"
alias ll="ls -lart"

# Direnv
eval "$(direnv hook bash)"
