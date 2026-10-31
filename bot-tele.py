#!/usr/bin/env python3
import urllib.request, urllib.parse, json, subprocess, time, os, uuid
from datetime import datetime, timedelta

CONF_FILE = "/etc/bot/bot.conf"

def load_conf():
    conf = {}
    if os.path.exists(CONF_FILE):
        with open(CONF_FILE, "r") as f:
            for line in f:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    conf[k.strip()] = v.strip().strip('"').strip("'")
    return conf

def api_call(token, method, payload):
    url = f"https://api.telegram.org/bot{token}/{method}"
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=35) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except:
        return {}

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL).decode("utf-8").strip()
    except:
        return ""

def main_keyboard():
    return {
        "inline_keyboard": [
            [{"text": "📊 Status Server", "callback_data": "status"}, {"text": "📋 List Semua Akun", "callback_data": "list_all"}],
            [{"text": "🔄 Restart Services", "callback_data": "restart"}, {"text": "🧹 Bersihkan Expired", "callback_data": "clean"}]
        ]
    }

def main():
    offset = 0
    while True:
        conf = load_conf()
        token = conf.get("TOKEN", "")
        admin = conf.get("ADMIN", "")
        if not token:
            time.sleep(5)
            continue

        res = api_call(token, "getUpdates", {"offset": offset, "timeout": 25})
        for upd in res.get("result", []):
            offset = upd["update_id"] + 1

            if "callback_query" in upd:
                cb = upd["callback_query"]
                cid = str(cb["message"]["chat"]["id"])
                data = cb.get("data", "")
                if admin and cid != admin:
                    continue
                if data == "status":
                    xr = run_cmd("systemctl is-active xray")
                    ng = run_cmd("systemctl is-active nginx")
                    ram = run_cmd("free -m | awk 'NR==2{printf \"%s/%s MB\", $3,$2}'")
                    dom = run_cmd("cat /etc/xray/domain.txt")
                    msg = f"🖥 <b>STATUS SERVER</b>\n━━━━━━━━━━━━━━━\n• Domain: <code>{dom}</code>\n• Xray: <b>{xr}</b>\n• Nginx: <b>{ng}</b>\n• RAM: <code>{ram}</code>"
                    api_call(token, "sendMessage", {"chat_id": cid, "text": msg, "parse_mode": "HTML", "reply_markup": main_keyboard()})
                elif data == "list_all":
                    vl = run_cmd("grep '^###' /etc/xray/vless.db | awk '{print \"- \"$2\" (\"$3\")\"}'") or "Kosong"
                    vm = run_cmd("grep '^###' /etc/xray/vmess.db | awk '{print \"- \"$2\" (\"$3\")\"}'") or "Kosong"
                    tr = run_cmd("grep '^###' /etc/xray/trojan.db | awk '{print \"- \"$2\" (\"$3\")\"}'") or "Kosong"
                    msg = f"📋 <b>DAFTAR AKUN AKTIF</b>\n\n<b>VLESS:</b>\n{vl}\n\n<b>VMESS:</b>\n{vm}\n\n<b>TROJAN:</b>\n{tr}"
                    api_call(token, "sendMessage", {"chat_id": cid, "text": msg, "parse_mode": "HTML", "reply_markup": main_keyboard()})
                elif data == "restart":
                    run_cmd("systemctl restart xray nginx ws-ssh dropbear")
                    api_call(token, "sendMessage", {"chat_id": cid, "text": "✅ Seluruh service berhasil di-restart!", "reply_markup": main_keyboard()})
                elif data == "clean":
                    run_cmd("/usr/bin/auto-exp")
                    api_call(token, "sendMessage", {"chat_id": cid, "text": "✅ Akun expired berhasil dibersihkan!", "reply_markup": main_keyboard()})
                continue

            msg_obj = upd.get("message", {})
            cid = str(msg_obj.get("chat", {}).get("id", ""))
            text = msg_obj.get("text", "").strip()
            if not text or (admin and cid != admin):
                continue

            if text.lower() in ["/start", "/menu"]:
                welcome = "🤖 <b>CASSANOVA TUNNELING BOT PANEL</b>\n━━━━━━━━━━━━━━━━━━━━━━\nGunakan tombol di bawah untuk memanajemen VPS Anda."
                api_call(token, "sendMessage", {"chat_id": cid, "text": welcome, "parse_mode": "HTML", "reply_markup": main_keyboard()})
        time.sleep(1)

if __name__ == "__main__":
    main()
