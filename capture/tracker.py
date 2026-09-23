"""WIRKLICHT capture entrypoint.

Reads camera frames (or synthetic data with --sim), tracks bodies, extracts
features and streams them locally to the Godot renderer over UDP.

Nothing is stored; only abstract numbers leave this process (to 127.0.0.1).
"""

from __future__ import annotations

import argparse
import json
import os
import time

from .features import BodyTracker, crowd_energy
from .sim import LIFECYCLE_SCENARIOS
from .net import UdpJsonSender
from .control import SimControlServer

_CONFIG_PATH = os.path.join(os.path.dirname(__file__), "..", "config", "config.json")


def load_config(path: str = _CONFIG_PATH) -> dict:
    # Windows PowerShell 5.1 may have written an existing local config with a
    # UTF-8 BOM. utf-8-sig accepts both BOM and BOM-less UTF-8.
    with open(os.path.abspath(path), "r", encoding="utf-8-sig") as fh:
        return json.load(fh)


def build_frame(bodies, pairs, energy, t, departures=None, temporarily_missing=None) -> dict:
    return {
        "t": round(t, 3),
        "bodies": bodies,
        "pairs": pairs,
        "crowd": {"count": len(bodies), "energy": energy},
        "events": {"departures": departures or []},
        "tracking": {"temporarily_missing": temporarily_missing or []},
    }


def _make_body_tracker(fcfg: dict) -> BodyTracker:
    return BodyTracker(
        max_dist=fcfg["track_max_dist"],
        timeout=fcfg["track_timeout"],
        intensity_scale=fcfg["intensity_scale"],
        smoothing=fcfg["intensity_smoothing"],
        grace_period=fcfg.get("track_grace_period", fcfg["track_timeout"]),
        departure_edge_margin=fcfg.get("departure_edge_margin", 0.08),
        departure_min_speed=fcfg.get("departure_min_speed", 0.05),
        confirmation_frames=fcfg.get("track_confirmation_frames", 1),
        stillness_speed_threshold=fcfg.get("stillness_speed_threshold", 0.08),
        stillness_rise_seconds=fcfg.get("stillness_rise_seconds", 2.5),
        stillness_fall_seconds=fcfg.get("stillness_fall_seconds", 0.8),
    )


SIM_SCENARIO_CHOICES = ("phase44", *LIFECYCLE_SCENARIOS)


def run_sim(cfg: dict, scenario: str = "phase44") -> None:
    from .sim import make_simulation_persons

    fcfg = cfg["features"]
    tracker = _make_body_tracker(fcfg)
    sender = UdpJsonSender(cfg["network"]["host"], cfg["network"]["port"])
    # Debug-only control channel (loopback, port+1) lets the renderer's debug
    # overlay switch the scenario live. Failure to bind is not fatal: the
    # simulator simply runs with the start scenario.
    control = None
    try:
        control = SimControlServer(cfg["network"]["port"] + 1, SIM_SCENARIO_CHOICES)
    except OSError as exc:
        print(f"Simulations-Steuerkanal nicht verfügbar ({exc}); Szenario bleibt fest.")
    print("Simulator läuft (Strg+C zum Beenden) ...")
    start = time.time()
    # Two clocks on purpose. `t` (sent to the renderer) is a monotonic wall
    # clock; the renderer rejects any packet whose timestamp moves backwards.
    # `scenario_time` only drives the scenario phase, so a switch replays the
    # new scenario from its beginning without ever rewinding `t`.
    scenario_start = start
    try:
        while True:
            now = time.time()
            if control is not None:
                new_scenario = control.poll()
                if new_scenario is not None and new_scenario != scenario:
                    scenario = new_scenario
                    scenario_start = now
                    print(f"Simulations-Szenario: {scenario}")
            t = now - start
            scenario_time = now - scenario_start
            persons = make_simulation_persons(scenario, scenario_time)
            bodies = tracker.update(persons, t)
            pairs = tracker.compute_pairs(fcfg["proximity_threshold"])
            sender.send(
                build_frame(
                    bodies, pairs, crowd_energy(bodies), t, tracker.take_departures(),
                    tracker.temporarily_missing_ids(),
                )
            )
            time.sleep(1.0 / 60.0)
    except KeyboardInterrupt:
        pass
    finally:
        if control is not None:
            control.close()
        sender.close()


def run_camera(cfg: dict) -> None:
    import cv2

    from .camera import Camera, choose_camera, list_cameras
    from .pose import PoseTracker

    fcfg = cfg["features"]
    ccfg = cfg["camera"]
    pcfg = cfg["pose"]

    selected = choose_camera(ccfg, list_cameras(backend=ccfg.get("backend", "any")))
    if selected is not None:
        ccfg["index"] = selected["index"]
        ccfg["backend"] = selected["backend"]
        print(
            f"Kamera: {selected['name']} "
            f"({selected['source_backend']}, Geräteindex {selected['source_index']})."
        )

    model_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", pcfg["model_path"]))
    if selected is None:
        print(f"Kamera-Index {ccfg['index']} (backend={ccfg.get('backend', 'any')}).")
    camera = Camera(
        ccfg["index"], ccfg["width"], ccfg["height"], ccfg["flip"], ccfg.get("backend", "any")
    )
    pose = PoseTracker(
        model_path,
        pcfg["num_poses"],
        pcfg["min_detection_confidence"],
        pcfg.get("min_torso_visibility", 0.5),
        pcfg.get("active_region"),
    )
    tracker = _make_body_tracker(fcfg)
    sender = UdpJsonSender(cfg["network"]["host"], cfg["network"]["port"])
    preview = cfg["debug"]["preview"]

    print("Webcam-Tracker läuft. 'q' im Vorschaufenster zum Beenden.")
    start = time.time()
    try:
        while True:
            frame = camera.read()
            if frame is None:
                break
            t = time.time() - start
            persons = pose.process(frame, int(t * 1000))
            bodies = tracker.update(persons, t)
            pairs = tracker.compute_pairs(fcfg["proximity_threshold"])
            sender.send(
                build_frame(
                    bodies, pairs, crowd_energy(bodies), t, tracker.take_departures(),
                    tracker.temporarily_missing_ids(),
                )
            )

            if preview:
                _draw_overlay(cv2, frame, bodies)
                cv2.imshow("WIRKLICHT — Tracker (lokal)", frame)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break
    finally:
        sender.close()
        pose.close()
        camera.release()
        if preview:
            cv2.destroyAllWindows()


def _draw_overlay(cv2, frame, bodies) -> None:
    h, w = frame.shape[:2]
    for b in bodies:
        cx, cy = int(b["x"] * w), int(b["y"] * h)
        radius = 8 + int(b["intensity"] * 40)
        cv2.circle(frame, (cx, cy), radius, (0, 255, 0), 2)
        cv2.putText(
            frame,
            f"#{b['id']} i={b['intensity']:.2f}",
            (cx + 10, cy),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            (0, 255, 0),
            1,
        )
    cv2.putText(
        frame,
        f"Personen: {len(bodies)}  (lokal, keine Aufzeichnung)",
        (10, 30),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (0, 255, 255),
        2,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="WIRKLICHT gesture capture")
    parser.add_argument("--sim", action="store_true", help="Ohne Kamera, synthetische Daten senden")
    parser.add_argument(
        "--sim-scenario",
        default="phase44",
        choices=SIM_SCENARIO_CHOICES,
        help="Deterministisches Simulator-Szenario (nur mit --sim; Standard: phase44)",
    )
    parser.add_argument(
        "--list-cameras",
        action="store_true",
        help="Verfügbare Kameras auflisten (Index, Auflösung) und beenden",
    )
    parser.add_argument(
        "--camera", type=int, default=None, help="Kamera-Index (überschreibt config.json)"
    )
    parser.add_argument(
        "--backend",
        choices=("any", "dshow", "msmf"),
        default=None,
        help="OpenCV-Kamera-Backend (Windows: 'dshow' listet physische Webcams zuverlässig)",
    )
    return parser


def apply_overrides(cfg: dict, args: argparse.Namespace) -> dict:
    """Merge CLI overrides into the camera config (returns the same dict)."""
    if getattr(args, "camera", None) is not None:
        cfg["camera"]["index"] = args.camera
        for key in ("name", "device_path", "vid", "pid"):
            cfg["camera"].pop(key, None)
    if getattr(args, "backend", None) is not None:
        cfg["camera"]["backend"] = args.backend
    return cfg


def print_cameras(backend: str = "any") -> None:
    from .camera import list_cameras

    cams = list_cameras(backend=backend)
    if not cams:
        print("Keine Kamera gefunden. Ist eine Webcam angeschlossen / von anderer App belegt?")
        print("Tipp (Windows): --backend dshow ausprobieren.")
        return
    print("Gefundene Kameras:")
    for c in cams:
        usb = f" USB {c['vid']}:{c['pid']}" if c.get("physical") else " virtuell/unklar"
        print(
            f"  {c['index']}: {c['name']} "
            f"({c.get('source_backend', c.get('backend', 'any'))},{usb})"
        )
    print("Auswahl z. B.: python -m capture.tracker --camera 701 --backend any")


def main() -> None:
    args = build_parser().parse_args()
    cfg = apply_overrides(load_config(), args)

    if args.list_cameras:
        print_cameras(cfg["camera"].get("backend", "any"))
        return
    if args.sim:
        run_sim(cfg, args.sim_scenario)
    else:
        run_camera(cfg)


if __name__ == "__main__":
    main()
