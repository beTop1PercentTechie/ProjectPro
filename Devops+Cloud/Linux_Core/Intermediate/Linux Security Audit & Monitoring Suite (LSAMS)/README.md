# Linux Security Audit & Monitoring Suite (LSAMS)

A Bash-based automation tool that performs comprehensive security auditing,
user activity monitoring, system health analysis, and compliance checks on
Linux servers. LSAMS scans for security vulnerabilities, configuration
issues, suspicious activity, and resource utilization, then generates a
scored, prioritized report with concrete remediation steps.

Designed for Ubuntu 24.04+ LTS; verified end-to-end on a live Ubuntu 26.04 LTS
EC2 instance.

## Features

- **User & access audits** - privileged accounts, empty passwords, sudo
  membership, password aging, inactive accounts.
- **SSH hardening checks** - root login, password auth, key permissions,
  and other `sshd_config` settings.
- **Filesystem checks** - SUID/SGID binaries, world-writable files, unowned
  files, and permissions on critical config files.
- **System health monitoring** - CPU load, memory, disk usage, top
  processes, failed systemd units.
- **Network & firewall audit** - listening ports, legacy/insecure
  services, firewall status, active connections.
- **Authentication log analysis** - failed logins, brute-force source IPs,
  sudo activity, invalid-user scan attempts.
- **Package & kernel audit** - pending updates, unattended-upgrades
  status, kernel currency, pending reboots.
- **Configurable compliance checklist** - a CIS-benchmark-style pass/fail
  list, toggled entirely through a config file.
- **Service audit** - unnecessary services left running by default.
- **Scored reporting** - a 0-100 security score and LOW/MEDIUM/HIGH/CRITICAL
  risk rating, exported as TXT, HTML, and/or JSON.
- **Alerting** - optional Email, Slack, and Telegram notifications when the
  score drops below a configurable threshold.
- **Automation** - a cron helper installs/removes a scheduled audit with
  one command.

## Quick start

```bash
git clone <repository-url> lsams
cd lsams
sudo ./install.sh --symlink

sudo lsams --quick     # fast subset of checks
sudo lsams --full       # full audit, all 9 modules
```

Reports land in `reports/`; a full run log lands in `logs/`.

## Project layout

```
LSAMS/
├── lsams.sh                    # Main entry point: CLI parsing & orchestration
├── bin/
│   └── lsams                   # Relocatable wrapper, symlinked onto PATH by install.sh
├── install.sh                  # Sets up directories/permissions, optional PATH symlink
├── uninstall.sh                # Reverses install.sh
├── config/
│   ├── lsams.conf              # Thresholds, report formats, alert channels
│   └── compliance_rules.conf   # Enable/disable individual compliance checks
├── lib/
│   ├── core/                   # Shared foundation used by every module
│   │   ├── colors.sh           # Terminal color codes
│   │   ├── logger.sh           # Timestamped, color-coded logging
│   │   ├── utils.sh            # Small shared helpers (require_root, trim, ...)
│   │   ├── config_loader.sh    # Loads config/lsams.conf with safe defaults
│   │   ├── findings.sh         # Central findings store + security scoring
│   │   └── report_engine.sh    # Renders TXT/HTML/JSON reports
│   └── modules/                # One file per audit domain (see docs/MODULES.md)
│       ├── 01_user_audit.sh
│       ├── 02_ssh_audit.sh
│       ├── 03_file_permissions.sh
│       ├── 04_system_health.sh
│       ├── 05_network_audit.sh
│       ├── 06_auth_log_analysis.sh
│       ├── 07_package_kernel_audit.sh
│       ├── 08_compliance_check.sh
│       └── 09_service_audit.sh
├── alerts/
│   ├── email_notify.sh
│   ├── slack_notify.sh
│   └── telegram_notify.sh
├── cron/
│   └── lsams_scheduler.sh      # Installs/removes the scheduled audit
├── tests/
│   ├── run_tests.sh            # Test runner (discovers test_*.sh)
│   └── test_core_lib.sh        # Unit tests for lib/core
├── docs/
│   ├── INSTALL.md
│   ├── USAGE.md
│   ├── CONFIGURATION.md
│   └── MODULES.md
├── reports/                    # Generated reports (gitignored)
└── logs/                       # Run logs (gitignored)
```

## How it fits together

1. `lsams.sh` resolves its own install directory, loads `lib/core/*.sh`,
   then `config/lsams.conf`.
2. It opens a findings store (`lib/core/findings.sh`) and, for each
   requested module, sources `lib/modules/NN_*.sh` and calls its entry
   function.
3. Every module reports through `add_finding SEVERITY MODULE TITLE DETAIL
   RECOMMENDATION` - no module talks to the report format directly.
4. `lib/core/report_engine.sh` reads the findings store, computes the
   security score and risk rating, and renders the requested formats.
5. If the score is below `ALERT_MIN_SCORE`, `alerts/*.sh` dispatches the
   enabled notification channels.

This separation - modules produce data, one engine renders it - is what
lets you add a new check (or a new report format) without touching
anything else.

## Documentation

- [docs/INSTALL.md](docs/INSTALL.md) - installation and requirements
- [docs/USAGE.md](docs/USAGE.md) - CLI reference, exit codes, cron setup
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md) - every config variable explained
- [docs/MODULES.md](docs/MODULES.md) - what each module checks, and how to add one

## Running the test suite

```bash
bash tests/run_tests.sh
```

## Security note

LSAMS is read-only by design: every module inspects system state and
reports findings, it never modifies configuration or remediates issues
automatically. Recommendations in the report are meant to be reviewed and
applied by an administrator.
