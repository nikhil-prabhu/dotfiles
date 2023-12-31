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
