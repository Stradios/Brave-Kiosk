#!/bin/bash
# ============================================================
#  Brave Kiosk — one-shot installer
#  https://github.com/Stradios/Brave-Kiosk
#
#  Supports:
#    Ubuntu/Debian (x86_64), Fedora/RHEL (x86_64),
#    Arch Linux (x86_64), Raspberry Pi OS (aarch64)
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/Stradios/Brave-Kiosk/main/install.sh \
#      -o /tmp/install.sh && sudo bash /tmp/install.sh
# ============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[info]${RESET}  $*"; }
success() { echo -e "${GREEN}[ok]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[warn]${RESET}  $*"; }
die()     { echo -e "${RED}[error]${RESET} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}$*${RESET}"; echo "────────────────────────────────────────"; }

KIOSK_USER="${SUDO_USER:-$USER}"
KIOSK_HOME=$(eval echo "~$KIOSK_USER")

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)        ARCH_LABEL="x86_64" ;;
  aarch64|arm64) ARCH_LABEL="aarch64" ;;
  *)             die "Unsupported architecture: $ARCH" ;;
esac

if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  DISTRO_ID="${ID:-unknown}"
  DISTRO_LIKE="${ID_LIKE:-}"
else
  die "Cannot detect distro — /etc/os-release not found."
fi

is_debian() { [[ "$DISTRO_ID" == "debian" || "$DISTRO_ID" == "ubuntu" || "$DISTRO_ID" == "raspbian" || "$DISTRO_LIKE" == *"debian"* ]]; }
is_fedora() { [[ "$DISTRO_ID" == "fedora" || "$DISTRO_ID" == "rhel" || "$DISTRO_LIKE" == *"fedora"* || "$DISTRO_LIKE" == *"rhel"* ]]; }
is_arch()   { [[ "$DISTRO_ID" == "arch" || "$DISTRO_ID" == "manjaro" || "$DISTRO_LIKE" == *"arch"* ]]; }
is_pi()     { [[ "$DISTRO_ID" == "raspbian" ]] || { [[ -f /proc/device-tree/model ]] && grep -qi "raspberry" /proc/device-tree/model 2>/dev/null; }; }

clear
echo -e "${BOLD}"
echo "  ██████╗ ██████╗  █████╗ ██╗   ██╗███████╗"
echo "  ██╔══██╗██╔══██╗██╔══██╗██║   ██║██╔════╝"
echo "  ██████╔╝██████╔╝███████║██║   ██║█████╗  "
echo "  ██╔══██╗██╔══██╗██╔══██║╚██╗ ██╔╝██╔══╝  "
echo "  ██████╔╝██║  ██║██║  ██║ ╚████╔╝ ███████╗"
echo "  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝"
echo -e "${RESET}"
echo -e "  ${CYAN}Kiosk Installer${RESET} — Brave + Openbox + HDMI Audio + Media Keys"
echo ""
echo -e "  User   : ${BOLD}$KIOSK_USER${RESET}"
echo -e "  Home   : ${BOLD}$KIOSK_HOME${RESET}"
echo -e "  Arch   : ${BOLD}$ARCH_LABEL${RESET}"
echo -e "  Distro : ${BOLD}$PRETTY_NAME${RESET}"
echo ""

[[ $EUID -ne 0 ]] && die "Please run with sudo:\n  sudo bash /tmp/install.sh"

read -rp "$(echo -e "${YELLOW}Continue with installation? [Y/n]:${RESET} ")" CONFIRM
CONFIRM="${CONFIRM:-Y}"
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── Kiosk URL ────────────────────────────────────────────────
header "Kiosk URL"
echo -e "  Enter the website to display on startup."
echo -e "    ${CYAN}https://your-company.no${RESET}"
echo -e "    ${CYAN}https://dashboard.example.com${RESET}"
echo -e "    ${CYAN}file:///home/$KIOSK_USER/index.html${RESET}"
echo ""
while true; do
  read -rp "$(echo -e "  ${BOLD}URL:${RESET} ")" KIOSK_URL
  KIOSK_URL="${KIOSK_URL:-}"
  if [[ -z "$KIOSK_URL" ]]; then
    warn "URL cannot be empty."
  elif [[ ! "$KIOSK_URL" =~ ^(https?://|file://) ]]; then
    warn "URL should start with https://, http://, or file://"
    read -rp "$(echo -e "  ${YELLOW}Use '$KIOSK_URL' anyway? [y/N]:${RESET} ")" USE_ANYWAY
    [[ "${USE_ANYWAY:-N}" =~ ^[Yy]$ ]] && break
  else
    break
  fi
done
success "Kiosk URL: $KIOSK_URL"

# ── Audio keybind ────────────────────────────────────────────
header "Audio Mixer Keybind"
echo -e "  Custom keybind to open the PulseAudio mixer (pavucontrol)."
echo -e "  This is separate from the dedicated volume keys on your keyboard."
echo -e "  Syntax: C=Ctrl  A=Alt  S=Shift  W=Super"
echo -e "  Default: ${CYAN}C-A-a${RESET}  (Ctrl+Alt+A)"
echo ""
read -rp "$(echo -e "  ${BOLD}Keybind [C-A-a]:${RESET} ")" KEYBIND
KEYBIND="${KEYBIND:-C-A-a}"
success "Audio mixer keybind: $KEYBIND"

# ── Display lockdown ─────────────────────────────────────────
header "Display Output Lockdown"
echo -e "  Locks the kiosk to an ${BOLD}external HDMI/DisplayPort${RESET} display."
echo -e "  Prevents headless-laptop misuse:"
echo ""
echo -e "    ${CYAN}•${RESET} Internal screen (eDP/LVDS) turned off when external display is connected"
echo -e "    ${CYAN}•${RESET} Kiosk waits up to 60 s at boot for an external display before falling back"
echo -e "    ${CYAN}•${RESET} Closing the laptop lid does nothing (no suspend, no output switch)"
echo -e "    ${CYAN}•${RESET} Power button action disabled via logind"
echo ""
read -rp "$(echo -e "  ${BOLD}Enable display lockdown? [Y/n]:${RESET} ")" DISPLAY_LOCK
DISPLAY_LOCK="${DISPLAY_LOCK:-Y}"
if [[ "$DISPLAY_LOCK" =~ ^[Yy]$ ]]; then
  DISPLAY_LOCKDOWN=true
  success "Display lockdown enabled"
else
  DISPLAY_LOCKDOWN=false
  info "Display lockdown skipped"
fi

# ════════════════════════════════════════════════════════════
#  STEP 1 — Packages
# ════════════════════════════════════════════════════════════
header "Step 1/7 — Installing packages"

# playerctl  — media key control (play/pause/next/prev) for browser media
# brightnessctl — brightness keys
# xdotool    — lets keybinds send synthetic key events to Brave (e.g. reload)

if is_pi; then
  info "Raspberry Pi OS — installing Brave via Snap"
  apt-get update -qq
  apt-get install -y snapd xorg openbox xinit unclutter \
    pulseaudio pulseaudio-utils pavucontrol x11-xserver-utils \
    playerctl brightnessctl xdotool
  systemctl enable --now snapd.socket 2>/dev/null || true
  info "Waiting for snapd..."
  snap wait system seed.loaded 2>/dev/null || sleep 5
  snap install brave
  BRAVE_BIN="/snap/bin/brave"

elif is_debian; then
  info "Debian/Ubuntu — adding Brave apt repo"
  apt-get update -qq && apt-get install -y curl
  curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
    https://brave-browser-apt-release.s3.brave.com/ stable main" \
    > /etc/apt/sources.list.d/brave-browser-release.list
  apt-get update -qq
  apt-get install -y brave-browser xorg openbox xinit unclutter \
    pulseaudio pulseaudio-utils pavucontrol x11-xserver-utils \
    playerctl brightnessctl xdotool
  BRAVE_BIN="brave-browser"

elif is_fedora; then
  info "Fedora/RHEL — adding Brave rpm repo"
  rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
  dnf config-manager --add-repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
  dnf install -y brave-browser xorg-x11-server-Xorg openbox xinit unclutter \
    pulseaudio pulseaudio-utils pavucontrol xorg-x11-server-utils \
    playerctl brightnessctl xdotool
  BRAVE_BIN="brave-browser"

elif is_arch; then
  info "Arch Linux detected"
  if ! command -v yay &>/dev/null; then
    pacman -S --needed --noconfirm base-devel git
    sudo -u "$KIOSK_USER" bash -c '
      git clone https://aur.archlinux.org/yay.git /tmp/yay-install
      cd /tmp/yay-install && makepkg -si --noconfirm'
  fi
  sudo -u "$KIOSK_USER" yay -S --noconfirm brave-bin
  pacman -S --needed --noconfirm xorg-server xorg-xinit xorg-xrandr openbox \
    unclutter pulseaudio pavucontrol playerctl brightnessctl xdotool
  BRAVE_BIN="brave-browser"

else
  die "Unsupported distro: $DISTRO_ID"
fi
success "Packages installed"

# ════════════════════════════════════════════════════════════
#  STEP 2 — Autologin
# ════════════════════════════════════════════════════════════
header "Step 2/7 — Configuring autologin"
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF
systemctl daemon-reexec
systemctl restart getty@tty1
success "Autologin configured for: $KIOSK_USER"

# ════════════════════════════════════════════════════════════
#  STEP 3 — Lid / power lockdown
# ════════════════════════════════════════════════════════════
header "Step 3/7 — Power & lid behaviour"
if [[ "$DISPLAY_LOCKDOWN" == true ]]; then
  mkdir -p /etc/systemd/logind.conf.d
  cat > /etc/systemd/logind.conf.d/kiosk.conf <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandlePowerKey=ignore
IdleAction=ignore
EOF
  systemctl restart systemd-logind
  success "Lid close and power button actions disabled"
else
  info "Skipping lid/power lockdown"
fi

# ════════════════════════════════════════════════════════════
#  STEP 4 — Pi tweaks
# ════════════════════════════════════════════════════════════
header "Step 4/7 — Platform-specific tweaks"
if is_pi; then
  BOOT_CONFIG="/boot/firmware/config.txt"
  [[ -f "$BOOT_CONFIG" ]] || BOOT_CONFIG="/boot/config.txt"
  if ! grep -q "hdmi_force_hotplug" "$BOOT_CONFIG" 2>/dev/null; then
    cat >> "$BOOT_CONFIG" <<'EOF'

# Kiosk display settings
hdmi_force_hotplug=1
hdmi_drive=2
disable_overscan=1
EOF
    success "HDMI config written to $BOOT_CONFIG"
  else
    warn "HDMI config already present — skipping"
  fi
  command -v raspi-config &>/dev/null && raspi-config nonint do_audio 2 \
    && success "HDMI audio forced via raspi-config"
else
  info "Not a Raspberry Pi — skipping firmware config"
fi

# ════════════════════════════════════════════════════════════
#  STEP 5 — Openbox rc.xml (keybinds + media keys)
# ════════════════════════════════════════════════════════════
header "Step 5/7 — Configuring Openbox keybinds & media keys"
OPENBOX_DIR="$KIOSK_HOME/.config/openbox"
mkdir -p "$OPENBOX_DIR"

cat > "$OPENBOX_DIR/rc.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <keyboard>

    <!-- ── Custom keybind: open audio mixer ── -->
    <keybind key="$KEYBIND">
      <action name="Execute"><command>pavucontrol</command></action>
    </keybind>

    <!-- ── Terminal (debug) ── -->
    <keybind key="C-A-t">
      <action name="Execute"><command>x-terminal-emulator</command></action>
    </keybind>

    <!-- ══════════════════════════════════════
         VOLUME KEYS
    ══════════════════════════════════════════ -->
    <keybind key="XF86AudioRaiseVolume">
      <action name="Execute">
        <command>pactl set-sink-volume @DEFAULT_SINK@ +5%</command>
      </action>
    </keybind>
    <keybind key="XF86AudioLowerVolume">
      <action name="Execute">
        <command>pactl set-sink-volume @DEFAULT_SINK@ -5%</command>
      </action>
    </keybind>
    <keybind key="XF86AudioMute">
      <action name="Execute">
        <command>pactl set-sink-mute @DEFAULT_SINK@ toggle</command>
      </action>
    </keybind>
    <keybind key="XF86AudioMicMute">
      <action name="Execute">
        <command>pactl set-source-mute @DEFAULT_SOURCE@ toggle</command>
      </action>
    </keybind>

    <!-- ══════════════════════════════════════
         MEDIA / PLAYBACK KEYS
         Controls media playing in Brave
         (YouTube, Spotify Web, etc.)
    ══════════════════════════════════════════ -->
    <keybind key="XF86AudioPlay">
      <action name="Execute"><command>playerctl play-pause</command></action>
    </keybind>
    <keybind key="XF86AudioStop">
      <action name="Execute"><command>playerctl stop</command></action>
    </keybind>
    <keybind key="XF86AudioNext">
      <action name="Execute"><command>playerctl next</command></action>
    </keybind>
    <keybind key="XF86AudioPrev">
      <action name="Execute"><command>playerctl previous</command></action>
    </keybind>

    <!-- ══════════════════════════════════════
         BRIGHTNESS KEYS
         Works on laptops; depends on driver
         for external displays.
    ══════════════════════════════════════════ -->
    <keybind key="XF86MonBrightnessUp">
      <action name="Execute">
        <command>brightnessctl set +10%</command>
      </action>
    </keybind>
    <keybind key="XF86MonBrightnessDown">
      <action name="Execute">
        <command>brightnessctl set 10%-</command>
      </action>
    </keybind>

    <!-- ══════════════════════════════════════
         RELOAD / HOME KEY
         Refreshes the kiosk page in Brave.
    ══════════════════════════════════════════ -->
    <keybind key="XF86HomePage">
      <action name="Execute"><command>xdotool key ctrl+r</command></action>
    </keybind>
    <keybind key="XF86Reload">
      <action name="Execute"><command>xdotool key ctrl+r</command></action>
    </keybind>

    <!-- ══════════════════════════════════════
         DISPLAY KEY
         Re-runs xrandr output detection —
         useful if HDMI was replugged.
    ══════════════════════════════════════════ -->
    <keybind key="XF86Display">
      <action name="Execute">
        <command>xrandr --auto</command>
      </action>
    </keybind>

    <!-- ══════════════════════════════════════
         REPURPOSED KEYS
         Calculator → open audio mixer
         Search     → disabled (no new windows)
    ══════════════════════════════════════════ -->
    <keybind key="XF86Calculator">
      <action name="Execute"><command>pavucontrol</command></action>
    </keybind>
    <keybind key="XF86Search">
      <action name="Execute"><command>true</command></action>
    </keybind>

    <!-- ══════════════════════════════════════
         SLEEP / POWER / SCREENSAVER
         All blocked inside the X session
         (logind also handles these system-wide)
    ══════════════════════════════════════════ -->
    <keybind key="XF86Sleep">
      <action name="Execute"><command>true</command></action>
    </keybind>
    <keybind key="XF86PowerOff">
      <action name="Execute"><command>true</command></action>
    </keybind>
    <keybind key="XF86ScreenSaver">
      <action name="Execute"><command>true</command></action>
    </keybind>

  </keyboard>
</openbox_config>
EOF

chown -R "$KIOSK_USER:$KIOSK_USER" "$OPENBOX_DIR"
success "Openbox keybinds written (media keys, volume, brightness, reload)"

# ════════════════════════════════════════════════════════════
#  STEP 6 — start-kiosk.sh
# ════════════════════════════════════════════════════════════
header "Step 6/7 — Generating start-kiosk.sh"

if [[ "$DISPLAY_LOCKDOWN" == true ]]; then
  DISPLAY_BLOCK='
# ── Display output lockdown ───────────────────────────────
INTERNAL_PATTERN="^(eDP|LVDS)"
MAX_WAIT=60 ; WAITED=0
echo "Scanning for external display..."
while true; do
  CONNECTED=$(xrandr 2>/dev/null | grep " connected" | awk '"'"'{print $1}'"'"')
  EXTERNAL="" ; INTERNAL=""
  for OUTPUT in $CONNECTED; do
    if echo "$OUTPUT" | grep -qiE "$INTERNAL_PATTERN"; then INTERNAL="$OUTPUT"
    else EXTERNAL="$OUTPUT"; fi
  done
  if [[ -n "$EXTERNAL" ]]; then
    xrandr --output "$EXTERNAL" --auto --primary
    [[ -n "$INTERNAL" ]] && xrandr --output "$INTERNAL" --off && \
      echo "Internal display ($INTERNAL) disabled"
    echo "External display: $EXTERNAL"
    break
  fi
  WAITED=$((WAITED + 5))
  if [[ $WAITED -ge $MAX_WAIT ]]; then
    echo "No external display after ${MAX_WAIT}s — using any connected output"
    for OUTPUT in $CONNECTED; do xrandr --output "$OUTPUT" --auto --primary && break; done
    break
  fi
  echo "Waiting for external display... (${WAITED}/${MAX_WAIT}s)" ; sleep 5
done
# ─────────────────────────────────────────────────────────'
else
  DISPLAY_BLOCK='# Display lockdown not enabled — using default output'
fi

cat > "$KIOSK_HOME/start-kiosk.sh" <<KIOSK_EOF
#!/bin/bash
# Auto-generated by Brave Kiosk Installer — re-run install.sh to update

URL="$KIOSK_URL"
BRAVE="$BRAVE_BIN"
DISPLAY_NUM=":0"
export DISPLAY="\$DISPLAY_NUM"

xset -dpms ; xset s off ; xset s noblank
command -v unclutter &>/dev/null && unclutter -idle 3 -root &

openbox-session &
sleep 2

$DISPLAY_BLOCK

# ── PulseAudio ────────────────────────────────────────────
pulseaudio --start --log-target=syslog
timeout 10 bash -c 'until pactl info &>/dev/null; do sleep 0.5; done'
HDMI_SINK=\$(pactl list short sinks | grep -i hdmi | awk '{print \$2}' | head -n1)
if [[ -n "\$HDMI_SINK" ]]; then
  pactl set-default-sink "\$HDMI_SINK" && echo "Audio: \$HDMI_SINK"
else
  echo "No HDMI sink — using default"
fi

# ── Launch Brave ──────────────────────────────────────────
"\$BRAVE" \\
  --display="\$DISPLAY_NUM" \\
  --kiosk \\
  --no-first-run \\
  --disable-infobars \\
  --disable-session-crashed-bubble \\
  --disable-restore-session-state \\
  --autoplay-policy=no-user-gesture-required \\
  --disable-pinch \\
  --overscroll-history-navigation=0 \\
  "\$URL"
KIOSK_EOF

chmod +x "$KIOSK_HOME/start-kiosk.sh"
chown "$KIOSK_USER:$KIOSK_USER" "$KIOSK_HOME/start-kiosk.sh"
success "start-kiosk.sh written"

# ════════════════════════════════════════════════════════════
#  STEP 7 — .bash_profile
# ════════════════════════════════════════════════════════════
header "Step 7/7 — Auto-start on login"
BASH_PROFILE="$KIOSK_HOME/.bash_profile"
if grep -q "start-kiosk.sh" "$BASH_PROFILE" 2>/dev/null; then
  warn ".bash_profile already has kiosk entry — skipping"
else
  cat >> "$BASH_PROFILE" <<'BPEOF'

# ── Brave Kiosk: auto-start X on tty1 ──
if [[ -z "$DISPLAY" ]] && [[ "$(tty)" == "/dev/tty1" ]]; then
    exec startx ~/start-kiosk.sh
fi
BPEOF
  chown "$KIOSK_USER:$KIOSK_USER" "$BASH_PROFILE"
  success ".bash_profile updated"
fi

# ════════════════════════════════════════════════════════════
#  SUMMARY
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  Installation complete!${RESET}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${BOLD}Kiosk URL    :${RESET} $KIOSK_URL"
echo -e "  ${BOLD}Brave binary :${RESET} $BRAVE_BIN"
echo -e "  ${BOLD}User         :${RESET} $KIOSK_USER"
echo -e "  ${BOLD}Mixer key    :${RESET} $KEYBIND  → pavucontrol"
echo -e "  ${BOLD}Terminal key :${RESET} Ctrl+Alt+T"
echo -e "  ${BOLD}Display lock :${RESET} $([[ "$DISPLAY_LOCKDOWN" == true ]] && echo "enabled" || echo "disabled")"
echo ""
echo -e "  ${BOLD}Media keys enabled:${RESET}"
echo -e "    ${CYAN}Volume Up/Down/Mute${RESET}   → pactl (PulseAudio)"
echo -e "    ${CYAN}Play/Pause/Next/Prev${RESET}  → playerctl (browser media)"
echo -e "    ${CYAN}Brightness Up/Down${RESET}    → brightnessctl"
echo -e "    ${CYAN}Home / Reload${RESET}         → refresh kiosk page"
echo -e "    ${CYAN}Calculator${RESET}            → open audio mixer"
echo -e "    ${CYAN}Sleep/Power/Screensaver${RESET} → blocked"
echo ""
echo -e "  Files written:"
echo -e "    ${CYAN}$KIOSK_HOME/start-kiosk.sh${RESET}"
echo -e "    ${CYAN}$KIOSK_HOME/.config/openbox/rc.xml${RESET}"
echo -e "    ${CYAN}/etc/systemd/system/getty@tty1.service.d/autologin.conf${RESET}"
[[ "$DISPLAY_LOCKDOWN" == true ]] && \
  echo -e "    ${CYAN}/etc/systemd/logind.conf.d/kiosk.conf${RESET}"
echo ""
read -rp "$(echo -e "  ${BOLD}Reboot now? [Y/n]:${RESET} ")" REBOOT
REBOOT="${REBOOT:-Y}"
if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
  info "Rebooting in 3 seconds..."
  sleep 3; reboot
else
  echo ""; info "Run ${CYAN}sudo reboot${RESET} when ready."
fi