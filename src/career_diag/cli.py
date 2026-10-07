from __future__ import annotations

import argparse
import asyncio
import json
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from ps4debug import PS4Debug


@dataclass
class SessionSummary:
    host: str
    pid: int
    process_name: str
    value_type: str = "int32"
    current_value: int | None = None
    candidate_count: int = 0
    sample: list[dict[str, Any]] | None = None
    updated_at: str | None = None


HELP = """Commands:
  first <value>    start a new exact int32 scan
  refine <value>   refine the current scan using the new exact value
  show             show current candidate sample
  reset            clear the current scan
  save             write a JSON session summary
  help             show this help
  quit             exit
"""


def _proc_name(proc: Any) -> str:
    return str(getattr(proc, "name", "<unknown>"))


def _proc_pid(proc: Any) -> int:
    return int(getattr(proc, "pid"))


async def choose_process(ps4: PS4Debug) -> Any:
    processes = await ps4.get_processes()
    if not processes:
        raise RuntimeError("No processes returned by ps4debug.")

    print("\nRunning processes:")
    for idx, proc in enumerate(processes):
        print(f"[{idx:02}] pid={_proc_pid(proc):6}  {_proc_name(proc)}")

    while True:
        raw = input("\nProcess index: ").strip()
        try:
            idx = int(raw)
            return processes[idx]
        except (ValueError, IndexError):
            print("Invalid index.")


def make_sample(results: dict[int, Any], limit: int = 20) -> list[dict[str, Any]]:
    items = []
    for address, value in list(results.items())[:limit]:
        items.append({"address": f"0x{address:016X}", "value": value})
    return items


def print_results(results: dict[int, Any], limit: int = 20) -> None:
    print(f"Candidates: {len(results):,}")
    if not results:
        return
    print("Sample:")
    for item in make_sample(results, limit):
        print(f"  {item['address']} = {item['value']}")


async def run(args: argparse.Namespace) -> None:
    if args.discover:
        print("Discovering PS4 on local network...")
        ps4 = await PS4Debug.discover()
    else:
        ps4 = PS4Debug(args.host)

    version = await ps4.get_version()
    print(f"Connected to {ps4.host} | ps4debug {version}")

    proc = await choose_process(ps4)
    pid = _proc_pid(proc)
    pname = _proc_name(proc)
    print(f"\nSelected: {pname} (pid {pid})")

    scanner = ps4.scan(pid)
    results: dict[int, Any] = {}
    current_value: int | None = None

    print("\nRead-only diagnostic mode.")
    print(HELP)

    while True:
        try:
            raw = input("career-diag> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break

        if not raw:
            continue

        parts = raw.split()
        command = parts[0].lower()

        if command in {"quit", "exit", "q"}:
            break

        if command == "help":
            print(HELP)
            continue

        if command == "reset":
            scanner.reset()
            results = {}
            current_value = None
            print("Scan state reset.")
            continue

        if command == "show":
            print_results(results)
            continue

        if command == "save":
            out_dir = Path("sessions")
            out_dir.mkdir(parents=True, exist_ok=True)
            stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            path = out_dir / f"session-{stamp}.json"
            summary = SessionSummary(
                host=ps4.host,
                pid=pid,
                process_name=pname,
                current_value=current_value,
                candidate_count=len(results),
                sample=make_sample(results),
                updated_at=datetime.now(timezone.utc).isoformat(),
            )
            path.write_text(json.dumps(asdict(summary), indent=2), encoding="utf-8")
            print(f"Saved: {path}")
            continue

        if command in {"first", "refine"}:
            if len(parts) != 2:
                print(f"Usage: {command} <integer>")
                continue

            try:
                value = int(parts[1])
            except ValueError:
                print("Value must be an integer.")
                continue

            if command == "first":
                scanner.reset()
            elif not scanner.initial:
                print("No active scan. Use 'first <value>' first.")
                continue

            print(f"Scanning int32 exact value {value}...")
            results = await scanner.query().int32().exact(value).execute()
            current_value = value
            print_results(results)

            if len(results) == 1:
                address = next(iter(results))
                print(f"\nStrong candidate: 0x{address:016X}")
            elif 1 < len(results) <= 10:
                print("\nCandidate set is small. Change the in-game value again and refine.")
            elif not results:
                print("\nNo matches survived. Reset and try again; the game may use another numeric type.")
            continue

        print("Unknown command. Type 'help'.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Read-only PS4 Career Diagnostic")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--host", help="PS4 IP address")
    group.add_argument("--discover", action="store_true", help="discover a PS4 on the LAN")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    try:
        asyncio.run(run(args))
    except Exception as exc:
        print(f"ERROR: {exc}")
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
