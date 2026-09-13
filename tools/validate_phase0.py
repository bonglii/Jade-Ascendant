#!/usr/bin/env python3
"""Jade Ascendant Phase 0. Python 3.10+, standard library only.

Run from the project root:
  python tools/validate_phase0.py --godot "C:/Godot/Godot_console.exe"
  python tools/validate_phase0.py --static-only

Engine checks use a clean disposable project copy and a unique save directory.
The original project, import cache, and gameplay saves are never test fixtures.
Exit 0: requested checks passed; 1: failed; 2: engine checks not available.
Static-only success is never a Godot/parser/runtime/release PASS.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import uuid
from pathlib import Path

TEXT_EXTENSIONS = {".gd", ".tscn", ".tres", ".gdshader", ".godot", ".cfg"}
SKIP_DIRS = {".godot", ".git", ".svn", "__pycache__", ".idea", ".local", "artifacts", "android"}
ENGINE_ISSUE = re.compile(
    r"(?im)^\s*(?:SCRIPT ERROR:|USER ERROR:|ERROR:|Parse Error:|"
    r"Parser Error:|WARNING:|USER WARNING:)|\b(?:leaked at exit|still in use at exit)\b"
)


def project_files(project: Path):
    for item in sorted(project.rglob("*")):
        if item.is_file() and not SKIP_DIRS.intersection(item.relative_to(project).parts):
            yield item


def string_values(source: str, semicolon_comments: bool = False):
    """Lex literal strings, including embedded GDScript; not a Godot parser."""
    i, line = 0, 1
    while i < len(source):
        char = source[i]
        if char == "#" or (char == ";" and semicolon_comments):
            end = source.find("\n", i)
            i = len(source) if end < 0 else end
        elif char in "\"'":
            start_line = line
            delim = char * (3 if source.startswith(char * 3, i) else 1)
            i += len(delim)
            value = []
            while i < len(source) and not source.startswith(delim, i):
                if source[i] == "\\" and i + 1 < len(source):
                    escaped = source[i + 1]
                    value.append({"n": "\n", "r": "\r", "t": "\t"}.get(escaped, escaped))
                    i += 2
                else:
                    line += source[i] == "\n"
                    value.append(source[i])
                    i += 1
            i += len(delim)
            yield start_line, "".join(value)
        else:
            line += char == "\n"
            i += 1


def scan(project: Path) -> dict:
    files = list(project_files(project))
    texts = {
        item.relative_to(project).as_posix(): item.read_text(encoding="utf-8-sig")
        for item in files if item.suffix in TEXT_EXTENSIONS
    }
    references, errors = [], []
    autoloads = dict(re.findall(r'(?m)^(\w+)="\*(res://[^"]+)"', texts["project.godot"]))
    dependencies = {}
    for relative, body in texts.items():
        literals = list(string_values(body, relative.endswith((".cfg", ".godot"))))
        if relative.endswith((".tscn", ".tres")):
            for line, value in literals.copy():
                if "\n" in value and "res://" in value:
                    literals.extend((line + n - 1, v) for n, v in string_values(value))
        for line, value in literals:
            value = value.removeprefix("*")
            if not value.startswith("res://") or "\n" in value:
                continue
            reference = {"source": relative, "line": line, "target": value}
            references.append(reference)
            target = project / value[6:]
            if not target.exists():
                errors.append({"type": "missing_literal_resource", **reference})
        if relative.endswith((".tscn", ".tres")):
            # Resource references are checked outside embedded script strings.
            for kind, section in (("ExtResource", "ext_resource"), ("SubResource", "sub_resource")):
                ids = set(re.findall(r'(?m)^\[' + section + r' [^\n]*\bid="([^"]+)"', body))
                for match in re.finditer(r'\b' + kind + r'\("([^"]+)"\)', body):
                    if match[1] not in ids:
                        errors.append({"type": "undefined_" + kind, "source": relative, "id": match[1]})
        if relative.endswith(".gd"):
            dependencies[relative] = {
                "classes": re.findall(r"(?m)^class_name\s+(\w+)", body),
                "signals": re.findall(r"(?m)^signal\s+(\w+)", body),
                "autoloads_used": [name for name in autoloads if re.search(r"\b" + name + r"\.", body)],
            }
    return {
        "static_status": "PASS" if not errors else "FAIL",
        "scope": "Literal resource paths, resource IDs, inventory and dependency map; not engine validation.",
        "counts": dict(collections.Counter(item.suffix for item in files)),
        "autoloads": autoloads,
        "reference_count": len(references),
        "unique_targets": len({item["target"] for item in references}),
        "references": references,
        "errors": errors,
        "script_dependencies": dependencies,
        "file_sha256": {item.relative_to(project).as_posix(): hashlib.sha256(item.read_bytes()).hexdigest() for item in files},
    }


def set_config_values(path: Path, section: str, values: dict[str, str]):
    """Change only a disposable copy's configuration; preserve other settings."""
    content = path.read_text(encoding="utf-8-sig") if path.exists() else ""
    header = re.search(r"(?m)^\[" + re.escape(section) + r"\]\s*$", content)
    if header:
        following = re.search(r"(?m)^\[", content[header.end():])
        end = header.end() + following.start() if following else len(content)
        current = content[header.end():end]
        for key in values:
            current = re.sub(r"(?m)^" + re.escape(key) + r"=.*(?:\n|$)", "", current)
        replacement = current.rstrip() + "\n" + "\n".join(k + "=" + v for k, v in values.items()) + "\n\n"
        content = content[:header.end()] + replacement + content[end:]
    else:
        content += "\n[" + section + "]\n\n" + "\n".join(k + "=" + v for k, v in values.items()) + "\n"
    path.write_text(content, encoding="utf-8", newline="\n")


def run_step(command: list[str], log_path: Path, timeout: float) -> dict:
    try:
        with log_path.open("w", encoding="utf-8") as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=timeout, check=False)
        output = log_path.read_text(encoding="utf-8", errors="replace")
        issues = [line for line in output.splitlines() if ENGINE_ISSUE.search(line)]
        return {"status": "PASS" if result.returncode == 0 and not issues else "FAIL",
                "exit_code": result.returncode, "issues": issues, "log": str(log_path)}
    except subprocess.TimeoutExpired:
        return {"status": "FAIL", "reason": "timeout", "log": str(log_path)}
    except OSError as error:
        return {"status": "FAIL", "reason": str(error), "log": str(log_path)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--godot", help="Exact Godot 4.7.2 editor/console executable")
    parser.add_argument("--expected-version", default="4.7.2.stable.official.ed1daf0bf")
    parser.add_argument("--static-only", action="store_true")
    parser.add_argument("--report-dir", type=Path)
    parser.add_argument("--timeout", type=float, default=180)
    args = parser.parse_args()
    project = args.project.resolve()
    if not (project / "project.godot").is_file():
        parser.error("--project must contain project.godot")
    report_dir = (args.report_dir or project.parent / (project.name + "-phase0-results")).resolve()
    if report_dir.is_relative_to(project):
        parser.error("Keep --report-dir outside the source project")
    report_dir.mkdir(parents=True, exist_ok=True)
    summary = {"static": scan(project), "engine_status": "NOT_RUN", "release_status": "NOT_VERIFIED"}

    def finish(code: int) -> int:
        (report_dir / "phase0_results.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        print("Static:", summary["static"]["static_status"], "| Engine:", summary["engine_status"])
        print("Report:", report_dir / "phase0_results.json")
        return code

    if summary["static"]["errors"]:
        return finish(1)
    if args.static_only:
        return finish(0)
    candidate = args.godot or shutil.which("godot") or shutil.which("godot4")
    if not candidate:
        summary["reason"] = "Godot not found. Pass --godot with the exact editor/console executable."
        return finish(2)
    engine = shutil.which(candidate) or str(Path(candidate).resolve())
    try:
        version_result = subprocess.run([engine, "--version"], capture_output=True, text=True, timeout=15, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        summary["reason"] = str(error)
        return finish(2)
    version = version_result.stdout.strip()
    summary["engine_version"] = version
    if version_result.returncode or version != args.expected_version:
        summary["reason"] = "Engine version does not match --expected-version; no source import attempted."
        return finish(2)
    token = "jade_phase0_" + uuid.uuid4().hex
    summary["qa_namespace"] = token
    with tempfile.TemporaryDirectory(prefix="jade-phase0-") as temporary:
        working = Path(temporary) / "project"
        shutil.copytree(project, working, ignore=shutil.ignore_patterns(*SKIP_DIRS, "*.tmp"))
        settings = {"config/use_custom_user_dir": "true", "config/custom_user_dir_name": json.dumps(token)}
        # Both files are set before the first engine invocation, including import.
        set_config_values(working / "project.godot", "application", settings)
        set_config_values(working / "override.cfg", "application", settings)
        set_config_values(working / "override.cfg", "jade_phase0", {"token": json.dumps(token)})
        command = [engine, "--headless", "--path", str(working)]
        summary["import"] = run_step(command + ["--import"], report_dir / "import.log", args.timeout)
        if summary["import"]["status"] != "PASS":
            summary["engine_status"] = "FAIL"
            return finish(1)
        smoke_log = report_dir / "smoke.log"
        summary["smoke"] = run_step(command + ["--verbose", "--script", "res://tests/phase0_smoke.gd", "--", "--phase0-token", token], smoke_log, args.timeout)
        output = smoke_log.read_text(encoding="utf-8", errors="replace")
        if "[SYSTEM] JADE_PHASE0_PASS" not in output:
            summary["smoke"]["status"] = "FAIL"
            summary["smoke"]["missing_success_marker"] = True
        summary["engine_status"] = summary["smoke"]["status"]
    return finish(0 if summary["engine_status"] == "PASS" else 1)


if __name__ == "__main__":
    raise SystemExit(main())
