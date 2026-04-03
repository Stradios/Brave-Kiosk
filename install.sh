#!/bin/bash
# ============================================================
#  v0.01 Brave Kiosk — one-shot installer
#  https://github.com/Stradios/Brave-Kiosk
#
#  Supports:
#    • Ubuntu / Debian (x86_64)
#    • Fedora / RHEL   (x86_64)
#    • Arch Linux      (x86_64)
#    • Raspberry Pi OS (aarch64)
# ============================================================

set -euo pipefail

# ── Colours ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[info]${RESET}  $*"; }
success() { echo -e "${GREEN}[ok]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[warn]${RESET}  $*"; }
die()     { echo -e "${RED}[error]${RESET} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}$*${RESET}"; echo "────────────────────────────────────────"; }

# ── Detect current user (works with and without sudo) ───────
KIOSK_USER="${SUDO_USER:-$USER}"
KIOSK_HOME=$(eval echo "~$KIOSK_USER")

# ── Detect architecture ──────────────────────────────────────
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)         ARCH_LABEL="x86_64" ;;
  aarch64|arm64)  ARCH_LABEL="aarch64" ;;
  *)              die "Unsupported architecture: $ARCH" ;;
esac

# ── Detect distro ────────────────────────────────────────────
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  DISTRO_ID="${ID:-unknown}"
  DISTRO_LIKE="${ID_LIKE:-}"
else
  die "Cannot detect distro — /etc/os-release not found."
fi

is_debian() { [[ "$DISTRO_ID" == "debian" || "$DISTRO_ID" == "ubuntu" || "$DISTRO_ID" == "raspbian" || "$DISTRO_LIKE" == *"debian"* ]]; }
is_fedora() { [[ "$DISTRO_ID" == "fedora" || "$DISTRO_ID" == "rhel"   || "$DISTRO_LIKE" == *"fedora"* || "$DISTRO_LIKE" == *"rhel"* ]]; }
is_arch()   { [[ "$DISTRO_ID" == "arch"   || "$DISTRO_ID" == "manjaro" || "$DISTRO_LIKE" == *"arch"* ]]; }
is_pi()     { [[ "$DISTRO_ID" == "raspbian" || ("$DISTRO_ID" == "debian" && "$ARCH_LABEL" == "aarch64") ]]; }

# ── Banner ───────────────────────────────────────────────────
clear
echo -e "${BOLD}"
echo "  ██████╗ ██████╗  █████╗ ██╗   ██╗███████╗"
echo "  ██╔══██╗██╔══██╗██╔══██╗██║   ██║██╔════╝"
echo "  ██████╔╝██████╔╝███████║██║   ██║█████╗  "
echo "  ██╔══██╗██╔══██╗██╔══██║╚██╗ ██╔╝██╔══╝  "
echo "  ██████╔╝██║  ██║██║  ██║ ╚████╔╝ ███████╗"
echo "  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝"
echo -e "${RESET}"
echo -e "  ${CYAN}Kiosk Installer${RESET} — Brave + Openbox + HDMI Audio"
echo ""
echo -e "  User      : ${BOLD}$KIOSK_USER${RESET}"
echo -e "  Home      : ${BOLD}$KIOSK_HOME${RESET}"
echo -e "  Arch      : ${BOLD}$ARCH_LABEL${RESET}"
echo -e "  Distro    : ${BOLD}$PRETTY_NAME${RESET}"
echo ""

# ── Require root ─────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  die "Please run with sudo:\n  sudo bash install.sh"
fi

# ── Confirm before proceeding ────────────────────────────────
read -rp "$(echo -e "${YELLOW}Continue with installation? [Y/n]:${RESET} ")" CONFIRM
CONFIRM="${CONFIRM:-Y}"
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── Ask for the kiosk URL ────────────────────────────────────
header "Kiosk URL"
echo -e "  Enter the website your kiosk should display on startup."
echo -e "  Examples:"
echo -e "    ${CYAN}https://your-company.no${RESET}"
echo -e "    ${CYAN}https://dashboard.example.com${RESET}"
echo -e "    ${CYAN}file:///home/$KIOSK_USER/index.html${RESET}"
echo ""

while true; do
  read -rp "$(echo -e "  ${BOLD}URL:${RESET} ")" KIOSK_URL
  KIOSK_URL="${KIOSK_URL:-}"
  if [[ -z "$KIOSK_URL" ]]; then
    warn "URL cannot be empty. Please enter a valid address."
  elif [[ ! "$KIOSK_URL" =~ ^(https?://|file://) ]]; then
    warn "URL must start with https://, http://, or file://"
    read -rp "$(echo -e "  ${YELLOW}Use '$KIOSK_URL' anyway? [y/N]:${RESET} ")" USE_ANYWAY
    [[ "$USE_ANYWAY" =~ ^[Yy]$ ]] && break
  else
    break
  fi
done

success "Kiosk URL set to: $KIOSK_URL"

# ── Ask for keybind ──────────────────────────────────────────
header "Audio Keybind"
echo -e "  Choose a keybind to open the PulseAudio mixer (pavucontrol)."
echo -e "  Openbox syntax: C=Ctrl, A=Alt, S=Shift, W=Super"
echo -e "  Default: ${CYAN}C-A-a${RESET}  (Ctrl+Alt+A)"
echo ""
read -rp "$(echo -e "  ${BOLD}Keybind [C-A-a]:${RESET} ")" KEYBIND
KEYBIND="${KEYBIND:-C-A-a}"
success "Audio keybind set to: $KEYBIND"

# ════════════════════════════════════════════════════════════
#  INSTALLATION
# ════════════════════════════════════════════════════════════

# ── 1. Install packages ──────────────────────────────────────
header "Step 1/6 — Installing packages"

if is_pi && [[ "$ARCH_LABEL" == "aarch64" ]]; then
  info "Raspberry Pi OS (aarch64) detected — installing Brave via Snap"
  apt-get update -qq
  apt-get install -y snapd xorg openbox xinit unclutter \
    pulseaudio pulseaudio-utils pavucontrol
  snap install brave
  BRAVE_BIN="/snap/bin/brave"

elif is_debian; then
  info "Debian/Ubuntu detected — adding Brave apt repo"
  apt-get update -qq
  apt-get install -y curl
  curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
    https://brave-browser-apt-release.s3.brave.com/ stable main" \
    > /etc/apt/sources.list.d/brave-browser-release.list
  apt-get update -qq
  apt-get install -y brave-browser xorg openbox xinit unclutter \
    pulseaudio pulseaudio-utils pavucontrol
  BRAVE_BIN="brave-browser"

elif is_fedora; then
  info "Fedora/RHEL detected — adding Brave rpm repo"
  rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
  dnf config-manager --add-repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
  dnf install -y brave-browser xorg-x11-server-Xorg openbox xinit unclutter \
    pulseaudio pulseaudio-utils pavucontrol
  BRAVE_BIN="brave-browser"

elif is_arch; then
  info "Arch Linux detected"
  if ! command -v yay &>/dev/null; then
    info "Installing yay AUR helper..."
    pacman -S --needed --noconfirm base-devel git
    sudo -u "$KIOSK_USER" bash -c '
      git clone https://aur.archlinux.org/yay.git /tmp/yay-install
      cd /tmp/yay-install && makepkg -si --noconfirm
    '
  fi
  sudo -u "$KIOSK_USER" yay -S --noconfirm brave-bin
  pacman -S --needed --noconfirm xorg-server xorg-xinit openbox unclutter \
    pulseaudio pavucontrol
  BRAVE_BIN="brave-browser"

else
  die "Unsupported distro: $DISTRO_ID\nSupported: Ubuntu, Debian, Fedora, RHEL, Arch, Raspberry Pi OS"
fi

success "Packages installed"

# ── 2. Autologin ─────────────────────────────────────────────
header "Step 2/6 — Configuring autologin"

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF

systemctl daemon-reexec
systemctl restart getty@tty1
success "Autologin configured for: $KIOSK_USER"

# ── 3. Raspberry Pi display tweaks ───────────────────────────
if is_pi; then
  header "Step 3/6 — Raspberry Pi display & audio tweaks"
  BOOT_CONFIG="/boot/firmware/config.txt"
  [[ -f "$BOOT_CONFIG" ]] || BOOT_CONFIG="/boot/config.txt"
  if ! grep -q "hdmi_force_hotplug" "$BOOT_CONFIG"; then
    cat >> "$BOOT_CONFIG" <<'EOF'

# Kiosk display settings
hdmi_force_hotplug=1
hdmi_drive=2
disable_overscan=1
EOF
    success "HDMI config written to $BOOT_CONFIG"
  else
    warn "HDMI config already present in $BOOT_CONFIG — skipping"
  fi
  # Force HDMI audio at firmware level
  if command -v raspi-config &>/dev/null; then
    raspi-config nonint do_audio 2 && success "HDMI audio forced via raspi-config"
  fi
else
  header "Step 3/6 — (Pi-only tweaks skipped)"
  info "Not a Raspberry Pi — skipping firmware config"
fi

# ── 4. Openbox keybind config ────────────────────────────────
header "Step 4/6 — Configuring Openbox keybinds"

OPENBOX_DIR="$KIOSK_HOME/.config/openbox"
mkdir -p "$OPENBOX_DIR"

cat > "$OPENBOX_DIR/rc.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">

  <keyboard>

    <!-- $KEYBIND → open PulseAudio volume control -->
    <keybind key="$KEYBIND">
      <action name="Execute">
        <command>pavucontrol</command>
      </action>
    </keybind>

    <!-- Ctrl+Alt+T → terminal (for debugging) -->
    <keybind key="C-A-t">
      <action name="Execute">
        <command>x-terminal-emulator</command>
      </action>
    </keybind>

  </keyboard>

</openbox_config>
EOF

chown -R "$KIOSK_USER:$KIOSK_USER" "$OPENBOX_DIR"
success "Openbox config written to $OPENBOX_DIR/rc.xml"

# ── 5. Generate start-kiosk.sh ───────────────────────────────
header "Step 5/6 — Generating start-kiosk.sh"

cat > "$KIOSK_HOME/start-kiosk.sh" <<EOF
#!/bin/bash
# Auto-generated by Brave Kiosk Installer
# Re-run install.sh to regenerate with new settings

URL="$KIOSK_URL"
BRAVE="$BRAVE_BIN"
DISPLAY_NUM=":0"

export DISPLAY="\$DISPLAY_NUM"

# Disable screen blanking and screensaver
xset -dpms
xset s off
xset s noblank

# Hide cursor after 3 s of inactivity
command -v unclutter &>/dev/null && unclutter -idle 3 -root &

# Start Openbox (loads keybinds from ~/.config/openbox/rc.xml)
openbox-session &
sleep 2

# ── PulseAudio: start and route to HDMI ──────────────────────
pulseaudio --start --log-target=syslog

# Wait for PulseAudio to be ready (up to 10 s)
timeout 10 bash -c 'until pactl info &>/dev/null; do sleep 0.5; done'

# Auto-select first HDMI sink
HDMI_SINK=\$(pactl list short sinks | grep -i hdmi | awk '{print \$2}' | head -n1)
if [[ -n "\$HDMI_SINK" ]]; then
  pactl set-default-sink "\$HDMI_SINK"
  echo "Audio routed to: \$HDMI_SINK"
else
  echo "No HDMI sink found — using system default"
fi

# ── Launch Brave in kiosk mode ────────────────────────────────
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
EOF

chmod +x "$KIOSK_HOME/start-kiosk.sh"
chown "$KIOSK_USER:$KIOSK_USER" "$KIOSK_HOME/start-kiosk.sh"
success "start-kiosk.sh written to $KIOSK_HOME/start-kiosk.sh"

# ── 6. Auto-start X on tty1 login ───────────────────────────
header "Step 6/6 — Configuring auto-start on login"

BASH_PROFILE="$KIOSK_HOME/.bash_profile"
AUTOSTART_BLOCK='
# ── Brave Kiosk: auto-start X on tty1 ──────────────────────
if [[ -z "$DISPLAY" ]] && [[ "$(tty)" == "/dev/tty1" ]]; then
    exec startx ~/start-kiosk.sh
fi'

if grep -q "start-kiosk.sh" "$BASH_PROFILE" 2>/dev/null; then
  warn ".bash_profile already has kiosk entry — skipping"
else
  echo "$AUTOSTART_BLOCK" >> "$BASH_PROFILE"
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
echo -e "  ${BOLD}Kiosk URL   :${RESET} $KIOSK_URL"
echo -e "  ${BOLD}Brave binary:${RESET} $BRAVE_BIN"
echo -e "  ${BOLD}User        :${RESET} $KIOSK_USER"
echo -e "  ${BOLD}Audio key   :${RESET} $KEYBIND  (opens pavucontrol)"
echo -e "  ${BOLD}Terminal key:${RESET} Ctrl+Alt+T"
echo ""
echo -e "  Files written:"
echo -e "    ${CYAN}$KIOSK_HOME/start-kiosk.sh${RESET}"
echo -e "    ${CYAN}$KIOSK_HOME/.config/openbox/rc.xml${RESET}"
echo -e "    ${CYAN}/etc/systemd/system/getty@tty1.service.d/autologin.conf${RESET}"
echo ""
echo -e "  ${YELLOW}To apply all changes, reboot now:${RESET}"
echo ""
read -rp "$(echo -e "  ${BOLD}Reboot now? [Y/n]:${RESET} ")" REBOOT
REBOOT="${REBOOT:-Y}"
if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
  info "Rebooting in 3 seconds..."
  sleep 3
  reboot
else
  echo ""
  info "Reboot skipped. Run ${CYAN}sudo reboot${RESET} when ready."
fi
