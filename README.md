# CIS Benchmark Linux Hardening

Automated CIS benchmark audit and hardening scripts for Debian Linux.

## Scripts
- `audit.sh` — audits current system security posture
- `harden.sh` — applies CIS benchmark fixes automatically

## Results
| | Before | After |
|--|--------|-------|
| Passed | 7/16 | 16/16 |
| Failed | 9 | 0 |

## What Gets Hardened
- SSH: root login disabled, password auth disabled, non-default port
- Password policy: 90-day max age, 7-day min age, complexity enforced
- Audit logging: auditd installed with CIS rules
- File permissions: /etc/passwd, /etc/shadow, /etc/crontab
- Unnecessary services: telnet, ftp, rsh, rlogin disabled

## Usage

### Run audit only
```bash
./scripts/audit.sh
```

### Run hardening
```bash
./scripts/harden.sh
```

### Run audit again to verify
```bash
./scripts/audit.sh
```
