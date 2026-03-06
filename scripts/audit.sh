#!/bin/bash
# =============================================================
# audit.sh — CIS Benchmark Audit Script
# Checks current system security status before hardening
# =============================================================

REPORT_FILE="$HOME/cis-hardening/reports/audit_$(date +%Y-%m-%d_%H-%M-%S).txt"
PASS=0
FAIL=0

log() { echo "$1" | tee -a "$REPORT_FILE"; }
pass() { log "  [PASS] $1"; ((PASS++)); }
fail() { log "  [FAIL] $1"; ((FAIL++)); }

log "============================================="
log " CIS Benchmark Audit Report"
log " Date: $(date)"
log " Host: $(hostname)"
log "============================================="
log ""

# --- SSH HARDENING ---
log "[ SSH Configuration ]"

if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
    pass "PermitRootLogin is disabled"
else
    fail "PermitRootLogin is not explicitly disabled"
fi

if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    pass "PasswordAuthentication is disabled"
else
    fail "PasswordAuthentication is not explicitly disabled"
fi

if grep -q "^Protocol 2" /etc/ssh/sshd_config 2>/dev/null || \
   ssh -Q protocol 2>/dev/null | grep -q "2"; then
    pass "SSH Protocol 2 in use"
else
    fail "SSH Protocol not explicitly set to 2"
fi

if grep -qE "^Port [0-9]+" /etc/ssh/sshd_config; then
    PORT=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')
    if [ "$PORT" != "22" ]; then
        pass "SSH running on non-default port: $PORT"
    else
        fail "SSH running on default port 22"
    fi
else
    fail "SSH running on default port 22"
fi

log ""

# --- PASSWORD POLICY ---
log "[ Password Policy ]"

MAX_DAYS=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
if [ "$MAX_DAYS" -le 90 ] 2>/dev/null; then
    pass "Password max age is $MAX_DAYS days (<=90)"
else
    fail "Password max age is $MAX_DAYS days (should be <=90)"
fi

MIN_DAYS=$(grep "^PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}')
if [ "$MIN_DAYS" -ge 7 ] 2>/dev/null; then
    pass "Password min age is $MIN_DAYS days (>=7)"
else
    fail "Password min age is $MIN_DAYS days (should be >=7)"
fi

log ""

# --- AUDIT LOGGING ---
log "[ Audit Logging ]"

if systemctl is-active --quiet auditd; then
    pass "auditd is running"
else
    fail "auditd is not running"
fi

if sudo test -f /etc/audit/audit.rules; then
    pass "audit.rules file exists"
else
    fail "audit.rules file missing"
fi

log ""

# --- FILE PERMISSIONS ---
log "[ File Permissions ]"

if [ "$(stat -c %a /etc/passwd)" = "644" ]; then
    pass "/etc/passwd permissions are 644"
else
    fail "/etc/passwd permissions are $(stat -c %a /etc/passwd) (should be 644)"
fi

if [ "$(stat -c %a /etc/shadow)" = "640" ] || \
   [ "$(stat -c %a /etc/shadow)" = "000" ]; then
    pass "/etc/shadow permissions are restrictive"
else
    fail "/etc/shadow permissions are $(stat -c %a /etc/shadow) (should be 640)"
fi

if [ "$(stat -c %a /etc/crontab)" = "600" ]; then
    pass "/etc/crontab permissions are 600"
else
    fail "/etc/crontab permissions are $(stat -c %a /etc/crontab) (should be 600)"
fi

log ""

# --- UNNECESSARY SERVICES ---
log "[ Unnecessary Services ]"

for service in telnet ftp rsh rlogin; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        fail "$service is running (should be disabled)"
    else
        pass "$service is not running"
    fi
done

log ""

# --- FIREWALL ---
log "[ Firewall ]"

if systemctl is-active --quiet ufw 2>/dev/null || \
   systemctl is-active --quiet firewalld 2>/dev/null || \
   iptables -L 2>/dev/null | grep -qv "Chain INPUT (policy ACCEPT)"; then
    pass "Firewall appears to be active"
else
    fail "No active firewall detected"
fi

log ""

# --- SUMMARY ---
log "============================================="
log " SUMMARY"
log " Passed: $PASS"
log " Failed: $FAIL"
log " Total:  $((PASS + FAIL))"
log "============================================="
