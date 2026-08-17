"""Download the MediaPipe PoseLandmarker model for multi-person tracking."""

from __future__ import annotations

import os
import urllib.request

URL = (
    "https://storage.googleapis.com/mediapipe-models/pose_landmarker/"
    "pose_landmarker_full/float16/latest/pose_landmarker_full.task"
)
DEST = os.path.join(os.path.dirname(__file__), "..", "models", "pose_landmarker_full.task")


def main() -> None:
    dest = os.path.abspath(DEST)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.exists(dest):
        print(f"Modell bereits vorhanden: {dest}")
        return
    print(f"Lade Modell von {URL} ...")
    urllib.request.urlretrieve(URL, dest)
    print(f"Gespeichert: {dest}")


if __name__ == "__main__":
    main()
