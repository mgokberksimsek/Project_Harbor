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

    def test_reassembles_chunked_milestone_with_pipes_and_unicode(self) -> None:
        payload = {
            "event_id": "run-1:99",
            "run_id": "run-1",
            "ship_upgrade_state": "Yakamoz: S2/C1 | Rüzgâr: S1/C0",
            "port_details": [{"port_name": "İzmir"}] * 20,
        }
        serialized = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        pieces = [serialized[:100], serialized[100:300], serialized[300:]]
        assembler = MODULE.PlaytestChunkAssembler()
        record = None
        for index in [1, 0, 2]:
            line = (
                "09-11 I/godot: PH_PLAYTEST_CHUNK|run-1:99|"
                f"{index}|{len(pieces)}|MILESTONE|COMPANY_LEVEL_8|{pieces[index]}"
            )
            chunk = MODULE.parse_playtest_chunk(line)
            self.assertIsNotNone(chunk)
            record = assembler.append(chunk)
        self.assertIsNotNone(record)
        self.assertEqual(record.category, "MILESTONE")
        self.assertEqual(record.name, "COMPANY_LEVEL_8")
        self.assertEqual(record.payload, payload)

    def test_offer_table_and_level_event_summary_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            session = MODULE.PlaytestSession(
                Path(temporary_directory),
                "run-1",
                "2026-09-11 18:30:00",
            )
            presented = self._record(
                "EVENT",
                "MISSION_OFFER_PRESENTED",
                "run-1:1",
                active_sec=30,
                offer_batch_id="run-1:offers:1",
                offer_id="offer-1",
                ship_id="starter_1",
                ship_name="Yakamoz",
                model="starter_freighter",
                origin_port="samsun",
                pickup_type="local",
                pickup_is_local=True,
                pickup_port="samsun",
                destination_port="istanbul",
                final_destination_port="trabzon",
                contract_ports=["samsun", "istanbul", "trabzon"],
                cargo_type="containers",
                cargo_amount=2,
                gross_reward=500,
                operating_cost=50,
                net_reward=450,
                mission_duration=60.0,
                net_per_min=450.0,
                is_large_contract=True,
                is_selected=False,
            )
            selected_values = presented.payload.copy()
            selected_values.pop("event_id", None)
            selected_values["is_selected"] = True
            selected = self._record(
                "EVENT",
                "MISSION_OFFER_SELECTED",
                "run-1:2",
                **selected_values,
            )
            level_event = self._record(
                "EVENT",
                "COMPANY_LEVEL_CHANGED",
                "run-1:3",
                active_sec=120,
                company_level=8,
            )
            self.assertTrue(session.append(presented))
            self.assertTrue(session.append(selected))
            self.assertTrue(session.append(level_event))
            offer_rows = self._rows(session.mission_offers_path)
            self.assertEqual(len(offer_rows), 2)
            self.assertEqual(offer_rows[0]["pickup_type"], "local")
            self.assertEqual(offer_rows[0]["net_per_min"], "450.0")
            self.assertEqual(offer_rows[1]["offer_event"], "selected")
            summary = session.summary_path.read_text(encoding="utf-8")
            self.assertIn("Level 8 aktif süresi: 00:02:00", summary)
            self.assertIn("COMPANY_LEVEL_CHANGED event fallback", summary)

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
