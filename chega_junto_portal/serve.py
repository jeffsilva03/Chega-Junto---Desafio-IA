"""Servidor local de arquivos + configuração pública, sem dependências externas."""
import argparse
import json
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--api-base", required=True)
    parser.add_argument("--port", type=int, default=5500)
    parser.add_argument("--mode", choices=("operator", "simulator"), default="operator")
    args = parser.parse_args()
    url = urlsplit(args.api_base)
    if url.scheme not in {"http", "https"} or url.hostname not in {"localhost", "127.0.0.1", "::1"} or url.username or url.password or url.path not in {"", "/"} or url.query or url.fragment:
        parser.error("API deve ser uma origem de loopback, sem credenciais ou caminho.")

    class Handler(SimpleHTTPRequestHandler):
        def end_headers(self):
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("Content-Security-Policy", f"default-src 'self'; connect-src 'self' {args.api_base}; script-src 'self'; style-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'")
            super().end_headers()

        def do_GET(self):
            if urlsplit("//" + self.headers.get("Host", "")).hostname not in {"127.0.0.1", "localhost", "::1"}:
                self.send_error(403)
                return
            if urlsplit(self.path).path == "/config.json":
                content = json.dumps({"apiBaseUrl": args.api_base, "mode": args.mode}).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)
            else:
                super().do_GET()

    root = Path(__file__).resolve().parent
    server = ThreadingHTTPServer(("127.0.0.1", args.port), partial(Handler, directory=str(root)))
    print(f"Portal local: http://127.0.0.1:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
