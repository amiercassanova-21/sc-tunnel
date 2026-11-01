#!/usr/bin/env python3
"""Cassanova Tunneling Telegram control bot (stdlib only)."""
from __future__ import annotations
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
LOG_LEVEL = os.environ.get('BOT_LOG_LEVEL', 'INFO').upper()
logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO),
                    format='%(asctime)s %(levelname)s %(message)s')
LOG = logging.getLogger('cassanova-bot')
ALLOWED_SERVICES = ('xray', 'sing-box', 'nginx', 'ws-ssh', 'dropbear')
DB_FILES = {
    'VLESS': Path('/etc/xray/vless.db'),
    'VMESS': Path('/etc/xray/vmess.db'),
    'TROJAN': Path('/etc/xray/trojan.db'),
    'SSH': Path('/etc/ssh/.ssh.db'),
    'HYSTERIA2': Path('/etc/sing-box/users.json'),
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
    return {item.strip() for item in raw.split(',') if re.fullmatch(r'-?\d+', item.strip())}


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
    payload = {'chat_id': chat_id, 'text': text, 'parse_mode': 'HTML', 'disable_web_page_preview': True}
    if markup:
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
    for service in ALLOWED_SERVICES:
        state = run_command(['/usr/bin/systemctl', 'is-active', service]) or 'unknown'
        states.append(f'• {service}: <b>{html.escape(state)}</b>')
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
        text = '📋 <b>DAFTAR AKUN</b>\n\n' + '\n\n'.join(sections)
        # Telegram message limit is 4096 chars.
        send(token, chat_id, text[:3900])
    elif action == 'restart':
        results = []
        for service in ALLOWED_SERVICES:
            out = run_command(['/usr/bin/systemctl', 'restart', service], timeout=20)
            state = run_command(['/usr/bin/systemctl', 'is-active', service]) or 'unknown'
            results.append(f'• {service}: <b>{html.escape(state)}</b>')
        send(token, chat_id, '🔄 <b>Hasil restart</b>\n' + '\n'.join(results))
    elif action == 'clean':
        cleaner = Path('/usr/bin/auto-exp')
        if not cleaner.is_file() or not os.access(cleaner, os.X_OK):
            send(token, chat_id, '⚠️ Program auto-exp tidak ditemukan atau tidak executable.')
            return
        output = run_command([str(cleaner)], timeout=60)
        hy2_output = run_command(['/usr/bin/hy2-manager', 'expire'], timeout=60)
        combined = '\n'.join(part for part in (output, hy2_output) if part)
        send(token, chat_id, '🧹 Proses pembersihan selesai.' + (f'\n<code>{html.escape(combined[:1000])}</code>' if combined else ''))


def main() -> None:
    offset = 0
    while True:
        conf = load_conf()
        token = conf.get('TOKEN', '').strip()
        admins = allowed_ids(conf)
        if not token or not admins:
            time.sleep(5)
            continue
        updates = api_call(token, 'getUpdates', {'offset': offset, 'timeout': 25, 'allowed_updates': json.dumps(['message', 'callback_query'])})
        if not updates.get('ok'):
            time.sleep(3)
            continue
        for update in updates.get('result', []):
            offset = max(offset, int(update.get('update_id', 0)) + 1)
            callback = update.get('callback_query')
            if callback:
                message = callback.get('message') or {}
                chat_id = str((message.get('chat') or {}).get('id', ''))
                api_call(token, 'answerCallbackQuery', {'callback_query_id': callback.get('id', '')})
                if chat_id not in admins:
                    continue
                handle_action(token, chat_id, str(callback.get('data', '')))
                continue
            message = update.get('message') or {}
            chat_id = str((message.get('chat') or {}).get('id', ''))
            if chat_id not in admins:
                continue
            text = str(message.get('text', '')).strip()
            if text.lower() in ('/start', '/menu'):
                send(token, chat_id, '🤖 <b>CASSANOVA TUNNELING BOT PANEL</b>\nAkses administrator terverifikasi.')
        time.sleep(0.5)


if __name__ == '__main__':
    main()
