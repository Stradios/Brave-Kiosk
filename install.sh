#!/bin/bash
# ============================================================
#  v0.03 Brave Kiosk — with display switcher (Ctrl+Alt+P)
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

# ── Detect current user ─────────────────────────────────────
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
echo -e "  ${CYAN}Kiosk Installer${RESET} — Brave + Display Switcher"
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

# ── Ask for keybinds ─────────────────────────────────────────
header "Keybind Configuration"
echo -e "  Choose keybinds for:"
echo -e "    • Audio mixer    (default: ${CYAN}C-A-a${RESET})"
echo -e "    • Display output (default: ${CYAN}C-A-p${RESET})"
echo ""

read -rp "$(echo -e "  ${BOLD}Audio keybind [C-A-a]:${RESET} ")" AUDIO_KEYBIND
AUDIO_KEYBIND="${AUDIO_KEYBIND:-C-A-a}"

read -rp "$(echo -e "  ${BOLD}Display switcher keybind [C-A-p]:${RESET} ")" DISPLAY_KEYBIND
DISPLAY_KEYBIND="${DISPLAY_KEYBIND:-C-A-p}"

success "Audio keybind: $AUDIO_KEYBIND"
success "Display switcher keybind: $DISPLAY_KEYBIND"

# ════════════════════════════════════════════════════════════
#  INSTALLATION
# ════════════════════════════════════════════════════════════

# ── 1. Install packages ──────────────────────────────────────
header "Step 1/7 — Installing packages"

# Determine which dialog tool to use
if is_debian || is_fedora || is_arch; then
  if is_debian; then
    apt-get update -qq
    apt-get install -y curl zenity whiptail
  elif is_fedora; then
    dnf install -y curl zenity newt
  elif is_arch; then
    pacman -S --needed --noconfirm curl zenity
  fi
fi

if is_pi && [[ "$ARCH_LABEL" == "aarch64" ]]; then
  info "Raspberry Pi OS (aarch64) detected — installing Brave via Snap"
  apt-get update -qq
  apt-get install -y snapd xorg openbox xinit unclutter \
    pulseaudio pulseaudio-utils pavucontrol x11-xserver-utils zenity whiptail
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
    pulseaudio pulseaudio-utils pavucontrol x11-xserver-utils zenity whiptail
  BRAVE_BIN="brave-browser"

elif is_fedora; then
  info "Fedora/RHEL detected — adding Brave rpm repo"
  rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
  dnf config-manager --add-repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
  dnf install -y brave-browser xorg-x11-server-Xorg openbox xinit unclutter \
    pulseaudio pulseaudio-utils pavucontrol xrandr zenity newt
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
    pulseaudio pavucontrol xorg-xrandr zenity
  BRAVE_BIN="brave-browser"

else
  die "Unsupported distro: $DISTRO_ID\nSupported: Ubuntu, Debian, Fedora, RHEL, Arch, Raspberry Pi OS"
fi

success "Packages installed"

# ── 2. Autologin ─────────────────────────────────────────────
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

# ── 3. Raspberry Pi display tweaks ───────────────────────────
if is_pi; then
  header "Step 3/7 — Raspberry Pi display & audio tweaks"
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
  if command -v raspi-config &>/dev/null; then
    raspi-config nonint do_audio 2 && success "HDMI audio forced via raspi-config"
  fi
else
  header "Step 3/7 — (Pi-only tweaks skipped)"
  info "Not a Raspberry Pi — skipping firmware config"
fi

# ── 4. Create display switcher script ───────────────────────
header "Step 4/7 — Creating display switcher (Ctrl+Alt+P)"

cat > "$KIOSK_HOME/display-switcher.sh" <<'SWITCHEREOF'
#!/bin/bash
# Display output switcher for Brave Kiosk
# Press Ctrl+Alt+P (or your configured keybind) to open this menu

DISPLAY_NUM="${DISPLAY:-:0}"
export DISPLAY="$DISPLAY_NUM"

# Function to show menu using zenity (GUI) if available
show_gui_menu() {
    # Get list of connected monitors
    local monitors=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^([a-zA-Z0-9\-]+)\ connected\ ([0-9x+]+)\ (.*) ]]; then
            monitor="${BASH_REMATCH[1]}"
            resolution="${BASH_REMATCH[2]}"
            monitors+=("$monitor" "$resolution")
        fi
    done < <(xrandr --query | grep " connected")
    
    if [[ ${#monitors[@]} -eq 0 ]]; then
        zenity --error --text="No external monitors detected!" --title="Display Switcher"
        return 1
    fi
    
    # Add special options
    local options=()
    for ((i=0; i<${#monitors[@]}; i+=2)); do
        options+=("${monitors[$i]}" "${monitors[$i+1]}")
    done
    options+=("MIRROR" "Clone/Mirror all displays")
    options+=("SPAN" "Span across all displays (extended desktop)")
    options+=("AUTO" "Auto-detect (system default)")
    
    # Show selection dialog
    selected=$(zenity --list \
        --title="Display Switcher" \
        --text="Select display output mode:" \
        --column="Output" \
        --column="Mode/Resolution" \
        "${options[@]}" \
        --height=400 \
        --width=500)
    
    case "$selected" in
        MIRROR)
            apply_mirror_mode
            ;;
        SPAN)
            apply_span_mode
            ;;
        AUTO)
            apply_auto_mode
            ;;
        "")
            return 0
            ;;
        *)
            apply_single_monitor "$selected"
            ;;
    esac
}

# Function to show menu using whiptail (terminal)
show_terminal_menu() {
    local monitors=()
    local i=1
    local menu_options=()
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^([a-zA-Z0-9\-]+)\ connected ]]; then
            monitor="${BASH_REMATCH[1]}"
            resolution=$(xrandr --query | grep "^$monitor" | grep "connected" | awk '{print $3}')
            monitors+=("$monitor")
            menu_options+=("$i" "$monitor - $resolution")
            ((i++))
        fi
    done < <(xrandr --query | grep " connected")
    
    if [[ ${#monitors[@]} -eq 0 ]]; then
        whiptail --title "Display Switcher" --msgbox "No external monitors detected!" 8 45
        return 1
    fi
    
    menu_options+=("M" "Mirror/Clone all displays")
    menu_options+=("S" "Span across all displays")
    menu_options+=("A" "Auto-detect (system default)")
    menu_options+=("C" "Cancel")
    
    choice=$(whiptail --title "Display Switcher" \
        --menu "Choose display output mode:" \
        20 60 10 \
        "${menu_options[@]}" \
        3>&1 1>&2 2>&3)
    
    case "$choice" in
        M|m)
            apply_mirror_mode
            ;;
        S|s)
            apply_span_mode
            ;;
        A|a)
            apply_auto_mode
            ;;
        C|c|"")
            return 0
            ;;
        *)
            # Number selected
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#monitors[@]} ]; then
                apply_single_monitor "${monitors[$((choice-1))]}"
            fi
            ;;
    esac
}

apply_single_monitor() {
    local monitor="$1"
    echo "Switching to single monitor: $monitor"
    
    # Disable all other monitors, enable only the selected one
    for output in $(xrandr --query | grep " connected" | awk '{print $1}'); do
        if [[ "$output" == "$monitor" ]]; then
            xrandr --output "$output" --auto --primary
        else
            xrandr --output "$output" --off
        fi
    done
    
    # Save configuration
    echo "$monitor" > "$HOME/.kiosk-display-mode"
    echo "single" >> "$HOME/.kiosk-display-mode"
    
    # Show notification if zenity is available
    if command -v zenity &>/dev/null; then
        zenity --info --text="Display switched to: $monitor" --timeout=2 2>/dev/null &
    fi
}

apply_mirror_mode() {
    echo "Switching to mirror/clone mode"
    
    local primary=""
    local first=""
    
    # Get first monitor as primary
    for output in $(xrandr --query | grep " connected" | awk '{print $1}'); do
        if [[ -z "$primary" ]]; then
            primary="$output"
            xrandr --output "$output" --auto --primary
            first="$output"
        else
            xrandr --output "$output" --same-as "$primary" --auto
        fi
    done
    
    # Save configuration
    echo "mirror" > "$HOME/.kiosk-display-mode"
    
    if command -v zenity &>/dev/null; then
        zenity --info --text="Mirror mode enabled\nAll displays show the same content" --timeout=2 2>/dev/null &
    fi
}

apply_span_mode() {
    echo "Switching to span/extended mode"
    
    # Enable all monitors in their preferred modes
    xrandr --auto
    
    # Save configuration
    echo "span" > "$HOME/.kiosk-display-mode"
    
    if command -v zenity &>/dev/null; then
        zenity --info --text="Span mode enabled\nDesktop extended across all displays" --timeout=2 2>/dev/null &
    fi
}

apply_auto_mode() {
    echo "Switching to auto-detect mode"
    
    xrandr --auto
    
    # Save configuration
    echo "auto" > "$HOME/.kiosk-display-mode"
    
    if command -v zenity &>/dev/null; then
        zenity --info --text="Auto-detect mode enabled\nUsing system defaults" --timeout=2 2>/dev/null &
    fi
}

# Main execution
if ! command -v xrandr &>/dev/null; then
    echo "xrandr not found. Please install x11-xserver-utils"
    exit 1
fi

# Detect if we're in a GUI environment
if command -v zenity &>/dev/null && [[ -n "$DISPLAY" ]]; then
    show_gui_menu
elif command -v whiptail &>/dev/null; then
    show_terminal_menu
else
    # Fallback to simple text menu
    echo "Display Switcher"
    echo "==============="
    echo ""
    xrandr --query | grep " connected"
    echo ""
    echo "Commands:"
    echo "  xrandr --output HDMI-1 --auto --primary    # Use HDMI-1 only"
    echo "  xrandr --auto                               # Auto-detect all"
    echo "  xrandr --output HDMI-1 --same-as eDP-1     # Mirror displays"
    echo ""
    read -p "Run xrandr command manually: " cmd
    eval "$cmd"
fi

# Restart Brave to apply new display settings
echo "Restarting Brave to apply display changes..."
sleep 1
pkill -f "brave.*kiosk" 2>/dev/null || true
sleep 2
# Brave will be restarted by the start-kiosk.sh script automatically

echo "Display configuration updated!"
SWITCHEREOF

chmod +x "$KIOSK_HOME/display-switcher.sh"
chown "$KIOSK_USER:$KIOSK_USER" "$KIOSK_HOME/display-switcher.sh"
success "Display switcher created at $KIOSK_HOME/display-switcher.sh"

# ── 5. Openbox keybind config ────────────────────────────────
header "Step 5/7 — Configuring Openbox keybinds"

OPENBOX_DIR="$KIOSK_HOME/.config/openbox"
mkdir -p "$OPENBOX_DIR"

cat > "$OPENBOX_DIR/rc.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">

  <keyboard>

    <!-- $AUDIO_KEYBIND → open PulseAudio volume control -->
    <keybind key="$AUDIO_KEYBIND">
      <action name="Execute">
        <command>pavucontrol</command>
      </action>
    </keybind>

    <!-- $DISPLAY_KEYBIND → open display switcher -->
    <keybind key="$DISPLAY_KEYBIND">
      <action name="Execute">
        <command>$KIOSK_HOME/display-switcher.sh</command>
      </action>
    </keybind>

    <!-- Ctrl+Alt+T → terminal (for debugging) -->
    <keybind key="C-A-t">
      <action name="Execute">
        <command>x-terminal-emulator</command>
      </action>
    </keybind>

    <!-- Ctrl+Alt+R → restart Brave (refresh kiosk) -->
    <keybind key="C-A-r">
      <action name="Execute">
        <command>pkill -f "brave.*kiosk"</command>
      </action>
    </keybind>

  </keyboard>

</openbox_config>
EOF

chown -R "$KIOSK_USER:$KIOSK_USER" "$OPENBOX_DIR"
success "Openbox config written to $OPENBOX_DIR/rc.xml"

# ── 6. Generate start-kiosk.sh ───────────────────────────────
header "Step 6/7 — Generating start-kiosk.sh"

cat > "$KIOSK_HOME/start-kiosk.sh" <<EOF
#!/bin/bash
# Auto-generated by Brave Kiosk Installer

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

# ── Apply saved display mode if it exists ────────────────────
if [[ -f "\$HOME/.kiosk-display-mode" ]]; then
    MODE=\$(head -n1 "\$HOME/.kiosk-display-mode")
    echo "Restoring saved display mode: \$MODE"
    case "\$MODE" in
        single)
            MONITOR=\$(sed -n '2p' "\$HOME/.kiosk-display-mode")
            if [[ -n "\$MONITOR" ]]; then
                for output in \$(xrandr --query | grep " connected" | awk '{print \$1}'); do
                    if [[ "\$output" == "\$MONITOR" ]]; then
                        xrandr --output "\$output" --auto --primary
                    else
                        xrandr --output "\$output" --off
                    fi
                done
            fi
            ;;
        mirror)
            PRIMARY=""
            for output in \$(xrandr --query | grep " connected" | awk '{print \$1}'); do
                if [[ -z "\$PRIMARY" ]]; then
                    PRIMARY="\$output"
                    xrandr --output "\$output" --auto --primary
                else
                    xrandr --output "\$output" --same-as "\$PRIMARY" --auto
                fi
            done
            ;;
        span|auto)
            xrandr --auto
            ;;
    esac
else
    # Default: auto-detect displays
    xrandr --auto
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

# ── 7. Auto-start X on tty1 login ───────────────────────────
header "Step 7/7 — Configuring auto-start on login"

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
echo ""
echo -e "  ${BOLD}Keybindings:${RESET}"
echo -e "    • ${CYAN}$AUDIO_KEYBIND${RESET}     → Open audio mixer"
echo -e "    • ${CYAN}$DISPLAY_KEYBIND${RESET}   → Open display switcher"
echo -e "    • ${CYAN}C-A-t${RESET}       → Open terminal"
echo -e "    • ${CYAN}C-A-r${RESET}       → Restart Brave"
echo ""
echo -e "  ${BOLD}Display Switcher Features:${RESET}"
echo -e "    • Single monitor   — Use only one display"
echo -e "    • Mirror/Clone     — Same content on all displays"
echo -e "    • Span/Extended    — Desktop across all displays"
echo -e "    • Auto-detect      — System default behavior"
echo ""
echo -e "  ${BOLD}Files written:${RESET}"
echo -e "    ${CYAN}$KIOSK_HOME/start-kiosk.sh${RESET}"
echo -e "    ${CYAN}$KIOSK_HOME/display-switcher.sh${RESET}"
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