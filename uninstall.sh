#!/bin/bash
# ============================================================
#  Brave Kiosk — Complete Uninstaller
#  Removes all packages, configs, and settings installed by
#  the Brave Kiosk installer
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
is_pi()     { [[ "$DISTRO_ID" == "raspbian" || "$DISTRO_ID" == "raspberrypi" ]]; }

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
echo -e "  ${CYAN}Kiosk Uninstaller${RESET} — Complete Removal"
echo ""
echo -e "  User      : ${BOLD}$KIOSK_USER${RESET}"
echo -e "  Home      : ${BOLD}$KIOSK_HOME${RESET}"
echo ""

# ── Require root ─────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  die "Please run with sudo:\n  sudo bash uninstall.sh"
fi

# ── Warning and confirmation ─────────────────────────────────
echo -e "${RED}${BOLD}⚠️  WARNING: This will completely remove Brave Kiosk${RESET}"
echo ""
echo "  This script will:"
echo "    • Remove Brave browser and kiosk-related packages"
echo "    • Delete all kiosk configuration files"
echo "    • Disable autologin"
echo "    • Restore original system settings where possible"
echo "    • NOT delete your personal files or home directory data"
echo ""
echo -e "${YELLOW}${BOLD}The following will be REMOVED:${RESET}"
echo "    • Brave browser (keeps your profile data by default)"
echo "    • Openbox window manager"
echo "    • unclutter, pavucontrol (if installed only for kiosk)"
echo "    • ~/start-kiosk.sh"
echo "    • ~/.config/openbox/ directory"
echo "    • ~/.bash_profile modifications"
echo "    • Autologin configuration"
echo "    • HDMI/RPi config.txt modifications (optional)"
echo ""
read -rp "$(echo -e "${RED}Type 'REMOVE' to confirm uninstall: ${RESET}")" CONFIRM
if [[ "$CONFIRM" != "REMOVE" ]]; then
  echo "Aborted."
  exit 0
fi

# ════════════════════════════════════════════════════════════
#  UNINSTALLATION
# ════════════════════════════════════════════════════════════

# ── 1. Remove Brave browser ─────────────────────────────────
header "Step 1/7 — Removing Brave browser"

if is_debian; then
  info "Removing Brave browser (Debian/Ubuntu)..."
  apt-get remove -y brave-browser brave-keyring 2>/dev/null || warn "Brave not installed via apt"
  rm -f /etc/apt/sources.list.d/brave-browser-release.list
  rm -f /usr/share/keyrings/brave-browser-archive-keyring.gpg
  apt-get update -qq
  
elif is_fedora; then
  info "Removing Brave browser (Fedora/RHEL)..."
  dnf remove -y brave-browser 2>/dev/null || warn "Brave not installed via dnf"
  rm -f /etc/yum.repos.d/brave-browser.repo
  
elif is_arch; then
  info "Removing Brave browser (Arch)..."
  if pacman -Qs brave-bin &>/dev/null; then
    pacman -Rns --noconfirm brave-bin 2>/dev/null || warn "Could not remove brave-bin"
  fi
  if pacman -Qs brave-browser &>/dev/null; then
    pacman -Rns --noconfirm brave-browser 2>/dev/null || warn "Could not remove brave-browser"
  fi
fi

success "Brave browser removed"

# ── 2. Remove kiosk packages (optional) ─────────────────────
header "Step 2/7 — Removing kiosk packages"

echo -e "  ${YELLOW}Note: Some packages may be needed for other purposes.${RESET}"
echo -e "  ${YELLOW}We'll only remove packages that were installed specifically for the kiosk.${RESET}"
echo ""
read -rp "$(echo -e "Remove kiosk packages (openbox, unclutter, pavucontrol, xinit)? [y/N]: ${RESET}")" REMOVE_PKGS

if [[ "$REMOVE_PKGS" =~ ^[Yy]$ ]]; then
  if is_debian; then
    apt-get remove -y openbox xinit unclutter pavucontrol 2>/dev/null || true
    apt-get autoremove -y
    
  elif is_fedora; then
    dnf remove -y openbox xinit unclutter pavucontrol 2>/dev/null || true
    dnf autoremove -y
    
  elif is_arch; then
    pacman -Rns --noconfirm openbox xorg-xinit unclutter pavucontrol 2>/dev/null || true
  fi
  success "Kiosk packages removed"
else
  info "Skipping package removal"
fi

# ── 3. Remove autologin configuration ───────────────────────
header "Step 3/7 — Disabling autologin"

AUTOLOGIN_CONF="/etc/systemd/system/getty@tty1.service.d/autologin.conf"
if [[ -f "$AUTOLOGIN_CONF" ]]; then
  rm -f "$AUTOLOGIN_CONF"
  success "Removed autologin configuration"
  
  # Remove the directory if empty
  rmdir "/etc/systemd/system/getty@tty1.service.d" 2>/dev/null || true
  
  # Reload systemd
  systemctl daemon-reexec
  info "Systemd reloaded — autologin disabled"
else
  warn "Autologin config not found"
fi

# ── 4. Remove logind lockdown config ────────────────────────
header "Step 4/7 — Removing logind lockdown"

LOGIND_CONF="/etc/systemd/logind.conf.d/kiosk.conf"
if [[ -f "$LOGIND_CONF" ]]; then
  rm -f "$LOGIND_CONF"
  success "Removed logind lockdown configuration"
  systemctl restart systemd-logind
else
  warn "Logind lockdown config not found"
fi

# ── 5. Remove kiosk files from user home ─────────────────────
header "Step 5/7 — Removing kiosk configuration files"

# Remove start-kiosk.sh
if [[ -f "$KIOSK_HOME/start-kiosk.sh" ]]; then
  rm -f "$KIOSK_HOME/start-kiosk.sh"
  success "Removed ~/start-kiosk.sh"
else
  warn "start-kiosk.sh not found"
fi

# Remove Openbox config
if [[ -d "$KIOSK_HOME/.config/openbox" ]]; then
  rm -rf "$KIOSK_HOME/.config/openbox"
  success "Removed ~/.config/openbox/"
else
  warn "Openbox config not found"
fi

# Clean up .bash_profile modifications
BASH_PROFILE="$KIOSK_HOME/.bash_profile"
if [[ -f "$BASH_PROFILE" ]]; then
  # Remove the kiosk autostart block
  if grep -q "Brave Kiosk: auto-start X" "$BASH_PROFILE"; then
    # Create a backup
    cp "$BASH_PROFILE" "$BASH_PROFILE.bak"
    # Remove the block (between the markers)
    sed -i '/# ── Brave Kiosk: auto-start X ──────────────────────/,/fi/d' "$BASH_PROFILE"
    # Remove trailing empty lines
    sed -i '/^$/N;/^\n$/D' "$BASH_PROFILE"
    success "Cleaned up ~/.bash_profile (backup saved as .bash_profile.bak)"
  else
    warn "Kiosk entry not found in .bash_profile"
  fi
else
  warn ".bash_profile not found"
fi

# Remove .xinitrc if it was created
if [[ -f "$KIOSK_HOME/.xinitrc" ]]; then
  rm -f "$KIOSK_HOME/.xinitrc"
  success "Removed ~/.xinitrc"
fi

# ── 6. Restore Raspberry Pi config.txt ──────────────────────
header "Step 6/7 — Restoring Raspberry Pi configuration"

if is_pi; then
  BOOT_CONFIG="/boot/firmware/config.txt"
  [[ -f "$BOOT_CONFIG" ]] || BOOT_CONFIG="/boot/config.txt"
  
  if [[ -f "$BOOT_CONFIG" ]] && grep -q "Kiosk display settings" "$BOOT_CONFIG"; then
    # Create backup before modifying
    cp "$BOOT_CONFIG" "$BOOT_CONFIG.bak.$(date +%Y%m%d_%H%M%S)"
    
    # Remove the kiosk block
    sed -i '/# Kiosk display settings/,/disable_overscan=1/d' "$BOOT_CONFIG"
    success "Removed HDMI config from $BOOT_CONFIG"
    warn "Original config backed up to $BOOT_CONFIG.bak.*"
  else
    warn "Kiosk HDMI config not found in $BOOT_CONFIG"
  fi
  
  # Reset audio to default (auto)
  if command -v raspi-config &>/dev/null; then
    read -rp "$(echo -e "Reset Raspberry Pi audio to default (auto)? [y/N]: ${RESET}")" RESET_AUDIO
    if [[ "$RESET_AUDIO" =~ ^[Yy]$ ]]; then
      raspi-config nonint do_audio 0 && success "Audio reset to default"
    fi
  fi
else
  info "Not a Raspberry Pi — skipping Pi-specific cleanup"
fi

# ── 7. Clean up Brave profile (optional) ────────────────────
header "Step 7/7 — Brave user profile (optional)"

echo ""
echo -e "  ${YELLOW}Brave keeps your browsing data, cookies, and settings in:${RESET}"
echo "    ~/.config/BraveSoftware/Brave-Browser/"
echo ""
read -rp "$(echo -e "Delete Brave profile data for user '$KIOSK_USER'? [y/N]: ${RESET}")" DELETE_PROFILE

if [[ "$DELETE_PROFILE" =~ ^[Yy]$ ]]; then
  if [[ -d "$KIOSK_HOME/.config/BraveSoftware" ]]; then
    rm -rf "$KIOSK_HOME/.config/BraveSoftware"
    success "Brave profile data deleted"
  else
    warn "Brave profile not found"
  fi
else
  info "Keeping Brave profile data"
fi

# ════════════════════════════════════════════════════════════
#  SUMMARY
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  Uninstall complete!${RESET}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${BOLD}Removed:${RESET}"
echo "    ✓ Brave browser"
[[ "$REMOVE_PKGS" =~ ^[Yy]$ ]] && echo "    ✓ Kiosk packages (openbox, unclutter, pavucontrol)"
echo "    ✓ Autologin configuration"
echo "    ✓ Kiosk startup scripts"
echo "    ✓ Openbox keybind configuration"
[[ -f "$BASH_PROFILE.bak" ]] && echo "    ✓ .bash_profile modifications (backup saved)"
[[ "$DELETE_PROFILE" =~ ^[Yy]$ ]] && echo "    ✓ Brave profile data"
echo ""
echo -e "  ${YELLOW}${BOLD}Manual cleanup may be needed:${RESET}"
echo "    • Check ~/.bash_profile backup if you need to restore anything"
echo "    • On Raspberry Pi, check /boot/config.txt backup files"
echo "    • Reboot to ensure all changes take effect"
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