# Module Reference

Every module lives in `lib/modules/`, is sourced by [`lsams.sh`](../lsams.sh)
on demand, and reports findings through `add_finding` (see
[`lib/core/findings.sh`](../lib/core/findings.sh)). Run
`lsams --list-modules` to see the exact keys accepted by `--modules=`.

## 01: users

**File:** `01_user_audit.sh` · **Function:** `run_user_audit`

Audits local accounts: extra UID-0 accounts, empty passwords, sudo/admin
group membership, password aging (`chage`), long-term inactive accounts,
and duplicate UIDs.

## 02: ssh

**File:** `02_ssh_audit.sh` · **Function:** `run_ssh_audit`

Reads the effective `sshd` configuration (via `sshd -T`, falling back to
`/etc/ssh/sshd_config`) and flags insecure settings: root login,
password authentication, empty passwords, X11 forwarding, user
environment injection, `MaxAuthTries`, and the SSH protocol version. Also
checks permissions on host private keys and `sshd_config`.

## 03: permissions

**File:** `03_file_permissions.sh` · **Function:** `run_file_permissions_audit`

Scans the filesystem for SUID/SGID binaries outside a known-good
allowlist, world-writable files, files with no valid owner/group, and
loose permissions on security-critical files (`/etc/passwd`,
`/etc/shadow`, `/etc/sudoers`, etc).

## 04: health

**File:** `04_system_health.sh` · **Function:** `run_system_health_audit`

Monitors CPU load average, memory usage, per-filesystem disk usage, the
top CPU/memory-consuming processes, and any systemd units in a failed
state.

## 05: network

**File:** `05_network_audit.sh` · **Function:** `run_network_audit`

Lists listening sockets, flags legacy/insecure services (Telnet, FTP,
rsh/rlogin, NFS, X11), checks firewall status (`ufw` / `firewalld` /
`iptables`), and counts active established TCP connections.

## 06: authlog

**File:** `06_auth_log_analysis.sh` · **Function:** `run_auth_log_analysis`

Parses `journalctl -u ssh` or `/var/log/auth.log` for failed logins,
brute-force patterns (many failures from one source IP within the
configured threshold), sudo usage/failures, and login attempts for
non-existent usernames.

## 07: packages

**File:** `07_package_kernel_audit.sh` · **Function:** `run_package_kernel_audit`

Checks for pending package/security updates via `apt`, whether
`unattended-upgrades` is installed and configured, whether the running
kernel matches the latest installed kernel package, and whether a reboot
is pending.

## 08: compliance

**File:** `08_compliance_check.sh` · **Function:** `run_compliance_check`

Runs a CIS-benchmark-style checklist, entirely driven by
[`config/compliance_rules.conf`](../config/compliance_rules.conf). Each
rule below can be toggled independently:

| Rule ID                          | Verifies |
|-----------------------------------|----------|
| `CHECK_PASSWORD_MAX_DAYS`        | `PASS_MAX_DAYS` in `/etc/login.defs` is <= 90 |
| `CHECK_PASSWORD_MIN_LENGTH`      | `minlen` in `/etc/security/pwquality.conf` is >= 8 |
| `CHECK_PASSWORD_COMPLEXITY`      | `pam_pwquality.so` is enabled in `common-password` |
| `CHECK_EMPTY_PASSWORDS`          | No account has an empty password field |
| `CHECK_ROOT_LOGIN_RESTRICTED`    | `PermitRootLogin` is `no`/`prohibit-password` |
| `CHECK_WORLD_WRITABLE_FILES`     | No world-writable files under `/etc` |
| `CHECK_SUID_SGID_FILES`          | SUID binary count is within baseline (<= 40) |
| `CHECK_CRITICAL_FILE_PERMISSIONS`| `/etc/shadow` mode is 640 or stricter |
| `CHECK_UNOWNED_FILES`            | No unowned files under `/etc` |
| `CHECK_FIREWALL_ENABLED`         | `ufw` or `firewalld` is active |
| `CHECK_UNNECESSARY_SERVICES`     | telnet/rsh/nis/tftp/xinetd are not active |
| `CHECK_SSH_HARDENING`            | `PasswordAuthentication` is `no` |
| `CHECK_AUDITD_RUNNING`           | `auditd` is active |
| `CHECK_LOG_PERMISSIONS`          | `/var/log/auth.log` mode is 640 or stricter |
| `CHECK_AUTOMATIC_UPDATES`        | Unattended upgrades are configured |
| `CHECK_UNUSED_ACCOUNTS`          | System accounts (UID < 1000) use a locked shell |

## 09: services

**File:** `09_service_audit.sh` · **Function:** `run_service_audit`

Reports the count of active services and flags commonly-unnecessary
daemons if running (`avahi-daemon`, `cups`, `isc-dhcp-server`,
`nfs-server`, `rpcbind`, `snapd`, `bluetooth`).

## Adding a new module

1. Create `lib/modules/NN_your_module.sh` following the pattern of an
   existing module: one `run_*` entry point calling private `_check_*`
   helpers, each ending in one or more `add_finding` calls.
2. Register it in the `MODULE_REGISTRY` array near the top of
   [`lsams.sh`](../lsams.sh): `"key:run_function:NN_your_module.sh"`.
3. Add a unit test if the module contains non-trivial parsing logic.
4. Document it here.
