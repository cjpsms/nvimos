[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ $(tty) == "/dev/tty1" ]]; then
    ~/.automated_script.sh
fi
