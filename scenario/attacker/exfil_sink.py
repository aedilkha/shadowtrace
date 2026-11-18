#!/usr/bin/env python3
"""
ShadowTrace - Serveur « attaquant » du lab : reçoit l'exfiltration et la garde comme preuve.
A lancer sur la VM Ubuntu (10.10.10.10) :
    python3 scenario/attacker/exfil_sink.py --port 8080 --out ./evidence/exfil
Chaque réception est enregistrée (fichier + ligne JSON avec IP source, taille, SHA-256).
"""
import argparse
import datetime as dt
import hashlib
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def make_handler(out: Path):
    class Sink(BaseHTTPRequestHandler):
        def do_POST(self):  # noqa: N802
            n = int(self.headers.get("Content-Length", 0))
            data = self.rfile.read(n)
            ts = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            name = self.headers.get("X-Filename", "payload.bin").replace("/", "_").replace("\\", "_")
            path = out / f"{ts}_{self.client_address[0]}_{name}"
            path.write_bytes(data)
            rec = {"ts": ts, "src_ip": self.client_address[0], "path": self.path, "bytes": len(data),
                   "sha256": hashlib.sha256(data).hexdigest(), "user_agent": self.headers.get("User-Agent"),
                   "saved_as": str(path)}
            with (out / "receptions.jsonl").open("a") as f:
                f.write(json.dumps(rec) + "\n")
            print("[EXFIL REÇUE]", json.dumps(rec))
            self.send_response(200); self.end_headers(); self.wfile.write(b"ok")

        def do_GET(self):  # noqa: N802
            self.send_response(200); self.end_headers(); self.wfile.write(b"exfil-relay.lab (ShadowTrace lab)")

    return Sink


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument("--out", type=Path, default=Path("evidence/exfil"))
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    print(f"Écoute sur 0.0.0.0:{a.port}, preuves dans {a.out}")
    ThreadingHTTPServer(("0.0.0.0", a.port), make_handler(a.out)).serve_forever()
