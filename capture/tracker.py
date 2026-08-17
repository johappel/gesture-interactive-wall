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

from .features import BodyTracker, compute_pairs, crowd_energy
from .net import UdpJsonSender

_CONFIG_PATH = os.path.join(os.path.dirname(__file__), "..", "config", "config.json")


def load_config(path: str = _CONFIG_PATH) -> dict:
    with open(os.path.abspath(path), "r", encoding="utf-8") as fh:
        return json.load(fh)


def build_frame(bodies, pairs, energy, t) -> dict:
    return {
        "t": round(t, 3),
        "bodies": bodies,
        "pairs": pairs,
        "crowd": {"count": len(bodies), "energy": energy},
    }


def run_sim(cfg: dict) -> None:
    from .sim import make_sim_persons

    fcfg = cfg["features"]
    tracker = BodyTracker(
        max_dist=fcfg["track_max_dist"],
        timeout=fcfg["track_timeout"],
        intensity_scale=fcfg["intensity_scale"],
        smoothing=fcfg["intensity_smoothing"],
    )
    sender = UdpJsonSender(cfg["network"]["host"], cfg["network"]["port"])
    print("Simulator läuft (Strg+C zum Beenden) ...")
    start = time.time()
    try:
        while True:
            t = time.time() - start
            persons = make_sim_persons(t)
            bodies = tracker.update(persons, t)
            pairs = compute_pairs(bodies, fcfg["proximity_threshold"])
            sender.send(build_frame(bodies, pairs, crowd_energy(bodies), t))
            time.sleep(1.0 / 60.0)
    except KeyboardInterrupt:
        pass
    finally:
        sender.close()


def run_camera(cfg: dict) -> None:
    import cv2

    from .camera import Camera
    from .pose import PoseTracker

    fcfg = cfg["features"]
    ccfg = cfg["camera"]
    pcfg = cfg["pose"]

    model_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", pcfg["model_path"]))
    camera = Camera(ccfg["index"], ccfg["width"], ccfg["height"], ccfg["flip"])
    pose = PoseTracker(model_path, pcfg["num_poses"], pcfg["min_detection_confidence"])
    tracker = BodyTracker(
        max_dist=fcfg["track_max_dist"],
        timeout=fcfg["track_timeout"],
        intensity_scale=fcfg["intensity_scale"],
        smoothing=fcfg["intensity_smoothing"],
    )
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
            pairs = compute_pairs(bodies, fcfg["proximity_threshold"])
            sender.send(build_frame(bodies, pairs, crowd_energy(bodies), t))

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


def main() -> None:
    parser = argparse.ArgumentParser(description="WIRKLICHT gesture capture")
    parser.add_argument("--sim", action="store_true", help="Ohne Kamera, synthetische Daten senden")
    args = parser.parse_args()

    cfg = load_config()
    if args.sim:
        run_sim(cfg)
    else:
        run_camera(cfg)


if __name__ == "__main__":
    main()
