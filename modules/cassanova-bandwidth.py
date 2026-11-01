#!/usr/bin/env python3
"""Periodic per-user Xray bandwidth enforcement using Xray StatsService.

Counters are sampled with reset=true and accumulated in a protected state file.
Enforcement is periodic (normally every 60 seconds), so a small overshoot is possible.
This module intentionally does NOT claim per-IP enforcement or support sing-box/SSH.
"""
from __future__ import annotations
import copy
import fcntl
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

XRAY = os.environ.get("CASSANOVA_XRAY_BIN", "/usr/local/bin/xray")
CONFIG = Path("/usr/local/etc/xray/config.json")
DBS = {p: Path(f"/etc/xray/{p}.db") for p in ("vless", "vmess", "trojan")}
LIMIT_DIR = Path("/etc/xray/limit/bw")
STATE = Path("/var/lib/cassanova/bandwidth-xray.json")
LOCK = Path("/run/lock/cassanova-xray-manager.lock")
API = "127.0.0.1:10085"
NOTIFIER = Path("/usr/local/bin/cassanova-notify.py")
GB = 1024 ** 3


def run(args: list[str], *, check: bool = True) -> str:
    p = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)
    if check and p.returncode:
        raise RuntimeError(p.stderr.strip() or f"Command gagal: {args[0]}")
    return p.stdout


def read_state() -> dict:
    try:
        obj = json.loads(STATE.read_text())
        return obj if isinstance(obj, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def write_json_atomic(path: Path, obj: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(obj, f, sort_keys=True)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    finally:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass


def parse_stats(text: str) -> int:
    total = 0
    # Xray CLI emits stat blocks containing name and value fields.
    for block in re.findall(r"stat\s*:\s*\{([^}]*)\}", text, flags=re.S):
        name = re.search(r'name\s*:\s*["\']([^"\']+)', block)
        value = re.search(r"value\s*:\s*(\d+)", block)
        if name and value and name.group(1).endswith((">>>uplink", ">>>downlink")):
            total += int(value.group(1))
    # Some Xray builds format each stat as a single line without braces.
    if total == 0:
        for line in text.splitlines():
            if "user>>>" in line and ("uplink" in line or "downlink" in line):
                m = re.search(r"value\s*:\s*(\d+)", line)
                if m:
                    total += int(m.group(1))
    return total


def query_delta(username: str) -> int:
    pattern = f"user>>>{username}>>>traffic>>>"
    output = run([XRAY, "api", "statsquery", f"--server={API}", f"-pattern={pattern}", "-reset=true"])
    return parse_stats(output)


def update_db_status(db: Path, username: str, status: str) -> None:
    rows = db.read_text().splitlines()
    found = False
    updated = []
    for row in rows:
        parts = row.split()
        if len(parts) >= 5 and parts[0] == "###" and parts[1] == username:
            parts[4] = status
            row = " ".join(parts)
            found = True
        updated.append(row)
    if not found:
        raise RuntimeError(f"Akun {username} tidak ditemukan saat update status")
    fd, tmp = tempfile.mkstemp(prefix=db.name + ".", dir=db.parent)
    try:
        with os.fdopen(fd, "w") as f:
            f.write("\n".join(updated) + "\n")
            f.flush()
            os.fsync(f.fileno())
        os.chmod(tmp, 0o600)
        os.replace(tmp, db)
    finally:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass


def remove_runtime(proto: str, username: str, credential: str) -> None:
    config = json.loads(CONFIG.read_text())
    candidate = copy.deepcopy(config)
    tags = []
    for inbound in candidate.get("inbounds", []):
        if inbound.get("protocol") == proto and inbound.get("tag"):
            tags.append(inbound["tag"])
            settings = inbound.setdefault("settings", {})
            clients = settings.get("clients") or []
            settings["clients"] = [c for c in clients if c.get("email") != username]
    if not tags:
        raise RuntimeError(f"Inbound {proto} tidak ditemukan")

    fd, staged = tempfile.mkstemp(prefix="config.bandwidth.", dir=CONFIG.parent)
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(candidate, f, indent=2)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())
        os.chmod(staged, 0o600)
        run([XRAY, "run", "-test", "-config", staged])

        backup_dir = Path("/var/backups/cassanova/xray")
        backup_dir.mkdir(parents=True, exist_ok=True)
        backup = backup_dir / f"config-bandwidth-{__import__('time').strftime('%Y%m%dT%H%M%SZ')}.json"
        backup.write_bytes(CONFIG.read_bytes())
        os.chmod(backup, 0o600)

        removed: list[str] = []
        user = {"email": username, "password": credential} if proto == "trojan" else {"email": username, "id": credential}
        for tag in tags:
            try:
                run([XRAY, "api", "rmu", f"--server={API}", f"-inbound={tag}", f"-users={json.dumps([username], separators=(',', ':'))}"])
                removed.append(tag)
            except Exception:
                for done in removed:
                    subprocess.run([XRAY, "api", "adu", f"--server={API}", f"-inbound={done}", f"-users={json.dumps([user], separators=(',', ':'))}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                raise
        db = DBS[proto]
        try:
            update_db_status(db, username, "locked")
        except Exception:
            for tag in removed:
                subprocess.run([XRAY, "api", "adu", f"--server={API}", f"-inbound={tag}", f"-users={json.dumps([user], separators=(',', ':'))}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            raise
        try:
            os.replace(staged, CONFIG)
            os.chmod(CONFIG, 0o600)
        except Exception:
            # The old on-disk config is still authoritative; restore DB and runtime.
            update_db_status(db, username, "unlocked")
            for tag in removed:
                subprocess.run([XRAY, "api", "adu", f"--server={API}", f"-inbound={tag}", f"-users={json.dumps([user], separators=(',', ':'))}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            raise
    finally:
        try:
            os.unlink(staged)
        except FileNotFoundError:
            pass


def notify(proto: str, username: str, used: int, limit: int) -> None:
    if not NOTIFIER.exists():
        return
    payload = {"event": "bandwidth_limit", "protocol": proto.upper(), "username": username,
               "context": f"Penggunaan: {used / GB:.3f} GB | Batas: {limit} GB | Akun dikunci otomatis."}
    subprocess.run([sys.executable, str(NOTIFIER)], input=json.dumps(payload), text=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)


def main() -> int:
    if os.geteuid() != 0:
        print("Harus dijalankan sebagai root", file=sys.stderr)
        return 2
    if not CONFIG.is_file():
        print("Konfigurasi Xray tidak ditemukan", file=sys.stderr)
        return 1
    try:
        config = json.loads(CONFIG.read_text())
    except (OSError, json.JSONDecodeError):
        print("Konfigurasi Xray tidak dapat dibaca", file=sys.stderr)
        return 1
    services = (config.get("api") or {}).get("services") or []
    level0 = ((config.get("policy") or {}).get("levels") or {}).get("0") or {}
    api_inbound = any(i.get("tag") == "api-in" and i.get("protocol") == "dokodemo-door" and i.get("listen") == "127.0.0.1" and i.get("port") == 10085 for i in config.get("inbounds", []))
    api_route = any("api-in" in (r.get("inboundTag") or []) and r.get("outboundTag") == "api" for r in (config.get("routing") or {}).get("rules", []))
    if "StatsService" not in services or not level0.get("statsUserUplink") or not level0.get("statsUserDownlink") or not api_inbound or not api_route:
        print("Bandwidth enforcement belum aktif: Xray StatsService/API inbound belum dikonfigurasi. Jalankan xray-manager vless api-enable.")
        return 0
    LIMIT_DIR.mkdir(parents=True, exist_ok=True)
    LOCK.parent.mkdir(parents=True, exist_ok=True)
    with LOCK.open("a") as lockf:
        try:
            fcntl.flock(lockf, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print("Proses bandwidth enforcement lain masih berjalan; pemeriksaan ini dilewati.")
            return 0
        state = read_state()
        if len(sys.argv) == 4 and sys.argv[1] == "--reset":
            proto, username = sys.argv[2], sys.argv[3]
            if proto not in DBS or not re.fullmatch(r"[A-Za-z0-9_.@-]{1,32}", username):
                print("Parameter reset tidak valid", file=sys.stderr)
                return 2
            query_delta(username)  # discard any pending Xray counter before starting a fresh quota period
            state.pop(f"{proto}:{username}", None)
            write_json_atomic(STATE, state)
            print(f"Penggunaan bandwidth {proto}/{username} direset ke 0 GB.")
            return 0
        changed = False
        failures = 0
        for proto, db in DBS.items():
            if not db.is_file():
                continue
            for row in db.read_text().splitlines():
                parts = row.split()
                if len(parts) < 5 or parts[0] != "###":
                    continue
                _, username, expiry, credential, status = parts[:5]
                limit_file = LIMIT_DIR / f"{proto}_{username}"
                try:
                    limit_gb = int(limit_file.read_text().strip()) if limit_file.exists() else 0
                except (ValueError, OSError):
                    print(f"Limit tidak valid: {proto}/{username}", file=sys.stderr)
                    failures += 1
                    continue
                if limit_gb <= 0 or status != "unlocked":
                    continue
                # Xray StatsService identifies users by email globally, not by inbound protocol.
                # Refuse ambiguous legacy duplicate usernames across VLESS/VMess/Trojan.
                duplicate_count = 0
                for other_db in DBS.values():
                    if other_db.is_file():
                        duplicate_count += sum(1 for line in other_db.read_text().splitlines()
                                               if len(line.split()) >= 2 and line.split()[0] == "###" and line.split()[1] == username)
                if duplicate_count > 1:
                    print(f"SKIP: username {username} muncul di beberapa database Xray; statistik email Xray akan tercampur.", file=sys.stderr)
                    failures += 1
                    continue
                key = f"{proto}:{username}"
                try:
                    delta = query_delta(username)
                    total = int(state.get(key, 0)) + delta
                    state[key] = total
                    changed = True
                    if total >= limit_gb * GB:
                        remove_runtime(proto, username, credential)
                        notify(proto, username, total, limit_gb)
                        print(f"LIMIT: {proto}/{username} dikunci pada {total} bytes")
                    else:
                        print(f"OK: {proto}/{username} {total}/{limit_gb * GB} bytes")
                except Exception as exc:
                    print(f"GAGAL: {proto}/{username}: {exc}", file=sys.stderr)
                    failures += 1
        if changed:
            write_json_atomic(STATE, state)
        return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
