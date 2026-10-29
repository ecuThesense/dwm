# su - && apt update && apt upgrade -y && apt install doas -y
# vi /etc/doas.conf
# permit persist username as root
# chown root:root /etc/doas.conf
# chmod 0400 /etc/doas.conf
# apt purge sudo && apt autoremove -y
doas apt update && doas apt upgrade -y && doas apt full-upgrade -y && doas apt autoremove -y
doas apt install git fzf firefox-esr thunderbird gimp libreoffice timeshift htop imagemagick ffmpeg mat2 mpv foomatic-db cups cups-pk-helper curl xclip make clang cmake ninja-build rustup meson just tealdeer vrms wget manpages man-db laptop-detect golang-go gnupg gcc mc converseen flameshot maim xwallpaper pcmanfm

doas apt install \
  build-essential \
  pkg-config \
  libx11-dev \
  libgtk-3-dev \
  libgcr-3-dev \
  libwebkit2gtk-4.1-dev

cp ~/dwm/.bashrc ~/.bashrc
cp -r ~/dwm/AdwaitaMono/ ~/.local/share/fonts/
#rm -rf ~/.config/alacritty/
#cp -r ~/SourceApps/alacritty/ ~/.config/
fc-cache -fv
cp -r ~/dwm/Templates/ ~/
exec ~/dwm/neovim/install.sh
doas exec ~/dwm/Vimix-Grub/install.sh

doas make -C ~/dwm/dwm/ clean install
doas make -C ~/dwm/dmenu/ clean install
doas make -C ~/dwm/slock/ clean install
doas make -C ~/dwm/slstatus/ clean install
doas make -C ~/dwm/st/ clean install
doas make -C ~/dwm/surf/ clean install

mkdir -p ~/apps/
curl -L -o ~/.local/bin/nvim https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
#curl -L -o ~/.local/bin/pdf-tricks https://github.com/pkgforge-dev/PDF-Tricks-AppImage/releases/download/0.4.1-2%402026-10-22_1792689058/PDF_Tricks-0.4.1-2-anylinux-x86_64.AppImage
#curl -L -o ~/.local/bin/eyedropper https://github.com/pkgforge-dev/Eyedropper-AppImage/releases/download/2.2.1-1%402026-10-22_1792689101/Eyedropper-2.2.1-1-anylinux-x86_64.AppImage
#curl -L -o ~/.local/bin/gradia https://github.com/pkgforge-dev/Gradia-AppImage/releases/download/1.13.0%402026-10-22_1792688704/Gradia-1.13.0-anylinux-x86_64.AppImage
curl -L -o ~/.local/bin/impression https://github.com/pkgforge-dev/Impression-AppImage/releases/download/3.8.0-1%402026-10-22_1792689451/Impression-3.8.0-1-anylinux-x86_64.AppImage
curl -L -o ~/.local/bin/localsend https://github.com/localsend/localsend/releases/download/v1.18.2/LocalSend-1.18.2-linux-x86-64.AppImage
curl -L -o ~/.local/bin/newsflash https://github.com/pkgforge-dev/NewsFlash-AppImage/releases/download/5.2.3-1%402026-10-22_1792688923/Newsflash-5.2.5-1-anylinux-x86_64.AppImage
curl -L -o ~/.local/bin/pdfcraft https://github.com/storytold/pdfcraft/releases/download/v0.14.0/pdfcraft-0.14.0-linux-x86_64.AppImage
#curl -L -o ~/.local/bin/libreoffice-full https://appimages.libreitalia.org/LibreOffice-latest.full-x86_64.AppImage

chmod u+x *
bin-import ~/apps/

# source ~/.bashrc
# doas update-alternatives --config x-terminal-emulator
# gsettings set org.gnome.desktop.default-applications.terminal exec '/usr/bin/gnome-terminal.wrapper'
# gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e'
# * 0  /usr/bin/gnome-terminal.wrapper   40   auto mode
