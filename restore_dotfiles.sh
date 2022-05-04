#!/usr/bin/bash

git clone --bare https://github.com/Bai-Chiang/dotfiles.git $HOME/.dotfiles

function dotfiles {
   /usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME $@
}

# delete conflicted files
dotfiles checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} rm {}

dotfiles checkout

dotfiles config --local status.showUntrackedFiles no
