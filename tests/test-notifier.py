#!/usr/bin/env python3
"""Offline unit test for Telegram notifier formatting/routing."""
import importlib.util
import io
import json
import tempfile
from pathlib import Path
from unittest.mock import patch
from urllib.parse import parse_qs

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('cassanova_notify', ROOT / 'modules/cassanova-notify.py')
assert SPEC and SPEC.loader
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


class FakeResponse:
    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self):
        return b'{"ok":true,"result":{}}'


def main():
    with tempfile.TemporaryDirectory() as tmp:
        conf = Path(tmp) / 'bot.conf'
        conf.write_text('TOKEN=12345:abcdefghijklmnopqrstuvwxyz\nADMIN=111,222\n', encoding='utf-8')
        MOD.CONF = conf
        payloads = []

        def fake_urlopen(request, timeout=0):
            payloads.append(parse_qs(request.data.decode()))
            return FakeResponse()

        events = [
            {
                'event': 'create', 'protocol': 'vless', 'username': '<alice>',
                'expiry': '2027-01-01', 'credential': 'uuid-secret',
                'links': 'vless://uuid-secret@example.test:443#alice', 'details': [],
            },
            {
                'event': 'recovery', 'protocol': 'SSH', 'context': 'OpenSSH port 22',
                'details': [{'username': 'ssh-user', 'expiry': '2027-02-01', 'status': 'unlocked'}],
            },
            {
                'event': 'create', 'protocol': 'HYSTERIA2', 'username': 'hy2-user',
                'expiry': '2027-03-01', 'credential': 'hy2-secret',
                'links': 'hysteria2://hy2-secret@example.test:443',
                'context': 'sing-box UDP/443', 'details': [],
            },
        ]
        with patch.object(MOD.urllib.request, 'urlopen', fake_urlopen):
            for event in events:
                with patch('sys.stdin', io.StringIO(json.dumps(event))):
                    assert MOD.main() == 0
        # Each event is delivered to both configured admin chat IDs.
        assert len(payloads) == 6, payloads
        messages = [p['text'][0] for p in payloads]
        assert all(p['parse_mode'] == ['HTML'] for p in payloads)
        assert all('&lt;alice&gt;' in m for m in messages[:2])
        assert all('uuid-secret' in m for m in messages[:2])
        assert all('ssh-user' in m and 'OpenSSH port 22' in m for m in messages[2:4])
        assert all('hy2-secret' in m and 'sing-box UDP/443' in m for m in messages[4:])
    print('Notifier offline unit test passed for Xray, SSH recovery and Hysteria2.')


if __name__ == '__main__':
    main()
