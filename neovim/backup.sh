# Make a backup of your current Neovim files:
# # required
# mv ~/.config/nvim{,.bak}
# # # optional but recommended
# mv ~/.local/share/nvim{,.bak}
# mv ~/.local/state/nvim{,.bak}
# mv ~/.cache/nvim{,.bak}
rm -rf ~/SourceApps/neovim/nvim/

cp -r ~/.config/nvim/ ~/SourceApps/neovim/
