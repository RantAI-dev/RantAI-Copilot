#!/usr/bin/env bash
# hypervisor · prove a VM is actually SSH-able — a LAN IP is NOT proof.
# Usage: ssh-check.sh <lan-ip> <user> [password]
#   - with a password: attempts a real login (via sshpass if present, else python
#     pexpect) and runs `whoami; hostname; ip -4 addr show enp2s0`.
#   - without a password: does reachability + auth-method probe only (no login).
# Run from a host on the SAME LAN as <lan-ip>. READ-ONLY on the cluster. Never
# echoes the password. Safe to re-run. Report ONLY what this prints, not a guess.
set -u

IP="${1:-}"; USER_="${2:-}"; PASS="${3:-}"
if [ -z "${IP}" ] || [ -z "${USER_}" ]; then
  echo "usage: ssh-check.sh <lan-ip> <user> [password]" >&2
  exit 2
fi
has() { command -v "$1" >/dev/null 2>&1; }
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=8 -o BatchMode=no"

echo "=== REACHABILITY ${IP} ==="
if ping -c2 -W3 "${IP}" >/dev/null 2>&1; then echo "PING=ok"; else echo "PING=fail"; fi
if timeout 6 bash -c "cat </dev/null >/dev/tcp/${IP}/22" 2>/dev/null; then
  echo "PORT22=open"
else
  echo "PORT22=closed"
  echo "=== STOP: port 22 unreachable — VM not SSH-able yet (still booting? wrong IP? no LAN route?) ==="
  exit 0
fi

echo
echo "=== AUTH METHODS OFFERED (must list 'password' if you set ssh_pwauth) ==="
# PreferredAuthentications=none makes the server reply with what it allows.
timeout 10 ssh ${SSH_OPTS} -o PreferredAuthentications=none "${USER_}@${IP}" true 2>&1 \
  | grep -i 'authentications that can continue' || echo "(no auth line — server may be publickey-only)"

if [ -z "${PASS}" ]; then
  echo
  echo "=== No password supplied — skipping login test. Provide one to fully verify. ==="
  exit 0
fi

echo
echo "=== LOGIN TEST (password auth) ==="
REMOTE_CMD='echo "whoami=$(whoami)"; echo "hostname=$(hostname)"; ip -4 addr show enp2s0 2>/dev/null | awk "/inet /{print \"enp2s0=\"\$2}"; sudo -n true 2>/dev/null && echo "sudo=ok" || echo "sudo=no"'

if has sshpass; then
  OUT="$(sshpass -p "${PASS}" ssh ${SSH_OPTS} -o PreferredAuthentications=password -o PubkeyAuthentication=no "${USER_}@${IP}" "${REMOTE_CMD}" 2>&1)"
  RC=$?
elif has python3; then
  OUT="$(PW="${PASS}" python3 - "${IP}" "${USER_}" "${REMOTE_CMD}" <<'PY' 2>&1
import os, sys
try:
    import pexpect
except Exception:
    print("LOGIN=skipped: no sshpass and no python pexpect available"); sys.exit(0)
ip, user, cmd = sys.argv[1], sys.argv[2], sys.argv[3]
pw = os.environ["PW"]
spawn = ("ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "
         "-o PreferredAuthentications=password -o PubkeyAuthentication=no "
         f"{user}@{ip} '{cmd}'")
c = pexpect.spawn(spawn, timeout=30, encoding="utf-8")
i = c.expect([r"[Pp]assword:", pexpect.EOF, pexpect.TIMEOUT])
if i != 0:
    print("LOGIN=fail: no password prompt"); print(c.before or ""); sys.exit(0)
c.sendline(pw)
c.expect(pexpect.EOF, timeout=30)
print(c.before or "")
PY
)"
  RC=$?
else
  echo "LOGIN=skipped: install sshpass or python3+pexpect to run the login test"
  exit 0
fi

echo "${OUT}"
echo
if printf '%s' "${OUT}" | grep -q "whoami=${USER_}"; then
  echo "=== VERDICT: SSH LOGIN OK (user=${USER_}) ==="
else
  echo "=== VERDICT: SSH LOGIN FAILED — check password / ssh_pwauth / first-boot cloud-init ==="
fi
