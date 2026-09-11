from __future__ import annotations

import csv
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "progression_playtest_logger.py"
SPEC = importlib.util.spec_from_file_location("progression_playtest_logger", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class ProgressionPlaytestWatcherTest(unittest.TestCase):
    def test_parse_decorated_logcat_line(self) -> None:
        line = (
            "09-11 18:30:00.000 I/godot(123): "
            'PH_PLAYTEST|EVENT|SHIP_PURCHASED|{"run_id":"run-1","cost":500}'
        )
        record = MODULE.parse_playtest_line(line)
        self.assertIsNotNone(record)
        self.assertEqual(record.category, "EVENT")
        self.assertEqual(record.name, "SHIP_PURCHASED")
        self.assertEqual(record.payload["cost"], 500)
        self.assertIsNone(MODULE.parse_playtest_line("ordinary Godot output"))
        self.assertIsNone(
            MODULE.parse_playtest_line("PH_PLAYTEST|EVENT|BROKEN|{not json}")
        )

    def test_csv_routing_summary_and_restart_deduplication(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            output_root = Path(temporary_directory)
            session = MODULE.PlaytestSession(output_root, "run-1", "2026-09-11 18:30:00")
            records = [
                self._record(
                    "MILESTONE",
                    "GAME_STARTED",
                    "run-1:1",
                    active_sec=0,
                    cash=500,
                    company_value=400,
                    company_level=1,
                    fleet_size=0,
                    fleet_models={},
                    ship_upgrade_state="",
                    port_levels="Mersin:L1 | İzmir:L1",
                    missions_completed=0,
                    large_contracts=0,
                    unlocked_ports=["mersin", "izmir"],
                ),
                self._record(
                    "EVENT",
                    "SHIP_PURCHASED",
                    "run-1:2",
                    active_sec=10,
                    ship_id="starter_1",
                    ship_name="Orion",
                    model="starter_freighter",
                    cost=500,
                ),
                self._record(
                    "EVENT",
                    "SHIP_SPEED_UPGRADED",
                    "run-1:3",
                    active_sec=20,
                    ship_id="starter_1",
                    ship_name="Orion",
                    model="starter_freighter",
                    previous_level=0,
                    new_level=1,
                    previous_value=120.0,
                    new_value=138.0,
                    cost=250,
                    company_value_gain=100,
                ),
                self._record(
                    "EVENT",
                    "PORT_UPGRADED",
                    "run-1:4",
                    active_sec=30,
                    port_id="antalya",
                    port_name="Antalya",
                    previous_level=1,
                    new_level=2,
                    cost=700,
                    company_value_gain=300,
                    previous_reward_modifier=1.0,
                    new_reward_modifier=1.08,
                    previous_handling_time=3.0,
                    new_handling_time=2.4,
                    previous_berths=2,
                    new_berths=4,
                ),
                self._record(
                    "EVENT",
                    "MISSION_COMPLETED",
                    "run-1:5",
                    active_sec=60,
                    ship_id="starter_1",
                    ship_name="Orion",
                    model="starter_freighter",
                    gross_reward=150,
                    operating_cost=25,
                    net_reward=125,
                ),
            ]
            for record in records:
                self.assertTrue(session.append(record))

            milestone_rows = self._rows(session.milestones_path)
            self.assertEqual(milestone_rows[0]["active_time"], "00:00:00")
            ship_upgrade_rows = self._rows(session.ship_upgrades_path)
            self.assertEqual(len(ship_upgrade_rows), 1)
            self.assertEqual(ship_upgrade_rows[0]["active_time"], "00:00:20")
            self.assertEqual(len(self._rows(session.port_upgrades_path)), 1)
            summary = session.summary_path.read_text(encoding="utf-8")
            self.assertIn("Toplam net gelir: 125 ₺", summary)
            self.assertIn("Orion — 750 ₺", summary)

            restarted = MODULE.PlaytestSession(output_root, "run-1")
            self.assertEqual(restarted.path, session.path)
            self.assertFalse(restarted.append(records[2]))
            self.assertEqual(len(self._rows(restarted.events_path)), 4)
            restarted.add_player_note("bulk carrier çok geç geldi", 61.0, 90.0)
            event_rows = self._rows(restarted.events_path)
            self.assertEqual(event_rows[-1]["event_type"], "PLAYER_NOTE")
            details = json.loads(event_rows[-1]["details"])
            self.assertEqual(details["note"], "bulk carrier çok geç geldi")

    @staticmethod
    def _record(category: str, name: str, event_id: str, **values: object):
        payload = {
            "event_id": event_id,
            "run_id": "run-1",
            "timestamp": "2026-09-11 18:30:00",
            "active_sec": 0,
            "elapsed_sec": 0,
        }
        payload.update(values)
        return MODULE.PlaytestRecord(category, name, payload)

    @staticmethod
    def _rows(path: Path) -> list[dict[str, str]]:
        with path.open("r", newline="", encoding="utf-8-sig") as handle:
            return list(csv.DictReader(handle))


if __name__ == "__main__":
    unittest.main()
