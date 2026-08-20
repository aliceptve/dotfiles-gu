
if command -v vim &>/dev/null; then
  export EDITOR=vim
else
  export EDITOR=nano
fi

export LESS='-R'

export COLORTERM=truecolor

export CLICOLOR=1

GREP_COLORS="ms=01;35:mc=01;35:sl=:cx=:fn=01;34:ln=33:bn=32:se=36"

LSCOLORS=gxfxcxdxbxegedabagacad

# alias la='ls -lAhG'
alias lrt='ls -lrt'
# alias ll='ls -lG'
alias lah='ls -lAhG'
alias lg='ls -lAG |grep '
alias l.='ls -ltrdph .*'

alias json='python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin), sort_keys=True, indent=2))"'

alias ml='mise list -c'

alias ri="rm -i"
alias rr="rm -ir"

alias mv="mv -i"

alias ll='ls -ltrph'
alias la='ls -ltraph'

alias vi='vim'

bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

function hex2rgb() {
  local hex=$1
  printf "%d %d %d\n" 0x${hex:0:2} 0x${hex:2:2} 0x${hex:4:2}
}

function rgb2hex() {
  printf "%02x%02x%02x\n" $1 $2 $3
}

alias superclean='find . -name target -exec rm -r {} \;'

function dsh() {
  if [ -z "$1" ]; then
    echo "Error: Please provide a devcontainer name."
    echo "Usage: ds <container_name>"
    return 1
  fi
  local name=$1
  docker exec -it -u vscode "$name" bash
}

# GIT helpers
alias gatus='git status -sb'
alias gadd='git add'
alias gommit='git commit'
alias giff='git diff'
alias giffw='git diff --word-diff=color'
alias giffc='git diff --cached'
alias gpoh='git push origin HEAD'
alias gitff='git merge --ff-only'
alias gitffom='git merge --ff-only origin/main'

function gog()
{
  git log --pretty=format:'%Cblue%h%Creset%x09%Cgreen(%ad)%x09%C(bold blue)<%an>%Creset%x09%C(yellow)%d%Creset %s' --date=iso --abbr\
ev-commit $*
}

function granch()
{
  for k in `git branch $*|grep -v "HEAD \->"|grep -v "(no branch)"|sed s/^..//`;do echo -e `git log -1 --pretty=format:"%Cgreen%ci %C(bold blue)%cr%Creset" "$k"`\\t"$k";done | sort | column -s $'\t' -t
}

function cu {
  if [ $# -eq 0 ]; then
	cd ../
  else
	cd `yes "../" |head -n$1 | perl -ne 'chomp and print'`
  fi
}
