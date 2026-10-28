doas apt update && doas apt upgrade -y
doas apt install ripgrep fd-find luarocks lazygit python3-pynvim

# doas rm -rf /usr/local/share/nvim /usr/local/lib/nvim
# cd ~/apps/neovim/
# doas make install

# Make a backup of your current Neovim files:
# # required
mv ~/.config/nvim{,.bak}
# # optional but recommended
mv ~/.local/share/nvim{,.bak}
mv ~/.local/state/nvim{,.bak}
mv ~/.cache/nvim{,.bak}
# Clone the starter
# git clone https://github.com/LazyVim/starter ~/.config/nvim
cp -r ~/SourceApps/neovim/nvim ~/.config/
# Remove the .git folder, so you can add it to your own repo later
# rm -rf ~/.config/nvim/.git
# Start Neovim!
# nvim
# It is recommended to run :LazyHealth after installation. This will load all plugins and check if everything is working correctly.
