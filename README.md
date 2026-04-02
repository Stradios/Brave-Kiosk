# 🦁 Brave Kiosk

> One-command installer that turns any 64-bit Linux machine or Raspberry Pi into a locked-down, auto-booting browser kiosk running [Brave](https://brave.com).

---

## ✨ Features

- **One-line install** — detects your distro and architecture automatically
- **Interactive setup** — prompts for your kiosk URL, audio keybind, and display mode; no file editing required
- **Auto-login** — boots straight to Brave on tty1, no desktop environment needed
- **HDMI audio** — starts PulseAudio, auto-detects and routes to the HDMI sink
- **Media & volume keys** — dedicated keyboard buttons work out of the box (volume, mute, play/pause, next/prev, brightness)
- **Display lockdown** — forces external HDMI/DisplayPort output, disables internal laptop screen and lid switch
- **Minimal footprint** — uses Xorg + Openbox only; no full desktop installed

---

## 🖥️ Supported platforms

| Distro | Architecture | Brave install method |
|---|---|---|
| Ubuntu / Debian | x86_64 | Official apt repo |
| Fedora / RHEL | x86_64 | Official rpm repo |
| Arch Linux / Manjaro | x86_64 | AUR (`brave-bin`) — see note below |
| Raspberry Pi OS 64-bit | aarch64 | Snap |

---

## 🚀 Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/Stradios/Brave-Kiosk/main/install.sh \
  -o /tmp/install.sh && sudo bash /tmp/install.sh
```

> **Note:** The `sudo bash <(curl ...)` process substitution form does **not** work on Raspberry Pi OS — always use the download-then-run form above. It works identically on all supported platforms.

The installer asks three questions, then handles everything else:

1. **Kiosk URL** — the website to display on boot (e.g. `https://your-company.no`)
2. **Audio mixer keybind** — shortcut to open the PulseAudio GUI mixer (default: `Ctrl+Alt+A`)
3. **Display lockdown** — whether to disable the internal laptop screen and require an external display (recommended for laptop hardware)

After answering, it installs all packages, configures autologin, writes all config files, and offers to reboot immediately.

---

## 📋 What gets installed

| Package | Purpose |
|---|---|
| `brave-browser` / `brave` (snap) | The kiosk browser |
| `xorg` | Minimal display server |
| `openbox` | Lightweight window manager |
| `xinit` | Starts X from the terminal |
| `unclutter` | Hides the mouse cursor when idle |
| `pulseaudio` + `pulseaudio-utils` | Audio daemon and CLI tools (`pactl`, `pacmd`) |
| `pavucontrol` | GUI audio mixer, opened via keybind |
| `playerctl` | Controls media playback in Brave via D-Bus |
| `brightnessctl` | Handles screen brightness keys |
| `xdotool` | Sends synthetic key events to Brave (e.g. page reload) |

---

## 📁 Files written by the installer

```
~/start-kiosk.sh                                          # Main launch script
~/.config/openbox/rc.xml                                  # All keybinds and media keys
~/.bash_profile                                           # Auto-starts X on tty1 login
/etc/systemd/system/getty@tty1.service.d/autologin.conf  # Auto-login, no password prompt
/etc/systemd/logind.conf.d/kiosk.conf                    # Lid/power lockdown (if enabled)
```

> The installer detects your username automatically — you never need to edit a placeholder manually.

---

## ⌨️ Keyboard keys

### Custom keybinds (set during install)

| Keybind | Action |
|---|---|
| `Ctrl+Alt+A` *(or your choice)* | Open PulseAudio mixer (`pavucontrol`) |
| `Ctrl+Alt+T` | Open a terminal emulator (for debugging) |

To change the mixer keybind after install, edit `~/.config/openbox/rc.xml` and run `openbox --reconfigure`.

### Volume keys

| Key | Action |
|---|---|
| Volume Up | +5% on the default audio sink |
| Volume Down | −5% on the default audio sink |
| Mute | Toggle mute on the default sink |
| Mic Mute | Toggle mute on the microphone source |

### Media / playback keys

Controls whatever is playing in Brave — YouTube, Spotify Web, any HTML5 audio or video.

| Key | Action |
|---|---|
| Play / Pause | Toggle playback |
| Stop | Stop playback |
| Next | Skip to next track |
| Previous | Go to previous track |

### Brightness keys

| Key | Action |
|---|---|
| Brightness Up | +10% backlight via `brightnessctl` |
| Brightness Down | −10% backlight via `brightnessctl` |

> Works on laptop internal screens and monitors that expose a backlight device. On Raspberry Pi, depends on the display driver.

### Other special keys

| Key | Action |
|---|---|
| Home / Reload | Refreshes the kiosk page in Brave (`Ctrl+R`) |
| Display | Runs `xrandr --auto` to re-detect outputs (useful after HDMI replug) |
| Calculator | Opens `pavucontrol` — repurposed, no use in kiosk mode |
| Sleep | **Blocked** — no-op |
| Power | **Blocked** — no-op (also handled by logind) |
| Screensaver | **Blocked** — no-op |

---

## 🖥️ Display output lockdown

The installer offers an optional **external-display-only** mode, designed to prevent the machine from being used as a regular laptop.

**At the logind level** (system-wide, before X even starts):
- Closing the laptop lid does nothing — no suspend, no output switch
- The physical power button is ignored
- Idle auto-suspend is disabled

**At the X session level** (inside `start-kiosk.sh`, every boot):
- Scans connected outputs via `xrandr`
- If an external display (HDMI / DisplayPort) is found → sets it as primary, turns off the internal screen (eDP / LVDS)
- If no external display is found → waits and retries every 5 seconds for up to 60 seconds, then falls back gracefully

```
Scanning for external display...
No external display yet — retrying in 5s... (5/60s)
External display found: HDMI-1
Internal display (eDP-1) disabled
```

The 60-second wait means the kiosk shows a black internal screen until a display is plugged in — a clear signal that the setup is incomplete, rather than silently running on the laptop screen.

> On a Raspberry Pi or dedicated mini-PC with no internal screen, you can skip this option safely.

---

## 🔊 HDMI audio

The start script handles HDMI audio automatically at every boot:

1. Starts the PulseAudio daemon
2. Waits up to 10 seconds for it to initialise
3. Finds the first HDMI sink and sets it as the default output

If audio ends up on the wrong output, press your configured keybind (default `Ctrl+Alt+A`) to open `pavucontrol` on-screen and switch sinks manually.

### Raspberry Pi — extra audio step

On the Pi, HDMI audio is also forced at the firmware level during install:

```bash
sudo raspi-config nonint do_audio 2
```

You can revert this in `raspi-config → System Options → Audio` at any time.

### Useful audio debug commands

```bash
pactl list short sinks          # List all output sinks
pactl info                      # Show current default sink
pactl set-default-sink NAME     # Manually switch output
pacmd list-sinks                # Verbose sink info
aplay -l                        # List ALSA hardware devices
```

---

## 🔧 Brave kiosk flags

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

## 🎵 Arch Linux — audio pre-requirement

On Arch Linux, PulseAudio is **not installed by default**. If the audio drivers are missing before you run the installer, PulseAudio will fail silently and you will get no sound over HDMI.

Install the required packages manually **before** running the kiosk installer:

```bash
sudo pacman -S --needed pulseaudio pulseaudio-alsa alsa-utils
```

| Package | Why it's needed |
|---|---|
| `pulseaudio` | The audio daemon itself |
| `pulseaudio-alsa` | ALSA backend — bridges PulseAudio to the kernel sound layer |
| `alsa-utils` | Provides `aplay`, `amixer`, and `alsamixer` for debugging |

After installing, start PulseAudio once to verify it works before running the kiosk installer:

```bash
pulseaudio --start
pactl info
```

If `pactl info` returns a default sink, you are good to go. If it says "Connection refused", try:

```bash
systemctl --user enable --now pulseaudio.socket
```

> **Manjaro users:** Manjaro typically ships with PulseAudio pre-installed, so this step is usually not needed. Run `pactl info` to confirm before installing.

---

## 🍓 Raspberry Pi notes

- Brave has no official ARM apt repo — the installer uses the **Snap** package at `/snap/bin/brave`
- First launch after a snap install can take 10–20 seconds on a Pi 4; subsequent boots are faster. A Pi 5 is significantly snappier
- The installer writes HDMI display settings to `/boot/firmware/config.txt`:

```ini
hdmi_force_hotplug=1
hdmi_drive=2
disable_overscan=1
```

- If your display shows black borders, replace `disable_overscan=1` with individual `overscan_left=0`, `overscan_right=0`, `overscan_top=0`, `overscan_bottom=0` lines

---

## 🛠️ Troubleshooting

**No sound over HDMI**
```bash
pactl list short sinks
# Find your HDMI sink name, then:
pactl set-default-sink alsa_output.YOUR_SINK_NAME
```
If no HDMI sink appears at all, open `pavucontrol → Configuration` and set the HDMI card profile to "Digital Stereo (HDMI)" — it may be set to "Off".

**Wrong display output / black screen**
- Check `hdmi_force_hotplug=1` is in `/boot/firmware/config.txt` (Pi)
- Try a different HDMI port or cable
- Run `xrandr` from a terminal (`Ctrl+Alt+T`) to list connected outputs

**Media keys not working**
- Verify `playerctl` is installed: `which playerctl`
- Brave must be the active media session — play something in Brave first, then test the keys
- List registered media players: `playerctl -l`

**Brightness keys not working**
- Verify `brightnessctl` is installed: `which brightnessctl`
- List available backlight devices: `brightnessctl --list`
- External monitors often don't expose a backlight device — this is a hardware limitation

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