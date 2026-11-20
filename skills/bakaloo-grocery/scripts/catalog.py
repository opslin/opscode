#!/usr/bin/env python3
"""Search, inspect, plan and fetch Bakaloo's pinned project template."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import tempfile

REFERENCES = Path(__file__).resolve().parent.parent / "references"
SKILL_ROOT = REFERENCES.parent
SOURCE = json.loads((REFERENCES / "sources.json").read_text())
TEMPLATE = json.loads((REFERENCES / "template.json").read_text())
INDEX = json.loads((REFERENCES / "inventory.json").read_text())
REPOS = SOURCE["repositories"]
PROFILES = TEMPLATE["profiles"]
BUNDLES = TEMPLATE.get("bundles", {})
MODULES = TEMPLATE["modules"]
GROUPS = INDEX["modules"]
CONTRACTS = [
    {"from": item["source"], "to": item["target"], "kind": "contract",
     "detail": item["relationship"], "evidence": [item["evidence"]]}
    for item in TEMPLATE["contracts"]
]
IMPORTS = [dict(item, kind="static-import") for item in INDEX["imports"]]


def emit(data):
    print(json.dumps(data, indent=2, ensure_ascii=False))


def tokens(text):
    return set(re.findall(r"[a-z0-9]+", text.lower()))


def find(query, limit, repo):
    terms = tokens(query)
    results = []
    for key, module in MODULES.items():
        if repo and not any(group.startswith(repo + ":") for group in module["groups"]):
            continue
        names = tokens(" ".join([key, *module["aliases"]]))
        matches = terms & names
        score = len(matches) * 8 + len(terms & tokens(module["summary"]))
        if score:
            results.append((score, key, {"id": key, "kind": "recipe", "summary": module["summary"]}))
    for key, paths in GROUPS.items():
        role, group = key.split(":", 1)
        if repo and role != repo:
            continue
        score = len(terms & tokens(group)) * 4 + len(terms & tokens(" ".join(paths)))
        if score:
            results.append((score, key, {"id": key, "kind": "source-group", "files": len(paths)}))
    return [row for _, _, row in sorted(results, key=lambda row: (-row[0], row[1]))[:limit]]


def resolve(selected):
    seen = set()
    pending = set()
    order = []

    def visit(module):
        if module not in MODULES:
            raise ValueError(f"unknown recipe: {module}")
        if module in seen:
            return
        if module in pending:
            raise ValueError(f"recipe dependency cycle at {module}")
        pending.add(module)
        for dependency in MODULES[module]["requires"]:
            visit(dependency)
        pending.remove(module)
        seen.add(module)
        order.append(module)

    for module in selected:
        visit(module)
    return order


def source_roles(resolved):
    return {group.split(":", 1)[0] for module in resolved for group in MODULES[module]["groups"]}


def plan(args):
    profile_modules = PROFILES[args.profile]["modules"] if args.profile else []
    selected = list(dict.fromkeys(profile_modules + args.modules))
    if not selected:
        raise ValueError("select a profile or at least one recipe")
    resolved = resolve(selected)
    roles = source_roles(resolved)
    bundle = next((item for item in BUNDLES.values()
                   if set(resolved) == set(item["covers"])), None)
    return {
        "template": TEMPLATE["id"], "version": TEMPLATE["version"], "profile": args.profile,
        "inputs": {"brand": args.brand, "app_id": args.app_id},
        "sources": {role: REPOS[role] for role in REPOS if role in roles},
        "modules": [{"id": module, "requested": module in selected,
                     **{key: val for key, val in MODULES[module].items() if key != "aliases"}}
                    for module in resolved],
        "assembly": bundle or "Pinned reference source. Validate and adapt each recipe in the destination.",
        "checkout_required": bundle is None,
    }


def show(item, limit):
    if item in MODULES:
        module = MODULES[item]
        return {"id": item, **module, "dependency_order": resolve([item]),
                "group_sizes": {key: len(GROUPS[key]) for key in module["groups"]}}
    if item not in GROUPS:
        raise ValueError(f"unknown recipe or source group: {item}")
    role = item.split(":", 1)[0]
    paths = GROUPS[item]
    links = IMPORTS + CONTRACTS
    return {"id": item, "source": REPOS[role], "file_count": len(paths), "files": paths[:limit],
            "more_files": max(0, len(paths) - limit),
            "imports_or_calls": [link for link in links if link["from"] == item],
            "used_by": [link for link in links if link["to"] == item]}


def graph(item):
    dependencies = [
        {"from": name, "to": dep, "kind": "recipe-requires"}
        for name, module in MODULES.items() for dep in module["requires"]
    ]
    links = IMPORTS + CONTRACTS
    if item is None:
        membership = [{"from": name, "to": group, "kind": "source-group"}
                      for name, module in MODULES.items() for group in module["groups"]]
        edges = dependencies + membership + links
        nodes = set(MODULES) | set(GROUPS)
    elif item in MODULES:
        recipes = set(resolve([item]))
        groups = set(MODULES[item]["groups"])
        nodes = recipes | groups
        edges = [edge for edge in dependencies + links
                 if edge["from"] in nodes and edge["to"] in nodes]
        edges.extend({"from": item, "to": group, "kind": "source-group"} for group in sorted(groups))
    elif item in GROUPS:
        edges = [edge for edge in links if item in (edge["from"], edge["to"])]
        nodes = {item} | {edge[key] for edge in edges for key in ("from", "to")}
    else:
        raise ValueError(f"unknown recipe or source group: {item}")
    return {"nodes": sorted(nodes), "edges": edges}


def mermaid(data):
    # Node IDs are generated and labels are escaped for Mermaid.
    ids = {key: f"n{i}" for i, key in enumerate(data["nodes"])}
    print("flowchart LR")
    for key, node in ids.items():
        label = key.replace('"', "&quot;")
        print(f'  {node}["{label}"]')
    for edge in data["edges"]:
        print(f'  {ids[edge["from"]]} -->|{edge["kind"]}| {ids[edge["to"]]}')


def validate():
    if not all(data["schema"] == 1 for data in (SOURCE, TEMPLATE, INDEX)):
        raise ValueError("unsupported catalog schema")
    commits = {role: source["commit"] for role, source in REPOS.items()}
    if INDEX["commits"] != commits or not all(re.fullmatch(r"[a-f0-9]{40}", x) for x in commits.values()):
        raise ValueError("source pins differ from the index")
    resolve(MODULES)
    for key, module in MODULES.items():
        if (not module["groups"] or not module["checks"]
                or not set(module["groups"]) <= GROUPS.keys()
                or not (REFERENCES / module["guide"]).is_file()):
            raise ValueError(f"incomplete recipe: {key}")
    for key, profile in PROFILES.items():
        if source_roles(resolve(profile["modules"])) != set(profile["repositories"]):
            raise ValueError(f"unexpected repository dependencies in profile: {key}")
    for key, bundle in BUNDLES.items():
        if (key not in PROFILES
                or set(bundle["covers"]) != set(resolve(PROFILES[key]["modules"]))
                or not (SKILL_ROOT / bundle["source"] / bundle["entrypoint"]).is_file()
                or not (SKILL_ROOT / bundle["assembler"]).is_file()
                or not (SKILL_ROOT / bundle["guide"]).is_file()):
            raise ValueError(f"incomplete assembly bundle: {key}")
    all_paths = set()
    by_repo = Counter()
    for group, paths in GROUPS.items():
        role = group.split(":", 1)[0]
        if role not in REPOS or not paths:
            raise ValueError(f"invalid source group: {group}")
        for path in paths:
            key = (role, path)
            if key in all_paths or path.startswith("/") or ".." in path.split("/"):
                raise ValueError(f"invalid or duplicate source path: {role}:{path}")
            all_paths.add(key)
            by_repo[role] += 1
    if any(by_repo[role] != INDEX["counts"][role]["files"] for role in REPOS):
        raise ValueError("source path coverage differs from the inventory counts")
    for edge in IMPORTS + CONTRACTS:
        origin, target = edge["from"], edge["to"]
        if origin not in GROUPS or target not in GROUPS or origin == target:
            raise ValueError(f"invalid graph edge: {origin} -> {target}")
        if not edge["evidence"] or any(a not in GROUPS[origin] or b not in GROUPS[target]
                                       for a, b in edge["evidence"]):
            raise ValueError(f"invalid graph evidence: {origin} -> {target}")
    return {"template": TEMPLATE["version"], "recipes": len(MODULES), "source_groups": len(GROUPS),
            "files": len(all_paths), "static_import_edges": len(IMPORTS), "api_contracts": len(CONTRACTS)}


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True,
                          stdout=subprocess.PIPE, text=True).stdout.strip()


def checkout(args):
    destination = args.destination.expanduser().absolute()
    if destination.exists() or destination.is_symlink():
        raise ValueError(f"checkout destination already exists: {destination}")
    roles = list(dict.fromkeys(args.repo or REPOS))
    overrides = {}
    for override in args.local:
        role, sep, path = override.partition("=")
        if not sep or role not in roles or role in overrides or not path:
            raise ValueError("--from expects a unique selected ROLE=/path/to/checkout")
        overrides[role] = str(Path(path).expanduser().resolve(strict=True))
    # Stage below the destination's existing parent and publish only when every pin checks out.
    with tempfile.TemporaryDirectory(prefix=".bakaloo-", dir=destination.parent) as temporary:
        staging = Path(temporary) / destination.name
        staging.mkdir()
        for role in roles:
            repo = staging / role
            repo.mkdir()
            source = REPOS[role]
            git(repo, "init", "--quiet")
            git(repo, "fetch", "--quiet", "--depth=1", "--no-tags", "--no-recurse-submodules",
                overrides.get(role, source["url"]), source["commit"])
            git(repo, "checkout", "--quiet", "--detach", source["commit"])
            if git(repo, "rev-parse", "HEAD") != source["commit"]:
                raise ValueError(f"could not confirm pin for {role}")
        if destination.exists() or destination.is_symlink():
            raise ValueError(f"checkout destination already exists: {destination}")
        staging.rename(destination)
    return {"destination": str(destination), "sources": {role: REPOS[role] for role in roles}}


def positive(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list", help="list build profiles and curated recipes")
    commands.add_parser("validate", help="check pins, membership, dependency order and evidence")
    search = commands.add_parser("search", help="find a recipe or source group")
    search.add_argument("query")
    search.add_argument("--repo", choices=REPOS)
    search.add_argument("--limit", type=positive, default=12)
    details = commands.add_parser("show", help="show a recipe or exact file group")
    details.add_argument("item")
    details.add_argument("--limit", type=positive, default=30)
    make_plan = commands.add_parser("plan", help="resolve prerequisites for selected recipes")
    make_plan.add_argument("modules", nargs="*", metavar="RECIPE")
    make_plan.add_argument("--profile", choices=PROFILES)
    make_plan.add_argument("--brand")
    make_plan.add_argument("--app-id")
    draw = commands.add_parser("graph", help="show an item's graph or the entire catalog")
    target = draw.add_mutually_exclusive_group(required=True)
    target.add_argument("--item")
    target.add_argument("--all", action="store_true")
    draw.add_argument("--format", choices=["json", "mermaid"], default="json")
    fetch = commands.add_parser("checkout", help="fetch exact source pins into a new folder")
    fetch.add_argument("destination", type=Path)
    fetch.add_argument("--repo", choices=REPOS, action="append")
    fetch.add_argument("--from", dest="local", action="append", default=[])
    args = parser.parse_args()
    try:
        actions = {
            "list": lambda: {"profiles": PROFILES, "modules": {
                key: val["summary"] for key, val in MODULES.items()}},
            "search": lambda: find(args.query, args.limit, args.repo),
            "show": lambda: show(args.item, args.limit),
            "plan": lambda: plan(args),
            "graph": lambda: graph(args.item),
            "validate": validate,
            "checkout": lambda: checkout(args),
        }
        result = actions[args.command]()
        if args.command == "graph" and args.format == "mermaid":
            mermaid(result)
        else:
            emit(result)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
