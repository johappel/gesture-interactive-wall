"""On-site benchmark harness for pose inference cost.

WIRKLICHT's latency is dominated by MediaPipe pose inference. This tool sweeps
``num_poses`` and the pose inference resolution against the real camera and
reports, for each setting, the mean pose time and the effective update rate, so
a default can be chosen from measurement rather than theoretical capacity.

    python -m capture.bench                 # default sweep, ~4 s per setting
    python -m capture.bench --seconds 6
    python -m capture.bench --num-poses 4 6 8 12 --inference 0 1280x720 960x540

Nothing is stored; only timing aggregates are printed. Requires the camera,
OpenCV and MediaPipe (unlike the unit-testable core, this is a runtime tool).
"""

from __future__ import annotations

import argparse
import os
import time

from .tracker import load_config


def _parse_resolution(token: str) -> tuple[int, int]:
    if token in ("0", "off", "none"):
        return 0, 0
    if "x" not in token:
        raise argparse.ArgumentTypeError(f"Auflösung '{token}' erwartet BxH oder 0")
    w, h = token.lower().split("x", 1)
    return int(w), int(h)


def _measure(camera, pose, seconds: float) -> dict:
    frames = 0
    pose_total = 0.0
    raw_total = 0
    accepted_total = 0
    start = time.time()
    while time.time() - start < seconds:
        frame = camera.read()
        if frame is None:
            continue
        t_ms = int((time.time() - start) * 1000)
        p0 = time.perf_counter()
        pose.process(frame, t_ms)
        pose_total += time.perf_counter() - p0
        frames += 1
        raw_total += pose.last_raw_poses
        accepted_total += pose.last_accepted
    elapsed = max(time.time() - start, 1e-6)
    return {
        "frames": frames,
        "fps": frames / elapsed,
        "pose_ms": (pose_total / frames * 1000.0) if frames else 0.0,
        "raw": raw_total / frames if frames else 0.0,
        "accepted": accepted_total / frames if frames else 0.0,
    }


def run(cfg: dict, num_poses_list, inference_list, seconds: float) -> None:
    from .camera import Camera, choose_camera, list_cameras
    from .pose import PoseTracker

    ccfg = cfg["camera"]
    pcfg = cfg["pose"]
    selected = choose_camera(ccfg, list_cameras(backend=ccfg.get("backend", "any")))
    if selected is not None:
        ccfg["index"] = selected["index"]
    camera = Camera(
        ccfg["index"], ccfg["width"], ccfg["height"], ccfg["flip"], ccfg.get("backend", "any"),
        fps=ccfg.get("fps", 30), fourcc=ccfg.get("fourcc", "MJPG"),
        latest_frame_wins=ccfg.get("latest_frame_wins", True),
    )
    negotiated = camera.describe()
    print(f"Kamera ausgehandelt: {negotiated}")
    model_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", pcfg["model_path"]))
    print(f"{'num_poses':>9} {'inference':>12} {'pose_ms':>8} {'fps':>6} {'raw':>5} {'acc':>5}")
    try:
        for num_poses in num_poses_list:
            for inf_w, inf_h in inference_list:
                pose = PoseTracker(
                    model_path, num_poses, pcfg["min_detection_confidence"],
                    pcfg.get("min_torso_visibility", 0.5), pcfg.get("active_region"),
                    min_presence_confidence=pcfg.get("min_presence_confidence"),
                    min_tracking_confidence=pcfg.get("min_tracking_confidence"),
                    inference_width=inf_w, inference_height=inf_h,
                )
                # A short warmup so the first heavy allocation is not measured.
                warm_end = time.time() + 0.5
                while time.time() < warm_end:
                    frame = camera.read()
                    if frame is not None:
                        pose.process(frame, int(time.time() * 1000))
                result = _measure(camera, pose, seconds)
                pose.close()
                label = "camera" if inf_w == 0 else f"{inf_w}x{inf_h}"
                print(
                    f"{num_poses:>9} {label:>12} {result['pose_ms']:>8.1f} "
                    f"{result['fps']:>6.1f} {result['raw']:>5.1f} {result['accepted']:>5.1f}"
                )
    finally:
        camera.release()


def main() -> None:
    parser = argparse.ArgumentParser(description="WIRKLICHT pose inference benchmark")
    parser.add_argument("--seconds", type=float, default=4.0, help="Messdauer pro Einstellung")
    parser.add_argument(
        "--num-poses", type=int, nargs="+", default=[4, 6, 8, 12], help="num_poses-Werte"
    )
    parser.add_argument(
        "--inference",
        type=_parse_resolution,
        nargs="+",
        default=[(0, 0), (1280, 720), (960, 540), (640, 360)],
        help="Inferenzauflösungen (BxH oder 0 für Kameraauflösung)",
    )
    args = parser.parse_args()
    run(load_config(), args.num_poses, args.inference, args.seconds)


if __name__ == "__main__":
    main()
