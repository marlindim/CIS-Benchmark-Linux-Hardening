#!/bin/bash
# =============================================================
# harden.sh — CIS Benchmark Hardening Script
# Fixes security issues found by audit.sh
# =============================================================

LOG_FILE="$HOME/cis-hardening/logs/harden_$(date +%Y-%m-%d_%H-%M-%S).log"
CHANGES=0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
fixed() { log "  [FIXED] $1"; ((CHANGES++)); }
info() { log "  [INFO]  $1"; }

log "============================================="
log " CIS Hardening Script"
log " Date: $(date)"
log " Host: $(hostname)"
log "============================================="

# --- SSH HARDENING ---
log ""
log "[ Hardening SSH ]"

SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup original config first
if [ ! -f "$SSHD_CONFIG.bak" ]; then
    sudo cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak"
    info "Backed up original sshd_config to sshd_config.bak"
fi

# Disable root login
if ! grep -q "^PermitRootLogin no" "$SSHD_CONFIG"; then
    sudo sed -i 's/.*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    fixed "PermitRootLogin set to no"
fi

# Disable password authentication
if ! grep -q "^PasswordAuthentication no" "$SSHD_CONFIG"; then
    sudo sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
    fixed "PasswordAuthentication set to no"
fi

# Set SSH Protocol to 2
if ! grep -q "^Protocol 2" "$SSHD_CONFIG"; then
    echo "Protocol 2" | sudo tee -a "$SSHD_CONFIG" > /dev/null
    fixed "SSH Protocol set to 2"
fi

# Change SSH port from 22 to 2222
if ! grep -q "^Port 2222" "$SSHD_CONFIG"; then
    sudo sed -i 's/.*#Port 22.*/Port 2222/' "$SSHD_CONFIG"
    fixed "SSH port changed from 22 to 2222"
fi

# Restart SSH to apply changes
sudo systemctl restart ssh
fixed "SSH service restarted"

# --- PASSWORD POLICY ---
log ""
log "[ Hardening Password Policy ]"

# Set max password age to 90 days
if ! grep -q "^PASS_MAX_DAYS.*90" /etc/login.defs; then
    sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/' /etc/login.defs
    fixed "PASS_MAX_DAYS set to 90"
fi

# Set min password age to 7 days
if ! grep -q "^PASS_MIN_DAYS.*7" /etc/login.defs; then
    sudo sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS\t7/' /etc/login.defs
    fixed "PASS_MIN_DAYS set to 7"
fi

# Install and configure password complexity
if ! dpkg -l | grep -q libpam-pwquality; then
    sudo apt install -y libpam-pwquality > /dev/null 2>&1
    fixed "libpam-pwquality installed"
fi

# --- AUDIT LOGGING ---
log ""
log "[ Setting Up Audit Logging ]"

# Install auditd
if ! systemctl is-active --quiet auditd; then
    sudo apt install -y auditd > /dev/null 2>&1
    sudo systemctl enable auditd
    sudo systemctl start auditd
    fixed "auditd installed and started"
fi

# Add audit rules
AUDIT_RULES="/etc/audit/rules.d/cis.rules"
if [ ! -f "$AUDIT_RULES" ]; then
    sudo tee "$AUDIT_RULES" > /dev/null << 'EOF'
# CIS Benchmark Audit Rules

# Monitor authentication events
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity

# Monitor SSH config changes
-w /etc/ssh/sshd_config -p wa -k sshd

# Monitor privilege escalation
-w /bin/su -p x -k priv_esc
-w /usr/bin/sudo -p x -k priv_esc

# Monitor login/logout
-w /var/log/auth.log -p wa -k auth_log

# Monitor crontab
-w /etc/crontab -p wa -k cron
EOF
    sudo augenrules --load > /dev/null 2>&1
    fixed "Audit rules configured"
fi

# --- FILE PERMISSIONS ---
log ""
log "[ Fixing File Permissions ]"

# Fix crontab permissions
if [ "$(stat -c %a /etc/crontab)" != "600" ]; then
    sudo chmod 600 /etc/crontab
    fixed "/etc/crontab permissions set to 600"
fi

# Fix other sensitive files
sudo chmod 644 /etc/passwd
sudo chmod 640 /etc/shadow
sudo chmod 600 /etc/gshadow
fixed "Sensitive file permissions verified"

# --- DISABLE UNNECESSARY SERVICES ---
log ""
log "[ Disabling Unnecessary Services ]"

for service in telnet ftp rsh rlogin xinetd; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        sudo systemctl stop "$service"
        sudo systemctl disable "$service"
        fixed "$service disabled"
    else
        info "$service already inactive"
    fi
done

# --- SUMMARY ---
log ""
log "============================================="
log " HARDENING COMPLETE"
log " Total changes made: $CHANGES"
log " Log saved to: $LOG_FILE"
log "============================================="
log " IMPORTANT: Run audit.sh again to verify"
log "============================================="
