#!/usr/bin/env python3
"""Send structured Cassanova account lifecycle notifications to configured admins.
Input is JSON on stdin; credentials are intentionally sent only to ADMIN IDs.
"""
from __future__ import annotations
import datetime as dt
import html
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CONF = Path('/etc/bot/bot.conf')
API = 'https://api.telegram.org/bot{token}/sendMessage'


def read_config() -> dict[str, str]:
    result: dict[str, str] = {}
    try:
        for raw in CONF.read_text(encoding='utf-8').splitlines():
            line = raw.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, value = line.split('=', 1)
            result[key.strip()] = value.strip().strip('"').strip("'")
    except OSError:
        return {}
    return result


def send(token: str, chat_id: str, message: str) -> bool:
    payload = urllib.parse.urlencode({
        'chat_id': chat_id,
        'text': message,
        'parse_mode': 'HTML',
        'disable_web_page_preview': 'true',
    }).encode()
    request = urllib.request.Request(API.format(token=token), data=payload)
    try:
        with urllib.request.urlopen(request, timeout=12) as response:
            body = json.loads(response.read().decode('utf-8'))
            return bool(body.get('ok'))
    except (OSError, urllib.error.URLError, ValueError, TimeoutError):
        return False


def esc(value: object) -> str:
    return html.escape(str(value or ''), quote=True)


def chunks(text: str, max_chars: int = 3700) -> list[str]:
    lines = text.splitlines() or ['']
    result: list[str] = []
    current = ''
    for line in lines:
        candidate = f'{current}\n{line}' if current else line
        if len(candidate) > max_chars and current:
            result.append(current)
            current = line
        else:
            current = candidate
    if current:
        result.append(current)
    return result


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        print('Input notifikasi bukan JSON valid.', file=sys.stderr)
        return 2
    conf = read_config()
    token = conf.get('TOKEN', '').strip()
    admins = [x.strip() for x in conf.get('ADMIN', '').split(',') if re.fullmatch(r'[1-9][0-9]{4,19}', x.strip())]
    if not token or not admins:
        print('Telegram token/admin belum dikonfigurasi; notifikasi tidak dikirim.', file=sys.stderr)
        return 1

    event = str(data.get('event', 'update')).lower()
    protocol = str(data.get('protocol', '')).upper()
    labels = {
        'create': 'AKUN BARU DIBUAT', 'renew': 'MASA AKTIF DIPERPANJANG',
        'delete': 'AKUN DIHAPUS',
        'modify': 'CREDENTIAL DIUBAH', 'lock': 'AKUN DIKUNCI',
        'unlock': 'AKUN DIBUKA', 'expired': 'AKUN KEDALUWARSA DINONAKTIFKAN',
        'recovery': 'RECOVERY / SINKRONISASI AKUN SELESAI',
        'bandwidth_limit': 'AKUN DIKUNCI KARENA BATAS BANDWIDTH',
    }
    now = dt.datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %Z')
    lines = [f'🔔 <b>CASSANOVA — {esc(labels.get(event, event.upper()))}</b>',
             f'Protokol: <b>{esc(protocol)}</b>', f'Waktu: <code>{esc(now)}</code>']
    username = str(data.get('username', '')).strip()
    if username:
        lines.append(f'Username: <code>{esc(username)}</code>')
    expiry = str(data.get('expiry', '')).strip()
    if expiry:
        lines.append(f'Expired: <code>{esc(expiry)}</code>')
    credential = str(data.get('credential', '')).strip()
    if credential:
        lines.append(f'Credential: <code>{esc(credential)}</code>')
    details = data.get('details')
    if isinstance(details, list) and details:
        summary = 'Jumlah akun kedaluwarsa' if event == 'expired' else 'Jumlah akun dipulihkan' if event == 'recovery' else 'Jumlah akun terkait'
        lines.append(f'{summary}: <b>{len(details)}</b>')
        for item in details:
            if not isinstance(item, dict):
                continue
            lines.append('')
            lines.append(f"• <code>{esc(item.get('username'))}</code> | Exp: <code>{esc(item.get('expiry'))}</code>")
            if item.get('credential'):
                lines.append(f"  Credential: <code>{esc(item.get('credential'))}</code>")
            if item.get('status'):
                lines.append(f"  Status: <code>{esc(item.get('status'))}</code>")
    context = str(data.get('context', '')).strip()
    if context:
        lines.extend(['', '<b>Detail koneksi</b>', '<pre>' + esc(context[:1800]) + '</pre>'])
    links = str(data.get('links', '')).strip()
    if links:
        lines.extend(['', '<b>LINK / KONFIGURASI AKUN</b>'])
        # Put links in code blocks to prevent Telegram HTML parsing of query chars.
        lines.append('<pre>' + esc(links[:2400]) + '</pre>')
    lines.extend(['', '🔐 <i>Notifikasi ini hanya dikirim ke Admin ID yang terdaftar.</i>'])
    messages = chunks('\n'.join(lines))
    failed = 0
    for admin in admins:
        for message in messages:
            if not send(token, admin, message):
                failed += 1
    if failed:
        print(f'{failed} pesan Telegram gagal dikirim.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
