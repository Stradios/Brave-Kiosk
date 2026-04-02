# 🦁 Brave Kiosk

> One-command installer that turns any 64-bit Linux machine or Raspberry Pi into a locked-down, auto-booting browser kiosk running [Brave](https://brave.com).

---

## ✨ Features

- **One-line install** — detects your distro and architecture automatically
- **Interactive setup** — prompts for your kiosk URL and audio keybind; no file editing required
- **Auto-login** — boots straight to Brave on tty1, no desktop environment needed
- **HDMI audio** — starts PulseAudio, auto-detects and routes to the HDMI sink
- **pavucontrol keybind** — press your chosen key combo to open the audio mixer on-screen
- **Minimal footprint** — uses Xorg + Openbox only; no full desktop installed

---

## 🖥️ Supported platforms

| Distro | Architecture | Brave install method |
|---|---|---|
| Ubuntu / Debian | x86_64 | Official apt repo |
| Fedora / RHEL | x86_64 | Official rpm repo |
| Arch Linux / Manjaro | x86_64 | AUR (`brave-bin`) |
| Raspberry Pi OS 64-bit | aarch64 | Snap |

---

## 🚀 Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/Stradios/Brave-Kiosk/main/install.sh \
  -o /tmp/install.sh && sudo bash /tmp/install.sh
```

> **Note:** The `sudo bash <(curl ...)` process substitution form does **not** work on Raspberry Pi OS — always use the download-then-run form above. It works on all supported platforms.

The installer will ask three questions and then handle everything else:

1. **Kiosk URL** — the website to display on boot (e.g. `https://your-company.no`)
2. **Audio keybind** — keyboard shortcut to open the PulseAudio mixer (default: `Ctrl+Alt+A`)
3. **Display lockdown** — whether to disable the internal screen and force an external display (recommended for laptop hardware)

After answering, it installs all packages, configures autologin, writes the start script, and offers to reboot immediately.

---

## 📋 What gets installed

| Package | Purpose |
|---|---|
| `brave-browser` / `brave` (snap) | The kiosk browser |
| `xorg` | Minimal display server |
| `openbox` | Lightweight window manager |
| `xinit` | Starts X from the terminal |
| `unclutter` | Hides the mouse cursor when idle |
| `pulseaudio` + `pulseaudio-utils` | Audio daemon and CLI tools |
| `pavucontrol` | GUI audio mixer (opened via keybind) |

---

## 📁 Files written by the installer

```
~/start-kiosk.sh                                     # Main launch script
~/.config/openbox/rc.xml                             # Openbox keybinds
~/.bash_profile                                      # Auto-starts X on tty1 login
/etc/systemd/system/getty@tty1.service.d/
  autologin.conf                                     # Auto-login (no password prompt)
```

> The installer detects your username automatically using `$(whoami)` — you never need to edit a username placeholder manually.

---

## 🖥️ Display output lockdown

The installer offers an optional **external-display-only** mode, designed to prevent the machine from being casually used as a regular laptop.

When enabled, the start script does four things:

**At the logind level (system-wide, before X even starts):**
- Closing the laptop lid does nothing — no suspend, no output switch
- The physical power button is ignored

**At the X session level (inside `start-kiosk.sh`):**
- Scans connected outputs via `xrandr` at boot
- If an external display (HDMI/DisplayPort) is found, it is set as the primary output and the internal screen (eDP/LVDS) is turned off
- If no external display is detected, the script waits and retries every 5 seconds for up to 60 seconds before falling back to whatever is connected

```
Scanning for external display...
No external display yet — retrying in 5s... (5/60s)
External display found: HDMI-1
Internal display (eDP-1) disabled
```

The 60-second wait means the kiosk will sit at a black internal screen on boot until a display is plugged in — a clear signal that something is wrong with the setup rather than silently running on the laptop screen.

> **Choosing not to enable lockdown** is fine too — the installer asks. On a Raspberry Pi or a dedicated mini-PC there is no internal screen to worry about.

---

## 🔊 HDMI audio

The start script handles HDMI audio automatically at every boot:

1. Starts the PulseAudio daemon
2. Waits up to 10 seconds for it to be ready
3. Finds the first HDMI sink and sets it as the default output

If audio ends up on the wrong output, press your configured keybind (default `Ctrl+Alt+A`) to open `pavucontrol` on the kiosk display and switch sinks manually.

### Raspberry Pi — extra audio step

On the Pi, HDMI audio is also forced at the firmware level during install:

```bash
sudo raspi-config nonint do_audio 2
```

You can change this back in `raspi-config → System Options → Audio` at any time.

---

## ⌨️ Default keybinds (Openbox)

| Keybind | Action |
|---|---|
| `Ctrl+Alt+A` (or your choice) | Open PulseAudio mixer (`pavucontrol`) |
| `Ctrl+Alt+T` | Open a terminal emulator (for debugging) |

To change the audio keybind after install, edit `~/.config/openbox/rc.xml` and run `openbox --reconfigure`.

---

## 🔧 Brave kiosk flags used

| Flag | Effect |
|---|---|
| `--kiosk` | Full-screen, no UI chrome, Esc/F11 disabled |
| `--no-first-run` | Skip welcome/setup dialogs |
| `--disable-infobars` | Suppress "not your default browser" banners |
| `--disable-session-crashed-bubble` | No "restore tabs?" prompt on boot |
| `--disable-pinch` | Prevent zoom gestures on touch screens |
| `--overscroll-history-navigation=0` | Disable swipe-to-go-back on touch screens |
| `--autoplay-policy=no-user-gesture-required` | Allow video/audio to autoplay |

---

## 🍓 Raspberry Pi notes

- Brave is not available in an official ARM apt repo — the installer uses the **Snap** package (`/snap/bin/brave`)
- First launch after a snap install can take 10–20 seconds on a Pi 4; subsequent boots are faster
- The installer also writes HDMI display settings to `/boot/firmware/config.txt`:

  ```ini
  hdmi_force_hotplug=1
  hdmi_drive=2
  disable_overscan=1
  ```

---

## 🛠️ Troubleshooting

**No sound over HDMI**
```bash
# List available sinks
pactl list short sinks

# Manually set the HDMI sink (replace with your sink name)
pactl set-default-sink alsa_output.pci-0000_00_1f.3.hdmi-stereo
```

**Wrong display output / black screen**
- Check `hdmi_force_hotplug=1` is in `/boot/firmware/config.txt` (Pi)
- Try a different HDMI port or cable
- Run `xrandr` from a terminal to list connected outputs

**Brave shows "restore session" on boot**
- Ensure `--disable-restore-session-state` and `--disable-session-crashed-bubble` are in `~/start-kiosk.sh`

**Kiosk URL needs to change**
Re-run the installer — it regenerates `start-kiosk.sh` with your new URL without touching the system config:
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