"""Small, dependency-free MCP bridge for the Sanity Drift Godot project."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


PROJECT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_EXE") or shutil.which("godot") or shutil.which("godot4")
if not GODOT:
    default = Path.home() / "Desktop" / "Godot_v4.7.2-stable_win64.exe"
    if default.is_file():
        GODOT = str(default)


def send(message):
    raw = json.dumps(message, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    sys.stdout.buffer.write(raw + b"\n")
    sys.stdout.buffer.flush()


def receive():
    line = sys.stdin.buffer.readline()
    return json.loads(line) if line else None


TOOLS = [
    {"name": "godot_project_info", "description": "Show this Godot project's path, executable, and scenes/scripts.", "inputSchema": {"type": "object", "properties": {}}},
    {"name": "godot_validate", "description": "Import and parse the Godot project headlessly; return diagnostics.", "inputSchema": {"type": "object", "properties": {}}},
    {"name": "godot_run_test", "description": "Run a project test script headlessly by filename from tests/.", "inputSchema": {"type": "object", "properties": {"name": {"type": "string", "description": "For example, smoke_test.gd"}}, "required": ["name"]}},
]


def result(text, error=False):
    return {"content": [{"type": "text", "text": text}], "isError": error}


def run_godot(args, timeout):
    if not GODOT or not Path(GODOT).is_file():
        return result("Godot executable not found. Set GODOT_EXE to its full path.", True)
    try:
        proc = subprocess.run([GODOT, "--headless", "--path", str(PROJECT), *args], cwd=PROJECT, capture_output=True, text=True, timeout=timeout, errors="replace")
    except subprocess.TimeoutExpired:
        return result(f"Godot timed out after {timeout} seconds.", True)
    output = (proc.stdout + "\n" + proc.stderr).strip()
    return result(f"Exit code: {proc.returncode}\n{output[-30000:]}", proc.returncode != 0)


def call(name, args):
    if name == "godot_project_info":
        files = sorted(str(p.relative_to(PROJECT)).replace("\\", "/") for pattern in ("*.tscn", "*.gd") for p in PROJECT.rglob(pattern) if ".godot" not in p.parts)
        return result(json.dumps({"project": str(PROJECT), "godot_executable": GODOT, "files": files}, indent=2))
    if name == "godot_validate":
        return run_godot(["--editor", "--import", "--quit"], 120)
    if name == "godot_run_test":
        test = args.get("name", "")
        if not isinstance(test, str) or not test.endswith(".gd") or Path(test).name != test:
            return result("Provide a .gd filename from tests/.", True)
        if not (PROJECT / "tests" / test).is_file():
            return result(f"Test not found: tests/{test}", True)
        return run_godot(["--script", f"res://tests/{test}"], 180)
    return result(f"Unknown tool: {name}", True)


def main():
    while message := receive():
        method = message.get("method")
        request_id = message.get("id")
        if request_id is None:
            continue
        if method == "initialize":
            payload = {"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "sanity-drift-godot", "version": "1.0.0"}}
        elif method == "tools/list":
            payload = {"tools": TOOLS}
        elif method == "tools/call":
            params = message.get("params") or {}
            payload = call(params.get("name"), params.get("arguments") or {})
        else:
            send({"jsonrpc": "2.0", "id": request_id, "error": {"code": -32601, "message": f"Method not found: {method}"}})
            continue
        send({"jsonrpc": "2.0", "id": request_id, "result": payload})


if __name__ == "__main__":
    main()
