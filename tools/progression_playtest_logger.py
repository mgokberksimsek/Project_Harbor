#!/usr/bin/env python3
"""Listen for Project Harbor debug playtest records over ADB/logcat.

The tool is intentionally standalone and uses only Python's standard library.
It never sends gameplay commands to the device; it only verifies ADB, reads
logcat, and writes local CSV/Markdown reports.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import queue
import re
import shutil
import subprocess
import sys
import threading
import time
import uuid
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable


LOG_PREFIX = "PH_PLAYTEST|"
DEFAULT_PACKAGE = "com.gokberksimsek.projectharbor"

MILESTONE_COLUMNS = [
    "event_id",
    "run_id",
    "timestamp",
    "milestone",
    "active_time",
    "elapsed_time",
    "active_sec",
    "elapsed_sec",
    "cash",
    "company_value",
    "peak_company_value",
    "company_level",
    "fleet_size",
    "fleet_models",
    "ship_upgrade_state",
    "ship_upgrade_details",
    "port_levels",
    "port_details",
    "missions_completed",
    "large_contracts",
    "total_net_mission_earnings",
    "unlocked_ports",
    "ship_purchase_spend",
    "port_unlock_spend",
    "ship_speed_upgrade_spend",
    "ship_capacity_upgrade_spend",
    "total_ship_upgrade_spend",
    "port_upgrade_spend",
    "automation_spend",
    "automation_unlocked_count",
    "automation_enabled_count",
]

EVENT_COLUMNS = [
    "event_id",
    "run_id",
    "timestamp",
    "active_time",
    "elapsed_time",
    "active_sec",
    "elapsed_sec",
    "event_type",
    "ship_id",
    "ship_name",
    "model",
    "port_id",
    "port_name",
    "pickup_port",
    "delivery_port",
    "cargo_type",
    "cargo_amount",
    "gross_reward",
    "operating_cost",
    "net_reward",
    "mission_duration",
    "cost",
    "company_value_gain",
    "cash",
    "company_value",
    "company_level",
    "details",
]

SHIP_UPGRADE_COLUMNS = [
    "event_id",
    "run_id",
    "timestamp",
    "active_time",
    "ship_id",
    "ship_name",
    "model",
    "upgrade_type",
    "previous_level",
    "new_level",
    "cost",
    "previous_value",
    "new_value",
    "company_value_gain",
]

PORT_UPGRADE_COLUMNS = [
    "event_id",
    "run_id",
    "timestamp",
    "active_time",
    "port_id",
    "port_name",
    "previous_level",
    "new_level",
    "cost",
    "company_value_gain",
    "previous_reward_modifier",
    "new_reward_modifier",
    "previous_handling_time",
    "new_handling_time",
    "previous_berths",
    "new_berths",
]


@dataclass(frozen=True)
class PlaytestRecord:
    category: str
    name: str
    payload: dict[str, Any]


def parse_playtest_line(line: str) -> PlaytestRecord | None:
    """Extract one PH_PLAYTEST record from a raw or decorated logcat line."""
    marker_index = line.find(LOG_PREFIX)
    if marker_index < 0:
        return None
    structured = line[marker_index:].strip()
    parts = structured.split("|", 3)
    if len(parts) != 4 or parts[0] != "PH_PLAYTEST":
        return None
    try:
        payload = json.loads(parts[3])
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, dict):
        return None
    return PlaytestRecord(parts[1], parts[2], payload)


def format_duration(seconds: Any) -> str:
    try:
        total_seconds = max(int(round(float(seconds))), 0)
    except (TypeError, ValueError):
        return ""
    hours, remainder = divmod(total_seconds, 3600)
    minutes, secs = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def _compact_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def _join_values(value: Any) -> str:
    if isinstance(value, list):
        return " | ".join(str(item) for item in value)
    if isinstance(value, dict):
        return " | ".join(
            f"{key}:{value[key]}" for key in sorted(value, key=str)
        )
    return "" if value is None else str(value)


def _float(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _int(value: Any) -> int:
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return 0


class PlaytestSession:
    """Append-only report writer for one Godot run_id."""

    def __init__(self, output_root: Path, run_id: str, timestamp: str = "") -> None:
        self.output_root = output_root
        self.run_id = run_id
        self.path = self._find_or_create_path(timestamp)
        self.metadata_path = self.path / ".playtest_session.json"
        self.milestones_path = self.path / "milestones.csv"
        self.events_path = self.path / "events.csv"
        self.ship_upgrades_path = self.path / "ship_upgrades.csv"
        self.port_upgrades_path = self.path / "port_upgrades.csv"
        self.summary_path = self.path / "summary.md"
        self._ensure_csv(self.milestones_path, MILESTONE_COLUMNS)
        self._ensure_csv(self.events_path, EVENT_COLUMNS)
        self._ensure_csv(self.ship_upgrades_path, SHIP_UPGRADE_COLUMNS)
        self._ensure_csv(self.port_upgrades_path, PORT_UPGRADE_COLUMNS)
        self.seen_event_ids = self._load_seen_event_ids()
        latest_active, latest_elapsed = self._latest_csv_times()
        self._live_active_base = latest_active
        self._live_elapsed_base = latest_elapsed
        self._live_observed_monotonic = time.monotonic()
        self._live_foreground = True
        self._write_metadata()
        self.update_summary()

    def _find_or_create_path(self, timestamp: str) -> Path:
        self.output_root.mkdir(parents=True, exist_ok=True)
        for candidate in sorted(self.output_root.iterdir()):
            metadata_path = candidate / ".playtest_session.json"
            if not metadata_path.is_file():
                continue
            try:
                metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            if metadata.get("run_id") == self.run_id:
                return candidate

        directory_name = _safe_session_timestamp(timestamp)
        candidate = self.output_root / directory_name
        suffix = 2
        while candidate.exists():
            candidate = self.output_root / f"{directory_name}_{suffix}"
            suffix += 1
        candidate.mkdir(parents=True)
        return candidate

    @staticmethod
    def _ensure_csv(path: Path, columns: list[str]) -> None:
        if path.exists() and path.stat().st_size > 0:
            return
        with path.open("w", newline="", encoding="utf-8-sig") as handle:
            csv.DictWriter(handle, fieldnames=columns).writeheader()

    def _load_seen_event_ids(self) -> set[str]:
        seen: set[str] = set()
        for path in (self.milestones_path, self.events_path):
            try:
                with path.open("r", newline="", encoding="utf-8-sig") as handle:
                    for row in csv.DictReader(handle):
                        event_id = row.get("event_id", "")
                        if event_id:
                            seen.add(event_id)
            except OSError:
                continue
        return seen

    def append(self, record: PlaytestRecord) -> bool:
        self._observe_live_clock(record)
        if record.category == "CONTROL":
            self._write_metadata(record.payload.get("timestamp", ""))
            return False

        event_id = str(record.payload.get("event_id", ""))
        if event_id and event_id in self.seen_event_ids:
            return False

        if record.category == "MILESTONE":
            self._append_csv(
                self.milestones_path,
                MILESTONE_COLUMNS,
                self._milestone_row(record),
            )
        elif record.category == "EVENT":
            self._append_csv(
                self.events_path,
                EVENT_COLUMNS,
                self._event_row(record),
            )
            if record.name in {"SHIP_SPEED_UPGRADED", "SHIP_CAPACITY_UPGRADED"}:
                self._append_csv(
                    self.ship_upgrades_path,
                    SHIP_UPGRADE_COLUMNS,
                    self._ship_upgrade_row(record),
                )
            elif record.name == "PORT_UPGRADED":
                self._append_csv(
                    self.port_upgrades_path,
                    PORT_UPGRADE_COLUMNS,
                    self._port_upgrade_row(record),
                )
        else:
            return False

        if event_id:
            self.seen_event_ids.add(event_id)
        self._write_metadata(record.payload.get("timestamp", ""))
        self.update_summary()
        return True

    @staticmethod
    def _append_csv(path: Path, columns: list[str], row: dict[str, Any]) -> None:
        with path.open("a", newline="", encoding="utf-8-sig") as handle:
            writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
            writer.writerow({column: row.get(column, "") for column in columns})

    @staticmethod
    def _base_row(payload: dict[str, Any]) -> dict[str, Any]:
        return {
            "event_id": payload.get("event_id", ""),
            "run_id": payload.get("run_id", ""),
            "timestamp": payload.get("timestamp", ""),
            "active_time": format_duration(payload.get("active_sec")),
            "elapsed_time": format_duration(payload.get("elapsed_sec")),
            "active_sec": payload.get("active_sec", ""),
            "elapsed_sec": payload.get("elapsed_sec", ""),
        }

    def _milestone_row(self, record: PlaytestRecord) -> dict[str, Any]:
        payload = record.payload
        row = {column: payload.get(column, "") for column in MILESTONE_COLUMNS}
        row.update(self._base_row(payload))
        row.update(
            {
                "milestone": record.name,
                "fleet_models": _join_values(payload.get("fleet_models", {})),
                "ship_upgrade_details": _compact_json(
                    payload.get("ship_upgrade_details", [])
                ),
                "port_details": _compact_json(payload.get("port_details", [])),
                "unlocked_ports": _join_values(payload.get("unlocked_ports", [])),
            }
        )
        return row

    def _event_row(self, record: PlaytestRecord) -> dict[str, Any]:
        payload = record.payload
        row = {column: payload.get(column, "") for column in EVENT_COLUMNS}
        row.update(self._base_row(payload))
        row["event_type"] = record.name
        row["details"] = _compact_json(payload)
        return row

    def _ship_upgrade_row(self, record: PlaytestRecord) -> dict[str, Any]:
        payload = record.payload
        row = {
            column: payload.get(column, "") for column in SHIP_UPGRADE_COLUMNS
        }
        row.update(self._base_row(payload))
        row["upgrade_type"] = (
            "speed" if record.name == "SHIP_SPEED_UPGRADED" else "capacity"
        )
        return row

    def _port_upgrade_row(self, record: PlaytestRecord) -> dict[str, Any]:
        payload = record.payload
        row = {
            column: payload.get(column, "") for column in PORT_UPGRADE_COLUMNS
        }
        row.update(self._base_row(payload))
        return row

    def add_player_note(self, note: str, active_sec: float, elapsed_sec: float) -> None:
        now = datetime.now().astimezone().isoformat(timespec="seconds")
        payload = {
            "event_id": f"PLAYER_NOTE:{uuid.uuid4()}",
            "run_id": self.run_id,
            "timestamp": now,
            "active_sec": round(max(active_sec, 0.0), 3),
            "elapsed_sec": round(max(elapsed_sec, 0.0), 3),
            "note": note,
        }
        self.append(PlaytestRecord("EVENT", "PLAYER_NOTE", payload))

    def latest_times(self) -> tuple[float, float]:
        elapsed_since_observation = max(
            time.monotonic() - self._live_observed_monotonic, 0.0
        )
        active_sec = self._live_active_base
        if self._live_foreground:
            active_sec += elapsed_since_observation
        return active_sec, self._live_elapsed_base + elapsed_since_observation

    def _latest_csv_times(self) -> tuple[float, float]:
        active_sec = 0.0
        elapsed_sec = 0.0
        for path in (self.events_path, self.milestones_path):
            for row in _read_csv(path):
                active_sec = max(active_sec, _float(row.get("active_sec")))
                elapsed_sec = max(elapsed_sec, _float(row.get("elapsed_sec")))
        return active_sec, elapsed_sec

    def _observe_live_clock(self, record: PlaytestRecord) -> None:
        payload = record.payload
        self._live_active_base = _float(payload.get("active_sec"))
        self._live_elapsed_base = _float(payload.get("elapsed_sec"))
        self._live_observed_monotonic = time.monotonic()
        if record.category == "CONTROL":
            if record.name == "APP_PAUSED":
                self._live_foreground = False
            elif record.name in {"APP_RESUMED", "RUN_STARTED", "RUN_RESUMED"}:
                self._live_foreground = True

    def update_summary(self) -> None:
        milestones = list(_read_csv(self.milestones_path))
        events = list(_read_csv(self.events_path))
        mission_events = [
            row
            for row in events
            if row.get("event_type")
            in {"MISSION_COMPLETED", "LARGE_CONTRACT_COMPLETED"}
        ]
        purchase_events = [
            row for row in events if row.get("event_type") == "SHIP_PURCHASED"
        ]

        total_net = sum(_int(row.get("net_reward")) for row in mission_events)
        latest_active_sec = max(
            [_float(row.get("active_sec")) for row in events + milestones] or [0.0]
        )
        spend_by_type = {
            event_type: sum(
                _int(row.get("cost"))
                for row in events
                if row.get("event_type") == event_type
            )
            for event_type in (
                "SHIP_PURCHASED",
                "PORT_UNLOCKED",
                "SHIP_SPEED_UPGRADED",
                "SHIP_CAPACITY_UPGRADED",
                "PORT_UPGRADED",
                "AUTOMATION_UNLOCKED",
            )
        }
        ship_investments: dict[str, int] = {}
        ship_labels: dict[str, str] = {}
        port_investments: dict[str, int] = {}
        for row in events:
            event_type = row.get("event_type", "")
            cost = _int(row.get("cost"))
            if event_type in {
                "SHIP_PURCHASED",
                "SHIP_SPEED_UPGRADED",
                "SHIP_CAPACITY_UPGRADED",
                "AUTOMATION_UNLOCKED",
            }:
                ship_key = row.get("ship_id") or row.get("ship_name") or ""
                if ship_key:
                    ship_investments[ship_key] = ship_investments.get(ship_key, 0) + cost
                    ship_labels[ship_key] = row.get("ship_name") or ship_key
            if event_type in {"PORT_UNLOCKED", "PORT_UPGRADED"}:
                port_key = row.get("port_name") or row.get("port_id") or ""
                if port_key:
                    port_investments[port_key] = port_investments.get(port_key, 0) + cost

        level_8_row = next(
            (row for row in milestones if row.get("milestone") == "COMPANY_LEVEL_8"),
            None,
        )
        average_per_active_minute = (
            total_net / (latest_active_sec / 60.0) if latest_active_sec > 0.0 else 0.0
        )
        purchased_ships = [
            f"{row.get('ship_name') or row.get('ship_id')} ({row.get('model')})"
            for row in purchase_events
        ]

        lines = [
            "# Project Harbor Progression Playtest",
            "",
            f"Run ID: `{self.run_id}`  ",
            f"Son güncelleme: {datetime.now().astimezone().isoformat(timespec='seconds')}",
            "",
            "| Milestone | Aktif Süre | Cash | CV | Level | Filo | Ship Upgrades | Port Levels | Görev | Büyük Kontrat |",
            "| --- | ---: | ---: | ---: | ---: | --- | --- | --- | ---: | ---: |",
        ]
        for row in milestones:
            lines.append(
                "| {milestone} | {active_time} | {cash} | {company_value} | "
                "{company_level} | {fleet} | {ships} | {ports} | {missions} | "
                "{contracts} |".format(
                    milestone=_markdown_cell(row.get("milestone", "")),
                    active_time=row.get("active_time", ""),
                    cash=row.get("cash", ""),
                    company_value=row.get("company_value", ""),
                    company_level=row.get("company_level", ""),
                    fleet=_markdown_cell(row.get("fleet_models", "")),
                    ships=_markdown_cell(row.get("ship_upgrade_state", "")),
                    ports=_markdown_cell(row.get("port_levels", "")),
                    missions=row.get("missions_completed", ""),
                    contracts=row.get("large_contracts", ""),
                )
            )

        lines.extend(
            [
                "",
                "## Koşu özeti",
                "",
                f"- Level 8 aktif süresi: {level_8_row.get('active_time') if level_8_row else 'henüz ulaşılmadı'}",
                f"- Toplam mission: {len(mission_events)}",
                f"- Toplam normal mission: {sum(row.get('event_type') == 'MISSION_COMPLETED' for row in mission_events)}",
                f"- Toplam Large Contract: {sum(row.get('event_type') == 'LARGE_CONTRACT_COMPLETED' for row in mission_events)}",
                f"- Toplam net gelir: {total_net} ₺",
                f"- Aktif dakika başına ortalama net gelir: {average_per_active_minute:.2f} ₺",
                f"- Satın alınan gemiler: {', '.join(purchased_ships) if purchased_ships else '—'}",
                f"- Gemi satın alma harcaması: {spend_by_type['SHIP_PURCHASED']} ₺",
                f"- Ship speed upgrade harcaması: {spend_by_type['SHIP_SPEED_UPGRADED']} ₺",
                f"- Ship capacity upgrade harcaması: {spend_by_type['SHIP_CAPACITY_UPGRADED']} ₺",
                f"- Port unlock harcaması: {spend_by_type['PORT_UNLOCKED']} ₺",
                f"- Port upgrade harcaması: {spend_by_type['PORT_UPGRADED']} ₺",
                f"- Automation harcaması: {spend_by_type['AUTOMATION_UNLOCKED']} ₺",
                f"- En fazla yatırım yapılan gemi: {_largest_investment(ship_investments, ship_labels)}",
                f"- En fazla yatırım yapılan liman: {_largest_investment(port_investments)}",
                "",
                "## Milestone arası aktif süreler",
                "",
            ]
        )
        if len(milestones) < 2:
            lines.append("Henüz yeterli milestone yok.")
        else:
            previous = milestones[0]
            for current in milestones[1:]:
                interval = _float(current.get("active_sec")) - _float(
                    previous.get("active_sec")
                )
                lines.append(
                    f"- {previous.get('milestone')} → {current.get('milestone')}: "
                    f"{format_duration(max(interval, 0.0))}"
                )
                previous = current
        self.summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def _write_metadata(self, timestamp: Any = "") -> None:
        metadata = {
            "run_id": self.run_id,
            "directory": self.path.name,
            "last_record_timestamp": timestamp,
            "updated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        }
        self.metadata_path.write_text(
            json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


def _safe_session_timestamp(timestamp: str) -> str:
    if timestamp:
        try:
            parsed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
            return parsed.astimezone().strftime("%Y-%m-%d_%H-%M-%S")
        except ValueError:
            pass
    return datetime.now().astimezone().strftime("%Y-%m-%d_%H-%M-%S")


def _read_csv(path: Path) -> Iterable[dict[str, str]]:
    try:
        with path.open("r", newline="", encoding="utf-8-sig") as handle:
            yield from csv.DictReader(handle)
    except OSError:
        return


def _markdown_cell(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def _largest_investment(
    investments: dict[str, int], labels: dict[str, str] | None = None
) -> str:
    if not investments:
        return "—"
    name, amount = max(investments.items(), key=lambda item: (item[1], item[0]))
    display_name = labels.get(name, name) if labels else name
    return f"{display_name} — {amount} ₺"


def _adb_command(adb: str, serial: str, *arguments: str) -> list[str]:
    command = [adb]
    if serial:
        command.extend(["-s", serial])
    command.extend(arguments)
    return command


def discover_adb() -> str:
    """Find ADB from PATH, common SDK env vars, or Godot editor settings."""
    path_adb = shutil.which("adb")
    if path_adb:
        return path_adb

    candidates: list[Path] = []
    executable_name = "adb.exe" if os.name == "nt" else "adb"
    for environment_name in ("ANDROID_SDK_ROOT", "ANDROID_HOME"):
        sdk_root = os.environ.get(environment_name, "")
        if sdk_root:
            candidates.append(Path(sdk_root) / "platform-tools" / executable_name)
    local_app_data = os.environ.get("LOCALAPPDATA", "")
    if local_app_data:
        candidates.append(
            Path(local_app_data) / "Android" / "Sdk" / "platform-tools" / executable_name
        )

    app_data = os.environ.get("APPDATA", "")
    if app_data:
        settings_directory = Path(app_data) / "Godot"
        try:
            settings_files = sorted(
                settings_directory.glob("editor_settings-*.tres"), reverse=True
            )
        except OSError:
            settings_files = []
        sdk_pattern = re.compile(r'^export/android/android_sdk_path\s*=\s*(".*")$')
        for settings_path in settings_files:
            try:
                settings_text = settings_path.read_text(encoding="utf-8")
            except OSError:
                continue
            for line in settings_text.splitlines():
                match = sdk_pattern.match(line.strip())
                if not match:
                    continue
                try:
                    godot_sdk_path = json.loads(match.group(1))
                except json.JSONDecodeError:
                    continue
                candidates.append(
                    Path(godot_sdk_path) / "platform-tools" / executable_name
                )
                break

    for candidate in candidates:
        try:
            if candidate.is_file():
                return str(candidate)
        except OSError:
            continue
    return "adb"


def find_device(adb: str, requested_serial: str) -> str:
    try:
        result = subprocess.run(
            [adb, "devices"],
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError as error:
        raise RuntimeError(
            f"ADB bulunamadı: {adb}. --adb ile adb.exe yolunu verin."
        ) from error
    except subprocess.CalledProcessError as error:
        raise RuntimeError(f"adb devices başarısız: {error.stderr.strip()}") from error

    devices: list[str] = []
    unauthorized: list[str] = []
    for line in result.stdout.splitlines()[1:]:
        fields = line.split()
        if len(fields) < 2:
            continue
        if fields[1] == "device":
            devices.append(fields[0])
        elif fields[1] == "unauthorized":
            unauthorized.append(fields[0])
    if requested_serial:
        if requested_serial not in devices:
            raise RuntimeError(f"ADB cihazı hazır değil: {requested_serial}")
        return requested_serial
    if len(devices) == 1:
        return devices[0]
    if not devices and unauthorized:
        raise RuntimeError(
            "Cihaz unauthorized. Telefonda USB debugging anahtarını onaylayın."
        )
    if not devices:
        raise RuntimeError("ADB üzerinden bağlı ve yetkili Android cihaz bulunamadı.")
    raise RuntimeError(
        "Birden fazla cihaz bağlı; --serial SERIAL ile birini seçin: "
        + ", ".join(devices)
    )


def _stream_reader(stream: Any, output_queue: queue.Queue[tuple[str, str]]) -> None:
    for line in iter(stream.readline, ""):
        output_queue.put(("log", line))
    output_queue.put(("closed", ""))


def _note_reader(output_queue: queue.Queue[tuple[str, str]]) -> None:
    while True:
        try:
            line = input()
        except EOFError:
            return
        output_queue.put(("input", line))


def run_watcher(args: argparse.Namespace) -> int:
    serial = find_device(args.adb, args.serial)
    print(f"ADB cihazı hazır: {serial}")
    pid_result = subprocess.run(
        _adb_command(args.adb, serial, "shell", "pidof", args.package),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    pid = pid_result.stdout.strip()
    if pid:
        print(f"{args.package} çalışıyor (PID {pid}).")
    else:
        print(f"{args.package} henüz çalışmıyor; logcat dinleniyor.")

    process = subprocess.Popen(
        _adb_command(args.adb, serial, "logcat", "-v", "raw"),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )
    assert process.stdout is not None
    incoming: queue.Queue[tuple[str, str]] = queue.Queue()
    threading.Thread(
        target=_stream_reader,
        args=(process.stdout, incoming),
        daemon=True,
    ).start()
    if not args.no_notes and sys.stdin.isatty():
        threading.Thread(target=_note_reader, args=(incoming,), daemon=True).start()
        print("Manuel not: n <not>. Bitirmek için Ctrl+C.")
    else:
        print("Bitirmek için Ctrl+C.")

    output_root = Path(args.output_root).resolve()
    sessions: dict[str, PlaytestSession] = {}
    current_session: PlaytestSession | None = None
    try:
        while True:
            try:
                item_type, value = incoming.get(timeout=0.25)
            except queue.Empty:
                if process.poll() is not None:
                    break
                continue
            if item_type == "closed":
                break
            if item_type == "input":
                stripped = value.strip()
                if not stripped:
                    continue
                if not stripped.startswith("n "):
                    print("Not biçimi: n <not>")
                    continue
                if current_session is None:
                    print("Henüz bir PH_PLAYTEST run kaydı alınmadı; not eklenmedi.")
                    continue
                active_sec, elapsed_sec = current_session.latest_times()
                current_session.add_player_note(
                    stripped[2:].strip(), active_sec, elapsed_sec
                )
                print(f"PLAYER_NOTE kaydedildi: {stripped[2:].strip()}")
                continue

            record = parse_playtest_line(value)
            if record is None:
                continue
            run_id = str(record.payload.get("run_id", ""))
            if not run_id:
                continue
            if run_id not in sessions:
                sessions[run_id] = PlaytestSession(
                    output_root,
                    run_id,
                    str(record.payload.get("timestamp", "")),
                )
                print(f"Playtest çıktısı: {sessions[run_id].path}")
            current_session = sessions[run_id]
            if current_session.append(record):
                print(
                    f"[{format_duration(record.payload.get('active_sec'))}] "
                    f"{record.category} {record.name}"
                )
    except KeyboardInterrupt:
        print("\nWatcher durduruldu.")
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
        for session in sessions.values():
            session.update_summary()
    return 0


def build_parser() -> argparse.ArgumentParser:
    repository_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(
        description="Project Harbor PH_PLAYTEST logcat watcher"
    )
    parser.add_argument(
        "--adb",
        default=discover_adb(),
        help="adb executable (default: PATH, Android SDK env, or Godot settings)",
    )
    parser.add_argument("--serial", default="", help="ADB device serial")
    parser.add_argument("--package", default=DEFAULT_PACKAGE)
    parser.add_argument(
        "--output-root",
        default=str(repository_root / "playtests"),
        help="Timestamped playtest directories are created here",
    )
    parser.add_argument(
        "--no-notes",
        action="store_true",
        help="Disable interactive n <note> input",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        return run_watcher(args)
    except RuntimeError as error:
        print(f"Hata: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
