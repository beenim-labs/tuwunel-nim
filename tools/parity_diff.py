#!/usr/bin/env python3
"""Rust-vs-Nim parity diff harness."""

from __future__ import annotations

import argparse
import json
import os
import re
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

ROOT = Path(__file__).resolve().parents[1]

VOLATILE_JSON_KEYS = {
    "access_token",
    "refresh_token",
    "device_id",
    "event_id",
    "next_batch",
    "origin_server_ts",
    "timestamp",
    "ts",
    "session_id",
    "signatures",
    "unsigned",
}

VOLATILE_TEXT_PATTERNS = [
    (
        re.compile(
            r'"(access_token|refresh_token|device_id|event_id|next_batch|session_id)"\s*:\s*"[^"]+"'
        ),
        r'"\1":"<volatile>"',
    ),
    (re.compile(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b"), "<uuid>"),
    (re.compile(r"\b\d{10,}\b"), "<num>"),
]


@dataclass
class CaseResult:
    id: str
    stage: str
    kind: str
    status: str
    message: str
    details: Dict[str, Any]

    def as_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "stage": self.stage,
            "kind": self.kind,
            "status": self.status,
            "message": self.message,
            "details": self.details,
        }


def load_json(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def try_parse_json(text: str) -> Any:
    stripped = text.strip()
    if not stripped:
        return None
    if not (stripped.startswith("{") or stripped.startswith("[")):
        return None
    try:
        return json.loads(stripped)
    except json.JSONDecodeError:
        return None


def normalize_text(text: str) -> str:
    out = text.strip()
    for pattern, repl in VOLATILE_TEXT_PATTERNS:
        out = pattern.sub(repl, out)
    return out


def normalize_json(value: Any) -> Any:
    if isinstance(value, dict):
        out: Dict[str, Any] = {}
        for key in sorted(value.keys()):
            if key in VOLATILE_JSON_KEYS:
                out[key] = "<volatile>"
            else:
                out[key] = normalize_json(value[key])
        return out
    if isinstance(value, list):
        return [normalize_json(item) for item in value]
    if isinstance(value, str):
        return normalize_text(value)
    return value


def normalized_output(stdout: str, stderr: str) -> Dict[str, Any]:
    out_json = try_parse_json(stdout)
    err_json = try_parse_json(stderr)
    return {
        "stdout": normalize_json(out_json) if out_json is not None else normalize_text(stdout),
        "stderr": normalize_json(err_json) if err_json is not None else normalize_text(stderr),
    }


def run_command(binary: Path, args: List[str], env: Dict[str, str], timeout: int) -> Dict[str, Any]:
    proc_env = os.environ.copy()
    proc_env.update(env)
    try:
        cp = subprocess.run(
            [str(binary), *args],
            capture_output=True,
            text=True,
            env=proc_env,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout if isinstance(exc.stdout, str) else (exc.stdout or b"").decode(
            "utf-8", errors="ignore"
        )
        stderr = exc.stderr if isinstance(exc.stderr, str) else (exc.stderr or b"").decode(
            "utf-8", errors="ignore"
        )
        return {
            "exit_code": -999,
            "stdout": stdout,
            "stderr": stderr,
            "timed_out": True,
            "normalized": normalized_output(stdout, stderr),
        }
    return {
        "exit_code": cp.returncode,
        "stdout": cp.stdout,
        "stderr": cp.stderr,
        "timed_out": False,
        "normalized": normalized_output(cp.stdout, cp.stderr),
    }


def compare_cli_case(case: Dict[str, Any], rust_bin: Path, nim_bin: Path, timeout: int) -> CaseResult:
    case_id = case["id"]
    stage = case.get("stage", "A")
    args = list(case.get("args", []))
    env = dict(case.get("env", {}))
    compare = dict(case.get("compare", {}))

    rust = run_command(rust_bin, args, env, timeout)
    nim = run_command(nim_bin, args, env, timeout)

    checks = []
    if compare.get("exit", "exact") != "ignore":
        checks.append(("exit_code", rust["exit_code"], nim["exit_code"]))
    if compare.get("stdout", "exact") != "ignore":
        checks.append(("stdout", rust["normalized"]["stdout"], nim["normalized"]["stdout"]))
    if compare.get("stderr", "exact") != "ignore":
        checks.append(("stderr", rust["normalized"]["stderr"], nim["normalized"]["stderr"]))

    mismatches = []
    for name, a, b in checks:
        if a != b:
            mismatches.append(name)

    if mismatches:
        return CaseResult(
            id=case_id,
            stage=stage,
            kind="cli",
            status="mismatch",
            message="Mismatch in: " + ", ".join(mismatches),
            details={
                "args": args,
                "env": env,
                "mismatch_fields": mismatches,
                "rust": rust,
                "nim": nim,
            },
        )

    return CaseResult(
        id=case_id,
        stage=stage,
        kind="cli",
        status="pass",
        message="Outputs matched under configured comparison rules",
        details={
            "args": args,
            "env": env,
            "compare": compare,
        },
    )


def find_free_port() -> int:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind(("127.0.0.1", 0))
    port = int(sock.getsockname()[1])
    sock.close()
    return port


def write_runtime_config(path: Path, port: int) -> Path:
    db_path = (path.parent / f"parity-db-{port}").as_posix()
    path.write_text(
        "\n".join(
            [
                "[global]",
                'server_name = "localhost"',
                'address = "127.0.0.1"',
                f"port = {port}",
                f'database_path = "{db_path}"',
                "allow_registration = true",
                "yes_i_am_very_very_sure_i_want_an_open_registration_server_prone_to_abuse = true",
                "allow_encryption = true",
                "allow_federation = false",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return path


def http_request(
    *, port: int, path: str, method: str = "GET", headers: Dict[str, str] | None = None, body: str = "", timeout: int
) -> Dict[str, Any]:
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}{path}",
        data=(body.encode("utf-8") if body else None),
        method=method,
        headers=headers or {},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            text = resp.read().decode("utf-8", errors="ignore")
            parsed = try_parse_json(text)
            return {
                "status": int(resp.status),
                "body": text,
                "json": parsed if isinstance(parsed, dict) else None,
                "errcode": parsed.get("errcode") if isinstance(parsed, dict) else None,
                "ok": True,
            }
    except urllib.error.HTTPError as exc:
        text = exc.read().decode("utf-8", errors="ignore")
        parsed = try_parse_json(text)
        return {
            "status": int(exc.code),
            "body": text,
            "json": parsed if isinstance(parsed, dict) else None,
            "errcode": parsed.get("errcode") if isinstance(parsed, dict) else None,
            "ok": True,
        }
    except Exception as exc:
        return {
            "status": -1,
            "body": "",
            "json": None,
            "errcode": None,
            "ok": False,
            "error": f"{type(exc).__name__}: {exc}",
        }


def start_runtime(binary: Path, config_path: Path, timeout: int) -> Dict[str, Any]:
    child_env = os.environ.copy()
    for key in [
        "TUWUNEL_NIM_BOOTSTRAP_ONLY",
        "TUWUNEL_NIM_REQUIRE_RUST_ENGINE",
        "TUWUNEL_NIM_DISABLE_RUST_DELEGATE",
        "TUWUNEL_RUST_BIN",
        "TUWUNEL_RUST_ROOT",
    ]:
        child_env.pop(key, None)

    proc = subprocess.Popen(
        [str(binary), "-c", str(config_path)],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env=child_env,
    )
    port = int(config_path.stem.split("-")[-1])
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            return {
                "ok": False,
                "proc": proc,
                "port": port,
                "error": f"process exited early with code {proc.returncode}",
            }
        probe = http_request(port=port, path="/_matrix/client/versions", method="GET", timeout=1)
        if probe["ok"] and probe["status"] > 0:
            return {"ok": True, "proc": proc, "port": port}
        time.sleep(0.1)
    return {"ok": False, "proc": proc, "port": port, "error": "startup timeout"}


def stop_runtime(proc: subprocess.Popen) -> None:
    if proc.poll() is not None:
        return
    try:
        proc.terminate()
        proc.wait(timeout=3)
    except Exception:
        proc.kill()
        try:
            proc.wait(timeout=2)
        except Exception:
            pass


def compare_http_probe_case(case: Dict[str, Any], rust_bin: Path, nim_bin: Path, timeout: int) -> CaseResult:
    case_id = case["id"]
    stage = case.get("stage", "A")
    method = str(case.get("method", "GET")).upper()
    path = str(case.get("path", "/"))
    headers = dict(case.get("headers", {}))
    body = str(case.get("body", ""))
    compare = dict(case.get("compare", {}))

    if not rust_bin.exists():
        return CaseResult(
            id=case_id,
            stage=stage,
            kind="http_probe",
            status="skipped",
            message=f"Rust binary not found: {rust_bin}",
            details={},
        )
    if not nim_bin.exists():
        return CaseResult(
            id=case_id,
            stage=stage,
            kind="http_probe",
            status="skipped",
            message=f"Nim binary not found: {nim_bin}",
            details={},
        )

    with tempfile.TemporaryDirectory(prefix="tuwunel-parity-http-") as tmp:
        tmp_path = Path(tmp)
        rust_port = find_free_port()
        nim_port = find_free_port()
        rust_cfg = write_runtime_config(tmp_path / f"rust-{rust_port}.toml", rust_port)
        nim_cfg = write_runtime_config(tmp_path / f"nim-{nim_port}.toml", nim_port)

        rust_runtime = start_runtime(rust_bin, rust_cfg, timeout)
        if not rust_runtime["ok"]:
            stop_runtime(rust_runtime["proc"])
            return CaseResult(
                id=case_id,
                stage=stage,
                kind="http_probe",
                status="skipped",
                message=f"Rust runtime failed to start: {rust_runtime['error']}",
                details={"port": rust_port},
            )

        nim_runtime = start_runtime(nim_bin, nim_cfg, timeout)
        if not nim_runtime["ok"]:
            stop_runtime(rust_runtime["proc"])
            stop_runtime(nim_runtime["proc"])
            return CaseResult(
                id=case_id,
                stage=stage,
                kind="http_probe",
                status="skipped",
                message=f"Nim runtime failed to start: {nim_runtime['error']}",
                details={"port": nim_port},
            )

        try:
            rust_resp = http_request(
                port=rust_port,
                path=path,
                method=method,
                headers=headers,
                body=body,
                timeout=timeout,
            )
            nim_resp = http_request(
                port=nim_port,
                path=path,
                method=method,
                headers=headers,
                body=body,
                timeout=timeout,
            )
        finally:
            stop_runtime(rust_runtime["proc"])
            stop_runtime(nim_runtime["proc"])

    if not rust_resp["ok"] or not nim_resp["ok"]:
        return CaseResult(
            id=case_id,
            stage=stage,
            kind="http_probe",
            status="mismatch",
            message="Failed to execute HTTP probe request",
            details={"rust": rust_resp, "nim": nim_resp, "path": path, "method": method},
        )

    mismatches: List[str] = []
    if compare.get("status", "exact") != "ignore" and rust_resp["status"] != nim_resp["status"]:
        mismatches.append("status")
    if compare.get("errcode", "ignore") != "ignore" and rust_resp["errcode"] != nim_resp["errcode"]:
        mismatches.append("errcode")

    required_keys = list(compare.get("required_json_keys", []))
    rust_json = rust_resp.get("json") if isinstance(rust_resp.get("json"), dict) else {}
    nim_json = nim_resp.get("json") if isinstance(nim_resp.get("json"), dict) else {}
    for key in required_keys:
        if (key in rust_json) != (key in nim_json):
            mismatches.append(f"required_json_keys:{key}")

    stable_keys = list(compare.get("stable_json_keys", []))
    for key in stable_keys:
        if rust_json.get(key) != nim_json.get(key):
            mismatches.append(f"stable_json_keys:{key}")

    if mismatches:
        return CaseResult(
            id=case_id,
            stage=stage,
            kind="http_probe",
            status="mismatch",
            message="Mismatch in: " + ", ".join(mismatches),
            details={
                "path": path,
                "method": method,
                "headers": headers,
                "mismatch_fields": mismatches,
                "rust": rust_resp,
                "nim": nim_resp,
            },
        )

    return CaseResult(
        id=case_id,
        stage=stage,
        kind="http_probe",
        status="pass",
        message="HTTP probe matched under configured comparison rules",
        details={"path": path, "method": method, "compare": compare},
    )


def extract_nim_string_array(source: str, symbol: str) -> List[str]:
    pattern = re.compile(
        rf"let\s+{re.escape(symbol)}\*\s*:\s*seq\[string\]\s*=\s*@\[(.*?)\]\s*",
        re.DOTALL,
    )
    m = pattern.search(source)
    if not m:
        return []
    body = m.group(1)
    return re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', body)


def route_inventory_cases(case: Dict[str, Any]) -> List[CaseResult]:
    stage = case.get("stage", "B")
    inventory_path = ROOT / case.get("inventory", "docs/parity/route_inventory.json")
    generated_path = ROOT / case.get("generated", "src/api/generated_route_inventory.nim")

    routes = load_json(inventory_path)
    generated_text = generated_path.read_text(encoding="utf-8", errors="ignore")
    nim_client = set(extract_nim_string_array(generated_text, "ClientRumaRoutes"))
    nim_server = set(extract_nim_string_array(generated_text, "ServerRumaRoutes"))
    nim_manual = set(extract_nim_string_array(generated_text, "ManualRoutes"))

    results: List[CaseResult] = []
    for kind, names, nim_set in [
        ("client", list(routes["client_ruma_routes"]), nim_client),
        ("server", list(routes["server_ruma_routes"]), nim_server),
        ("manual", list(routes["manual_routes"]), nim_manual),
    ]:
        for name in names:
            case_id = f"route:{kind}:{name}"
            if name in nim_set:
                results.append(
                    CaseResult(
                        id=case_id,
                        stage=stage,
                        kind="route_inventory",
                        status="pass",
                        message="Route present in generated Nim inventory",
                        details={"route": name, "route_kind": kind},
                    )
                )
            else:
                results.append(
                    CaseResult(
                        id=case_id,
                        stage=stage,
                        kind="route_inventory",
                        status="mismatch",
                        message="Route missing from generated Nim inventory",
                        details={"route": name, "route_kind": kind},
                    )
                )

    return results


def complement_cases(case: Dict[str, Any]) -> List[CaseResult]:
    stage = case.get("stage", "C")
    baseline_path = ROOT / case.get("baseline", "docs/parity/complement_baseline.json")
    nim_results_path = ROOT / case.get("nim_results", "docs/parity/complement_results.jsonl")
    baseline = load_json(baseline_path)

    if not nim_results_path.exists():
        return [
            CaseResult(
                id="complement:missing_results",
                stage=stage,
                kind="complement_actions",
                status="skipped",
                message=f"Nim complement results missing at {nim_results_path.relative_to(ROOT)}",
                details={"expected_tests": len(baseline.get("tests", []))},
            )
        ]

    nim_by_test: Dict[str, str] = {}
    for raw in nim_results_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        raw = raw.strip()
        if not raw:
            continue
        obj = json.loads(raw)
        nim_by_test[obj.get("Test", "")] = obj.get("Action", "unknown")

    results: List[CaseResult] = []
    for item in baseline.get("tests", []):
        test_name = item.get("test", "")
        expected_action = item.get("action", "unknown")
        actual_action = nim_by_test.get(test_name)
        case_id = f"complement:{test_name}"

        if actual_action is None:
            results.append(
                CaseResult(
                    id=case_id,
                    stage=stage,
                    kind="complement_actions",
                    status="skipped",
                    message="Test result missing from Nim complement dataset",
                    details={"expected_action": expected_action},
                )
            )
            continue

        if actual_action != expected_action:
            results.append(
                CaseResult(
                    id=case_id,
                    stage=stage,
                    kind="complement_actions",
                    status="mismatch",
                    message="Complement action mismatch",
                    details={"expected_action": expected_action, "actual_action": actual_action},
                )
            )
            continue

        results.append(
            CaseResult(
                id=case_id,
                stage=stage,
                kind="complement_actions",
                status="pass",
                message="Complement action matched baseline",
                details={"action": expected_action},
            )
        )

    return results


def resolve_baseline_commit(path: Path) -> str:
    baseline = load_json(path)
    return baseline.get("baseline", {}).get("rust_commit", "")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rust-bin", type=Path, required=True)
    parser.add_argument("--nim-bin", type=Path, required=True)
    parser.add_argument("--scenarios", type=Path, default=ROOT / "tests/parity/scenarios.json")
    parser.add_argument("--out", type=Path, default=ROOT / "docs/parity/runtime_diff_report.json")
    parser.add_argument("--baseline", type=Path, default=ROOT / "docs/parity/baseline.json")
    parser.add_argument("--timeout-seconds", type=int, default=20)
    args = parser.parse_args()

    scenario_doc = load_json(args.scenarios)
    cases = list(scenario_doc.get("scenarios", []))

    results: List[CaseResult] = []
    for case in cases:
        kind = case.get("kind")
        if kind == "cli":
            if not args.rust_bin.exists():
                results.append(
                    CaseResult(
                        id=case["id"],
                        stage=case.get("stage", "A"),
                        kind="cli",
                        status="skipped",
                        message=f"Rust binary not found: {args.rust_bin}",
                        details={},
                    )
                )
                continue
            if not args.nim_bin.exists():
                results.append(
                    CaseResult(
                        id=case["id"],
                        stage=case.get("stage", "A"),
                        kind="cli",
                        status="skipped",
                        message=f"Nim binary not found: {args.nim_bin}",
                        details={},
                    )
                )
                continue
            results.append(compare_cli_case(case, args.rust_bin, args.nim_bin, args.timeout_seconds))
        elif kind == "route_inventory":
            results.extend(route_inventory_cases(case))
        elif kind == "http_probe":
            results.append(compare_http_probe_case(case, args.rust_bin, args.nim_bin, args.timeout_seconds))
        elif kind == "complement_actions":
            results.extend(complement_cases(case))
        else:
            results.append(
                CaseResult(
                    id=case.get("id", "unknown"),
                    stage=case.get("stage", "?"),
                    kind=str(kind),
                    status="error",
                    message=f"Unsupported scenario kind: {kind}",
                    details={},
                )
            )

    report = {
        "baseline_commit": resolve_baseline_commit(args.baseline),
        "generated_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "rust_bin": str(args.rust_bin),
        "nim_bin": str(args.nim_bin),
        "scenario_sources": {
            "scenarios": str(args.scenarios),
            "baseline": str(args.baseline),
        },
        "scenarios_total": len(results),
        "passes_total": sum(1 for r in results if r.status == "pass"),
        "mismatches_total": sum(1 for r in results if r.status in {"mismatch", "error"}),
        "skipped_total": sum(1 for r in results if r.status == "skipped"),
        "results": [r.as_dict() for r in results],
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    print(f"Wrote {args.out}")

    return 1 if report["mismatches_total"] > 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
