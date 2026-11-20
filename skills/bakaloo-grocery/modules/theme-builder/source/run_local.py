#!/usr/bin/env python3
"""Run the local Bakaloo dashboard, API, and Flutter storefront."""
import argparse
from contextlib import ExitStack
from pathlib import Path
import os
import secrets
import shlex
import signal
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlencode
from urllib.request import urlopen


ROOT = Path(__file__).resolve().parent


def run(command, *, cwd=ROOT, env=None):
    subprocess.run(command, cwd=cwd, env=env, check=True)


def start(stack, command, *, cwd, env, log):
    stream = stack.enter_context(log.open("w", encoding="utf-8"))
    child = subprocess.Popen(
        command, cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT,
        start_new_session=True,
    )

    def stop():
        if child.poll() is not None:
            return
        os.killpg(child.pid, signal.SIGTERM)
        try:
            child.wait(timeout=8)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()

    stack.callback(stop)
    return child


def ready(child, url, log, timeout=75):
    end = time.monotonic() + timeout
    while time.monotonic() < end and child.poll() is None:
        try:
            with urlopen(url, timeout=2) as response:
                if response.status == 200:
                    return
        except OSError:
            pass
        time.sleep(.3)
    raise RuntimeError(f"Could not start {url}. See {log}")


def serve(args):
    backend = ROOT / "backend"
    dashboard = ROOT / "dashboard"
    flutter = ROOT / "flutter-app"
    state = ROOT / ".local"
    state.mkdir(exist_ok=True)
    data = state / "postgres"
    env = {
        **os.environ,
        "FLUTTER_SUPPRESS_ANALYTICS": "true",
        "NEXT_TELEMETRY_DISABLED": "1",
        "API_PORT": str(args.api_port),
        "THEME_BUILDER_API_URL": f"http://127.0.0.1:{args.api_port}",
        "THEME_BUNDLE_APP_ORIGIN": f"http://127.0.0.1:{args.app_port}",
        "THEME_BUILDER_ADMIN_TOKEN": secrets.token_urlsafe(32),
    }
    flutter_tool = str(Path(args.flutter).expanduser()) if "/" in args.flutter else args.flutter
    if not args.skip_install:
        npm = ["npm", "ci", "--no-audit", "--no-fund"]
        pub = [flutter_tool, "pub", "get"]
        if args.offline:
            npm.append("--offline")
            pub.append("--offline")
        for folder in (backend, dashboard):
            run(npm, cwd=folder, env=env)
        run(pub, cwd=flutter, env=env)

    run([flutter_tool, "build", "web", "--no-pub", "--no-web-resources-cdn",
         "--dart-define=THEME_BUILDER_API_URL=" + env["THEME_BUILDER_API_URL"]],
        cwd=flutter, env=env)

    if not (data / "PG_VERSION").is_file():
        run(["initdb", "-D", str(data), "-U", "theme_bundle", "-A", "trust", "--no-locale", "-E", "UTF8"])

    with ExitStack() as stack:
        socket = stack.enter_context(tempfile.TemporaryDirectory(prefix="bakaloo-pg-", dir="/tmp"))
        env["DATABASE_URL"] = "postgresql://theme_bundle@localhost/postgres?" + urlencode(
            {"host": socket, "port": args.db_port},
        )
        postgres = ["pg_ctl", "-D", str(data), "-w"]
        run([*postgres, "-l", str(state / "postgres.log"), "-o",
             "-h '' -k " + shlex.quote(socket) + f" -p {args.db_port}", "start"])

        def stop_postgres():
            subprocess.run([*postgres, "-m", "fast", "stop"], check=False)

        stack.callback(stop_postgres)
        run(["npm", "run", "migrate"], cwd=backend, env=env)
        api = start(stack, ["node", "src/server.js"], cwd=backend, env=env, log=state / "api.log")
        api_url = env["THEME_BUILDER_API_URL"]
        ready(api, api_url + "/health", state / "api.log")

        next_bin = dashboard / "node_modules/.bin/next"
        editor = start(
            stack, [str(next_bin), "dev", "--hostname", "127.0.0.1", "--port", str(args.dashboard_port)],
            cwd=dashboard, env=env, log=state / "dashboard.log",
        )
        web = start(
            stack, [sys.executable, "-m", "http.server", str(args.app_port), "--bind", "127.0.0.1"],
            cwd=flutter / "build/web", env=env, log=state / "flutter-web.log",
        )
        dashboard_url = f"http://127.0.0.1:{args.dashboard_port}/themes/builder"
        flutter_url = f"http://127.0.0.1:{args.app_port}"
        ready(editor, dashboard_url, state / "dashboard.log")
        ready(web, flutter_url, state / "flutter-web.log")
        print(f"Homepage builder: {dashboard_url}\nFlutter preview: {flutter_url}", flush=True)
        while all(child.poll() is None for child in (api, editor, web)):
            time.sleep(1)
        raise RuntimeError(f"A local service exited. See {state}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter", default="flutter", help="Flutter on PATH or a path to its executable")
    parser.add_argument("--offline", action="store_true", help="install dependencies from local caches")
    parser.add_argument("--skip-install", action="store_true", help="use dependencies already installed")
    for name, default in (("api", 4500), ("dashboard", 4501), ("app", 4502), ("db", 54321)):
        parser.add_argument("--" + name + "-port", type=int, default=default)
    args = parser.parse_args()
    ports = {args.api_port, args.dashboard_port, args.app_port, args.db_port}
    if len(ports) != 4 or not all(1024 <= port <= 65535 for port in ports):
        parser.error("choose four distinct ports between 1024 and 65535")
    # Keep the shutdown path identical for Ctrl-C and a supervisor's SIGTERM.
    signal.signal(signal.SIGTERM, signal.default_int_handler)
    try:
        serve(args)
    except KeyboardInterrupt:
        pass
    except (OSError, subprocess.CalledProcessError, RuntimeError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
