#!/usr/bin/env python3
"""Build a path and static import index from the pinned Git objects."""
import argparse
from collections import defaultdict
import json
import posixpath
from pathlib import Path
import re
import subprocess

REFERENCES = Path(__file__).resolve().parent.parent / "references"
REPOS = json.loads((REFERENCES / "sources.json").read_text())["repositories"]
IMPORT = re.compile(
    r"""\b(?:from|import|export|part(?:\s+of)?)\s*['"]([^'"\r\n]+)['"]"""
    r"""|\b(?:import|require)\s*\(\s*['"]([^'"\r\n]+)['"]"""
)
CODE = re.compile(r"\.(?:[cm]?js|jsx|ts|tsx|dart)$")
EXCLUDED = re.compile(
    r"(?:^|/)(?:\.env(?:\.[^/]+)?|google-services\.json|GoogleService-Info\.plist|"
    r"firebase_options\.dart|key\.properties|credentials\.json|id_rsa|id_ed25519)$"
    r"|\.(?:pem|key|p12|pfx|jks|keystore)$", re.I
)


def run_git(repo, *args, **kwargs):
    return subprocess.run(
        ["git", "-C", str(repo), *args], check=True, stdout=subprocess.PIPE, **kwargs
    ).stdout


def group(role, path):
    parts = path.split("/")
    first = parts[0]
    if role == "backend" and parts[:2] == ["src", "modules"]:
        depth = 4 if parts[2] == "admin" and len(parts) > 4 else 3
        return "/".join(parts[2:depth])
    if role == "dashboard" and first == "src" and len(parts) > 2:
        area, name = parts[1:3]
        if area == "app" and name in {"(dashboard)", "(auth)"} and len(parts) > 3:
            buckets = ["pages", parts[3]]
            if parts[3] in {"hq", "store", "settings", "b2b"} and len(parts) > 5:
                buckets.append(parts[4])
            return "/".join(buckets)
        if area == "services":
            return "services/" + name.split(".", 1)[0]
        if area == "components" and len(parts) > 3:
            return "components/" + name
    if role == "flutter-app" and first == "lib" and len(parts) > 3:
        return "/".join(parts[1:3])
    if first in {"src", "lib", "assets", "test", "tests", "public"} and len(parts) > 2:
        return first + "/" + parts[1]
    return first if len(parts) > 1 else "root"


def tracked_files(repo, commit):
    raw = run_git(repo, "ls-tree", "-r", "-z", commit)
    result = {}
    for record in raw.split(b"\0"):
        if not record:
            continue
        meta, path = record.split(b"\t", 1)
        mode, _, oid = meta.decode("ascii").split()
        path = path.decode("utf-8")
        if mode in {"100644", "100755"} and not EXCLUDED.search(path):
            result[path] = oid
    return result


def code_blobs(repo, files):
    oids = sorted(set(files.values()))
    if not oids:
        return {}
    raw = run_git(repo, "cat-file", "--batch", input=("\n".join(oids) + "\n").encode())
    blobs = {}
    pos = 0
    for oid in oids:
        end = raw.index(b"\n", pos)
        header = raw[pos:end].decode("ascii").split()
        if len(header) != 3 or header[:2] != [oid, "blob"]:
            raise ValueError(f"missing pinned blob {oid} in {repo}")
        size = int(header[2])
        pos = end + 1 + size + 1
        blobs[oid] = raw[end + 1:pos - 1].decode("utf-8", errors="replace")
    return blobs


def resolve_import(role, path, specifier, files):
    if specifier.startswith("."):
        base = posixpath.normpath(posixpath.join(posixpath.dirname(path), specifier))
    elif role == "dashboard" and specifier.startswith("@/"):
        base = "src/" + specifier[2:]
    elif role == "flutter-app" and specifier.startswith("package:bakaloo_flutter_app/"):
        base = "lib/" + specifier.split("/", 1)[1]
    else:
        return None
    stem, suffix = posixpath.splitext(base)
    candidates = [base]
    if suffix in {".js", ".jsx"}:
        candidates.extend([stem + ".ts", stem + ".tsx"])
    extensions = (".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs")
    candidates.extend(base + ext for ext in extensions)
    candidates.extend(base + "/index" + ext for ext in extensions)
    return next((candidate for candidate in candidates if candidate in files), None)


def build(roots):
    modules = {}
    links = defaultdict(list)
    counts = {}
    for role, source in REPOS.items():
        repo = roots[role]
        files = tracked_files(repo, source["commit"])
        if not files:
            raise ValueError(f"empty source tree for {role}")
        owners = {}
        for path in sorted(files):
            key = f"{role}:{group(role, path)}"
            modules.setdefault(key, []).append(path)
            owners[path] = key
        prefixes = ("lib/", "test/") if role == "flutter-app" else ("src/", "tests/", "e2e/")
        scan = {path: oid for path, oid in files.items()
                if path.startswith(prefixes) and CODE.search(path)}
        blobs = code_blobs(repo, scan)
        seen = set()
        for path, oid in sorted(scan.items()):
            for match in IMPORT.finditer(blobs[oid]):
                target = resolve_import(role, path, match[1] or match[2], files)
                if target is None or owners[path] == owners[target] or (path, target) in seen:
                    continue
                seen.add((path, target))
                links[(owners[path], owners[target])].append([path, target])
        counts[role] = {"files": len(files), "scanned": len(scan)}
    edges = [
        {"from": start, "to": end, "count": len(evidence), "evidence": evidence[:2]}
        for (start, end), evidence in sorted(links.items())
    ]
    return {"schema": 1, "commits": {r: x["commit"] for r, x in REPOS.items()},
            "counts": counts, "modules": dict(sorted(modules.items())), "imports": edges}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for role in REPOS:
        parser.add_argument("--" + role, type=Path, required=True)
    parser.add_argument("--output", type=Path, default=REFERENCES / "inventory.json")
    args = parser.parse_args()
    try:
        data = build({role: getattr(args, role.replace("-", "_")) for role in REPOS})
    except (subprocess.CalledProcessError, ValueError) as error:
        parser.exit(1, f"Index failed: {error}\n")
    # Keep each module and each edge on its own line for diffing and grep.
    sections = []
    for key, val in data.items():
        if key == "modules":
            val = "{\n" + ",\n".join("    " + json.dumps(k) + ": " + json.dumps(v)
                                     for k, v in val.items()) + "\n  }"
        elif key == "imports":
            val = "[\n" + ",\n".join("    " + json.dumps(edge) for edge in val) + "\n  ]"
        else:
            val = json.dumps(val)
        sections.append("  " + json.dumps(key) + ": " + val)
    args.output.write_text("{\n" + ",\n".join(sections) + "\n}\n")


if __name__ == "__main__":
    main()
