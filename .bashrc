#
# ~/.bashrc
#
alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
PATH=$PATH
systemctl --user enable backup.timer
alias vpn='sudo openconnect -u thrl --authgroup TU-Chemnitz https://vpngate.hrz.tu-chemnitz.de/'
alias install='bash ~/.NixOS/rebuild.sh'
