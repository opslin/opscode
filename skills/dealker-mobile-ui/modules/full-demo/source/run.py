#!/usr/bin/env python3
"""Build and serve both Dealker-derived Flutter web apps and the demo dashboard."""

from pathlib import Path
import argparse
import os
import subprocess

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--offline", action="store_true", help="resolve packages from the local Pub cache")
    parser.add_argument("--reuse-build", action="store_true", help="serve the existing Flutter web build outputs")
    args = parser.parse_args()
    port = int((ROOT / "demo-port.txt").read_text())
    base_url = f"http://127.0.0.1:{port}"
    for role in ("customer", "vendor"):
        app = ROOT / role
        if args.reuse_build:
            if not (app / "build/web/main.dart.js").is_file():
                parser.error(f"{role} web build is missing")
            continue
        subprocess.run([args.flutter, "pub", "get", *(["--offline"] if args.offline else [])], cwd=app, check=True)
        subprocess.run([
            args.flutter, "build", "web", "--no-pub", "--no-web-resources-cdn",
            "--base-href", f"/{role}/", "--dart-define=VELO_DEMO=true",
            f"--dart-define=BASE_URL={base_url}/api/v1", f"--dart-define=WEB_BASE_URL={base_url}",
        ], cwd=app, check=True)
    print(f"Dashboard and Flutter demos {base_url}/", flush=True)
    os.execvpe("node", ["node", str(ROOT / "service/server.mjs")], {**os.environ, "VELO_DEMO_PORT": str(port)})


if __name__ == "__main__":
    main()
