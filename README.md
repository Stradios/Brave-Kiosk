
# 🦁 Brave Kiosk

> One-command installer that turns any 64-bit Linux machine or Raspberry Pi into a locked-down, auto-booting browser kiosk running [Brave](https://brave.com).

---

## ✨ Features

- **One-line install** — detects your distro and architecture automatically
- **Interactive setup** — prompts for your kiosk URL, audio keybind, and display keybind; no file editing required
- **Auto-login** — boots straight to Brave on tty1, no desktop environment needed
- **HDMI audio** — starts PulseAudio, auto-detects and routes to the HDMI sink
- **🎮 Display switcher** — press `Ctrl+Alt+P` (or your custom keybind) to change display output on the fly
- **Multiple display modes** — single monitor, mirror/clone, span/extended, or auto-detect
- **Persistent settings** — your display choice is saved and restored after reboot
- **pavucontrol keybind** — press your chosen key combo to open the audio mixer on-screen
- **Minimal footprint** — uses Xorg + Openbox only; no full desktop installed

---

## 🖥️ Supported platforms

| Distro | Architecture | Brave install method |
|---|---|---|
| Ubuntu / Debian / Mint | x86_64 + aarch64 | Official apt repo |
| Fedora 41+ | x86_64 | Official rpm repo (dnf5) |
| Fedora <41 / Rocky / RHEL | x86_64 | Official rpm repo (dnf) |
| Arch Linux | x86_64 | AUR (`brave-bin`) |
| Manjaro | x86_64 | Official `pacman` package |
| Raspberry Pi OS 64-bit | aarch64 | Official apt repo (arm64) |

> Brave now publishes official packages for both **x86_64 and aarch64** via their apt and rpm repos. Snap is no longer required on any supported platform.

---

## 🚀 Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/Stradios/Brave-Kiosk/main/install.sh \
  -o /tmp/install.sh && sudo bash /tmp/install.sh
```



The installer asks you a few questions, then handles everything else:

1. **Kiosk URL** — the website to display on boot (e.g. `https://your-company.no`)
2. **Audio keybind** — keyboard shortcut to open the PulseAudio mixer (default: `Ctrl+Alt+A`)
3. **Display switcher keybind** — keyboard shortcut to open the display output menu (default: `Ctrl+Alt+P`)

After answering, it installs all packages, configures autologin, writes all config files, and offers to reboot immediately.

---

## 📋 What gets installed

| Package | Purpose |
|---|---|
| `brave-browser` | The kiosk browser |
| `xorg` | Minimal display server |
| `openbox` | Lightweight window manager |
| `xinit` | Starts X from the terminal |
| `unclutter` | Hides the mouse cursor when idle |
| `pulseaudio` + `pulseaudio-utils` | Audio daemon and CLI tools (`pactl`, `pacmd`) |
| `pavucontrol` | GUI audio mixer, opened via keybind |
| `zenity` / `whiptail` | GUI/terminal dialog for display switcher |
| `xrandr` | Display configuration tool |

---

## 📁 Files written by the installer

```
~/start-kiosk.sh                                          # Main launch script
~/display-switcher.sh                                     # Display output switcher
~/.config/openbox/rc.xml                                  # All keybinds
~/.bash_profile                                           # Auto-starts X on tty1 login
~/.kiosk-display-mode                                     # Saved display mode (auto-created)
/etc/systemd/system/getty@tty1.service.d/autologin.conf  # Auto-login, no password prompt
```

> The installer detects your username automatically — you never need to edit a placeholder manually.

---

## 🎮 Display Switcher (Ctrl+Alt+P)

Press your configured display keybind (default: `Ctrl+Alt+P`) to open an interactive menu that lets you change display output without rebooting.

### Display modes available:

| Mode | Description |
|---|---|
| **Single Monitor** | Select one specific monitor — all others are turned off |
| **Mirror/Clone** | Same content on all connected displays |
| **Span/Extended** | Desktop spreads across all monitors (extended desktop) |
| **Auto-detect** | System default behavior (enables all monitors in their preferred modes) |

### How it works:

1. Press `Ctrl+Alt+P` while the kiosk is running
2. A GUI dialog appears with all connected monitors and modes
3. Select your desired output configuration
4. The script applies the change instantly and restarts Brave
5. Your selection is saved to `~/.kiosk-display-mode` and restored on every boot

### Example menu (zenity GUI):

```
┌─────────────────────────────────────────┐
│ Display Switcher                        │
├─────────────────────────────────────────┤
│ Select display output mode:             │
│                                         │
│ ○ HDMI-1        1920x1080              │
│ ○ DP-1          2560x1440              │
│ ○ eDP-1 (laptop) 1366x768              │
│ ○ Mirror/Clone all displays             │
│ ○ Span across all displays              │
│ ○ Auto-detect (system default)          │
│                                         │
│              [OK]  [Cancel]             │
└─────────────────────────────────────────┘
```

### Terminal fallback:

If running over SSH or without a GUI, the script automatically falls back to a terminal-based menu using `whiptail`.

---

## ⌨️ Keyboard keys

### Custom keybinds (set during install)

| Keybind | Action |
|---|---|
| `Ctrl+Alt+A` *(or your choice)* | Open PulseAudio mixer (`pavucontrol`) |
| `Ctrl+Alt+P` *(or your choice)* | Open display switcher menu |
| `Ctrl+Alt+T` | Open a terminal emulator (for debugging) |
| `Ctrl+Alt+R` | Restart Brave (refresh kiosk page) |

To change keybinds after install, edit `~/.config/openbox/rc.xml` and run `openbox --reconfigure`.

---

## 🔊 HDMI audio

The start script handles HDMI audio automatically at every boot:

1. Starts the PulseAudio daemon
2. Waits up to 10 seconds for it to initialise
3. Finds the first HDMI sink and sets it as the default output

If audio ends up on the wrong output, press your configured keybind (default `Ctrl+Alt+A`) to open `pavucontrol` on-screen and switch sinks manually.

### Useful audio debug commands

```bash
pactl list short sinks          # List all output sinks
pactl info                      # Show current default sink
pactl set-default-sink NAME     # Manually switch output
pacmd list-sinks                # Verbose sink info
aplay -l                        # List ALSA hardware devices
```

---

## 🔧 Brave kiosk flags used

| Flag | Effect |
|---|---|
| `--kiosk` | Full-screen, no UI chrome, Esc/F11 disabled |
| `--no-first-run` | Skip welcome and setup dialogs |
| `--disable-infobars` | Suppress "not your default browser" banners |
| `--disable-session-crashed-bubble` | No "restore tabs?" prompt on boot |
| `--disable-restore-session-state` | Don't restore previous session |
| `--disable-pinch` | Prevent zoom gestures on touch screens |
| `--overscroll-history-navigation=0` | Disable swipe-to-go-back on touch screens |
| `--autoplay-policy=no-user-gesture-required` | Allow video and audio to autoplay |

---

## 🍓 Raspberry Pi notes

- Brave now publishes an official **arm64 apt package** — the installer uses the standard apt repo, no Snap required
- The installer writes HDMI display settings to `/boot/firmware/config.txt`:

```ini
hdmi_force_hotplug=1
hdmi_drive=2
disable_overscan=1
```

- If your display shows black borders, replace `disable_overscan=1` with individual `overscan_left=0`, `overscan_right=0`, `overscan_top=0`, `overscan_bottom=0` lines
- HDMI audio is also forced at the firmware level during install via `raspi-config nonint do_audio 2`. You can revert this in `raspi-config → System Options → Audio`

---

## 🛠️ Troubleshooting

**Display switcher doesn't appear when pressing the keybind**
- Verify the keybind is correct: `grep -A2 "C-A-p" ~/.config/openbox/rc.xml`
- Reload Openbox config: `openbox --reconfigure`
- Try running manually: `~/display-switcher.sh`

**No sound over HDMI**
```bash
pactl list short sinks
# Find your HDMI sink name, then:
pactl set-default-sink alsa_output.YOUR_SINK_NAME
```
If no HDMI sink appears at all, open `pavucontrol → Configuration` and set the HDMI card profile to "Digital Stereo (HDMI)" — it may be set to "Off".

**Wrong display output / black screen**
- Press `Ctrl+Alt+P` and select a different monitor mode
- Check `hdmi_force_hotplug=1` is in `/boot/firmware/config.txt` (Pi)
- Try a different HDMI port or cable
- Run `xrandr` from a terminal (`Ctrl+Alt+T`) to list connected outputs

**Display mode not persisting after reboot**
- Check that `~/.kiosk-display-mode` exists
- Verify the file has correct content (e.g., "single" on line 1, monitor name on line 2)
- The start script reads this file on boot to restore settings

**Brave shows "restore session" on boot**
- Ensure `--disable-restore-session-state` and `--disable-session-crashed-bubble` are present in `~/start-kiosk.sh`

**Kiosk URL or settings need to change**

Re-run the installer — it regenerates all config files with your new answers:

```bash
curl -fsSL https://raw.githubusercontent.com/Stradios/Brave-Kiosk/main/install.sh \
  -o /tmp/install.sh && sudo bash /tmp/install.sh
```

---

## 📄 License

MIT — do whatever you like with it.

---

<div align="center">
Made with ☕ by <a href="https://github.com/Stradios">Stradios</a>
</div>
