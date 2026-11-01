#!/usr/bin/env python3
"""Cassanova Tunneling Telegram control bot (stdlib only)."""
from __future__ import annotations
import fcntl
import html
import json
import logging
import os
import re
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CONF_FILE = Path('/etc/bot/bot.conf')
STATE_DIR = Path('/var/lib/cassanova')
OFFSET_FILE = STATE_DIR / 'bot-offset'
LOCK_FILE = Path('/run/lock/cassanova-bot.lock')
LOG_LEVEL = os.environ.get('BOT_LOG_LEVEL', 'INFO').upper()
logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO),
                    format='%(asctime)s %(levelname)s %(message)s')
LOG = logging.getLogger('cassanova-bot')
STATUS_SERVICES = ('xray', 'sing-box', 'nginx', 'cassanova-dropbear', 'ssh', 'bot-tele')
RESTART_SERVICES = ('xray', 'sing-box', 'nginx', 'cassanova-dropbear')
DB_FILES = {
    'VLESS': Path('/etc/xray/vless.db'),
    'VMESS': Path('/etc/xray/vmess.db'),
    'TROJAN': Path('/etc/xray/trojan.db'),
    'SSH': Path('/etc/ssh/.ssh.db'),
    'HYSTERIA2': Path('/var/lib/cassanova/hysteria2/users.json'),
}


def load_conf() -> dict[str, str]:
    conf: dict[str, str] = {}
    try:
        for line in CONF_FILE.read_text(encoding='utf-8').splitlines():
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, value = line.split('=', 1)
            conf[key.strip()] = value.strip().strip('"').strip("'")
    except OSError:
        return {}
    return conf


def allowed_ids(conf: dict[str, str]) -> set[str]:
    raw = conf.get('ADMIN', '')
    return {item.strip() for item in raw.split(',') if re.fullmatch(r'[1-9][0-9]{4,19}', item.strip())}


def api_call(token: str, method: str, payload: dict | None = None) -> dict:
    url = f'https://api.telegram.org/bot{token}/{method}'
    data = urllib.parse.urlencode(payload or {}).encode() if method == 'getUpdates' else json.dumps(payload or {}).encode()
    headers = {'Content-Type': 'application/x-www-form-urlencoded' if method == 'getUpdates' else 'application/json'}
    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=35) as response:
            result = json.loads(response.read().decode('utf-8'))
            if not result.get('ok'):
                LOG.warning('Telegram API returned an unsuccessful response for %s', method)
            return result
    except (urllib.error.URLError, TimeoutError, ValueError, OSError) as exc:
        LOG.warning('Telegram API request failed (%s): %s', method, type(exc).__name__)
        return {}


def run_command(args: list[str], timeout: int = 8) -> str:
    """Run a fixed executable/argument list; never invoke a shell."""
    try:
        result = subprocess.run(args, check=False, capture_output=True, text=True, timeout=timeout)
        return (result.stdout or result.stderr).strip()
    except (OSError, subprocess.TimeoutExpired):
        return ''


def keyboard() -> str:
    return json.dumps({'inline_keyboard': [
        [{'text': '📊 Status Server', 'callback_data': 'status'}, {'text': '📋 List Akun', 'callback_data': 'list'}],
        [{'text': '🔄 Restart Services', 'callback_data': 'restart'}, {'text': '🧹 Bersihkan Expired', 'callback_data': 'clean'}],
    ]})


def send(token: str, chat_id: str, text: str, markup: bool = True) -> None:
    # Split on line boundaries to avoid truncating HTML tags/entities mid-message.
    chunks: list[str] = []
    current = ''
    for line in text.splitlines() or ['']:
        candidate = line if not current else current + '\n' + line
        if len(candidate) > 3800 and current:
            chunks.append(current)
            current = line
        else:
            current = candidate
    if current:
        chunks.append(current)
    for index, chunk in enumerate(chunks):
        payload = {'chat_id': chat_id, 'text': chunk, 'parse_mode': 'HTML', 'disable_web_page_preview': True}
        if markup and index == 0:
            payload['reply_markup'] = keyboard()
        api_call(token, 'sendMessage', payload)


def account_lines(path: Path, label: str) -> list[str]:
    rows: list[str] = []
    try:
        content = path.read_text(encoding='utf-8', errors='replace')
        if label == 'HYSTERIA2':
            records = json.loads(content or '[]')
            if isinstance(records, list):
                for record in records:
                    if not isinstance(record, dict):
                        continue
                    username = html.escape(str(record.get('username', '')))
                    expiry = html.escape(str(record.get('expiry', '')))
                    state = html.escape(str(record.get('status', 'unknown')))
                    rows.append(f'• <code>{username}</code> — {expiry} ({state})')
        else:
            for line in content.splitlines():
                if not line.startswith('### '):
                    continue
                fields = line.split()
                if len(fields) >= 3:
                    username = html.escape(fields[1])
                    expiry = html.escape(fields[2])
                    rows.append(f'• <code>{username}</code> — {expiry}')
    except (OSError, ValueError, TypeError):
        pass
    return rows or ['• (kosong / database belum tersedia)']


def status_text() -> str:
    states = []
    for service in STATUS_SERVICES:
        state = run_command(['/usr/bin/systemctl', 'is-active', service]) or 'unknown'
        states.append(f'• {html.escape(service)}: <b>{html.escape(state)}</b>')
    ram = run_command(['/usr/bin/free', '-h'])
    ram_line = next((line for line in ram.splitlines() if line.startswith('Mem:')), 'Tidak tersedia')
    domain = 'Belum diatur'
    try:
        domain = Path('/etc/xray/domain.txt').read_text().strip() or domain
    except OSError:
        pass
    return ('🖥 <b>STATUS SERVER</b>\n' + '\n'.join(states) +
            f'\n• Domain: <code>{html.escape(domain)}</code>' +
            f'\n• RAM: <code>{html.escape(ram_line)}</code>')


def handle_action(token: str, chat_id: str, action: str) -> None:
    if action == 'status':
        send(token, chat_id, status_text())
    elif action == 'list':
        sections = []
        for label, path in DB_FILES.items():
            sections.append(f'<b>{label}</b>\n' + '\n'.join(account_lines(path, label)))
        send(token, chat_id, '📋 <b>DAFTAR AKUN</b>\n\n' + '\n\n'.join(sections))
    elif action == 'restart':
        results = []
        for service in RESTART_SERVICES:
            output = run_command(['/usr/bin/cassanova-service', 'restart', service], timeout=30)
            state = run_command(['/usr/bin/systemctl', 'is-active', service]) or 'unknown'
            detail = f' — {html.escape(output[:250])}' if state != 'active' and output else ''
            results.append(f'• {html.escape(service)}: <b>{html.escape(state)}</b>{detail}')
        send(token, chat_id, '🔄 <b>Hasil restart</b>\n' + '\n'.join(results))
    elif action == 'clean':
        cleaner = Path('/usr/bin/cassanova-expire')
        if not cleaner.is_file() or not os.access(cleaner, os.X_OK):
            send(token, chat_id, '⚠️ Program cassanova-expire tidak ditemukan atau tidak executable.')
            return
        output = run_command([str(cleaner)], timeout=120)
        send(token, chat_id, '🧹 <b>Rekonsiliasi expiry selesai.</b>' +
             (f'\n<code>{html.escape(output[:2500])}</code>' if output else '\nTidak ada output. Periksa journal service untuk detail.'))


def read_offset() -> int:
    try:
        return max(0, int(OFFSET_FILE.read_text().strip()))
    except (OSError, ValueError):
        return 0


def save_offset(offset: int) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(STATE_DIR, 0o700)
    tmp = OFFSET_FILE.with_suffix('.tmp')
    tmp.write_text(f'{offset}\n', encoding='ascii')
    os.chmod(tmp, 0o600)
    os.replace(tmp, OFFSET_FILE)


def authorised_private_user(container: dict, actor: dict, admins: set[str]) -> bool:
    chat = container.get('chat') or {}
    user_id = str(actor.get('id', ''))
    return chat.get('type') == 'private' and user_id in admins and str(chat.get('id', '')) == user_id


def main() -> None:
    LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    with LOCK_FILE.open('w') as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            LOG.error('Instance bot lain sudah berjalan; proses kedua dihentikan.')
            return
        offset = read_offset()
        while True:
            conf = load_conf()
            token = conf.get('TOKEN', '').strip()
            admins = allowed_ids(conf)
            if not token or not admins:
                time.sleep(5)
                continue
            updates = api_call(token, 'getUpdates', {'offset': offset, 'timeout': 25,
                                 'allowed_updates': json.dumps(['message', 'callback_query'])})
            if not updates.get('ok'):
                time.sleep(3)
                continue
            for update in updates.get('result', []):
                update_id = int(update.get('update_id', 0))
                callback = update.get('callback_query')
                if callback:
                    message = callback.get('message') or {}
                    actor = callback.get('from') or {}
                    api_call(token, 'answerCallbackQuery', {'callback_query_id': callback.get('id', '')})
                    if authorised_private_user(message, actor, admins):
                        handle_action(token, str((message.get('chat') or {}).get('id', '')), str(callback.get('data', '')))
                else:
                    message = update.get('message') or {}
                    actor = message.get('from') or {}
                    if authorised_private_user(message, actor, admins):
                        chat_id = str((message.get('chat') or {}).get('id', ''))
                        if str(message.get('text', '')).strip().lower() in ('/start', '/menu'):
                            send(token, chat_id, '🤖 <b>CASSANOVA TUNNELING BOT PANEL</b>\nAkses administrator terverifikasi.')
                offset = max(offset, update_id + 1)
                # Commit only after a given update has been handled, so restarts do not replay old callbacks.
                save_offset(offset)
            time.sleep(0.5)


if __name__ == '__main__':
    main()
