# dotfiles

My *nix dotfiles

## Setup

TODO

### Configure Electron apps to run on Wayland

Right Click on the Application Launcher > Edit Applications > \<APPLICATION> > Add the following to `Command-Line Arguments`:

`--enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto`

### Configure Electron apps to use the KDE Plasma file picker

Right Click on the Application Launcher > Edit Applications > \<APPLICATION> > Add the following environment variable:

`GTK_USE_PORTAL=1`

### Display battery percentage for Bluetooth devices using proprietary protocols

- Open a Terminal, and run: `sudo systecmtl edit bluetooth.service`
- In the file that opens, add the following content:

```ini
[Service]
ExecStart=
ExecStart=/usr/libexec/bluetooth/bluetoothd --experimental
```

- Save the file and exit, and run: `sudo systemctl restart bluetooth.service`

### Fix broken emojis in the KDE UI (mostly occurs on openSUSE Tumbleweed)

- Open the file `/etc/fonts/local.conf` and add the following content:

```xml
<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
 <alias>
  <family>serif</family>
  <prefer>
   <family>Noto Sans</family>
   <family>Noto Color Emoji</family>
  </prefer>
 </alias>
 <alias>
  <family>sans-serif</family>
  <prefer>
   <family>Noto Sans</family>
   <family>Noto Color Emoji</family>
  </prefer>
 </alias>
 <alias>
  <family>monospace</family>
  <prefer>
   <family>Noto Sans</family>
   <family>Noto Color Emoji</family>
  </prefer>
 </alias>
 <dir>~/.fonts</dir>
</fontconfig>
```

- Save the file, and run the following command: `fc-cache -f -v`

### Fix Discord (Flatpak version) not working with SELinux in enforcing mode (Discord shows a message saying that the installation is corrupted)

Open a Terminal, and run:

```bash
sudo ausearch -c 'Discord' --raw | audit2allow -M discord
sudo semodule -i discord.pp
```

### Setting up storage as a Steam drive

#### Using YaST

TODO

#### Manual

- Create a directory as a mount point in `/mnt` (Eg: `/mnt/MySteamDrive`). Ensure the ownership of this directory is `$USER:$USER`.
- Use the `blkid` command to get the UUID of the drive (Eg: `sudo blkid /dev/sda1`)
- Add the following entry in `/etc/fstab`:

```text
UUID=<UUID>  /mnt/<MOUNT_DIRECTORY>     <FILESYSTEM>   user,data=writeback,defaults,exec,noatime,barrier=0  0  2
```

- After saving the file and exiting, the drive can now be mounted and selected as a storage drive in Steam.

### Enable full screen sharing for XWayland apps

- Install the [XWayland Video Bridge](https://invent.kde.org/system/xwaylandvideobridge) application. (The package is usually `xwaylandvideobridge` on most distros)
- Run the XWayland Video Bridge application from the applications menu.
- ~~The application should also be added to autostart to enable it on every boot.~~ The application seems to autostart without requiring to add it to the autostart applications. If its added to autostart, it seems to spawn multiple instances on boot. This is apparently a bug that's being fixed in KDE Plasma.

### Allow adding printers from KDE System Settings (openSUSE)

- Open the file `/etc/cups/cups-files.conf` and find the line that starts with `SystemGroup`. By default, its value is set to just `root`.
- Modify this line to add the `wheel` group to it.

```ini
SystemGroup wheel root
```

- Save the file and restart the CUPS service: `sudo systemctl restart cups`
- Add your user to the `wheel` group: `sudo usermod -a -G wheel $USER`
- Log out and log in again for the group changes to take effect.

### Fix broken rendering in Chromium-based browsers and Electron apps (Wayland)

This issue usually occurs when the application's GPU cache is broken.
To fix this issue, we can simply clear the `GPUCache` directory for the application.

For example:

- Google Chrome: `rm -rf ~/.config/google-chrome/Default/GPUCache`
- Visual Studio Code: `~/.config/Code/GPUCache`
- Brave Browser: `~/.config/BraveSoftware/Brave-Browser/Default/GPUCache`

Restarting the app after deleting this directory will rebuild the GPU cache, and the issue should be resolved.
