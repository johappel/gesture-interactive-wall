"""MediaPipe pose tracking wrapper.

Prefers the Tasks API PoseLandmarker (multi-person). Falls back to the legacy
solutions.pose (single person) if the model file is missing.

Both paths return a list of "persons", each a list of (x, y, visibility)
normalized landmarks, matching capture.features expectations.
"""

from __future__ import annotations

import os


class PoseTracker:
    def __init__(self, model_path: str, num_poses: int = 4, min_confidence: float = 0.5) -> None:
        import mediapipe as mp

        self._mp = mp
        self._mode = None
        self._landmarker = None
        self._legacy = None

        if os.path.exists(model_path):
            self._init_tasks(model_path, num_poses, min_confidence)
        else:
            print(
                f"[pose] Modell '{model_path}' nicht gefunden — Rückfall auf "
                "Einzelperson-Tracking. Für Multi-Person: python capture/download_model.py"
            )
            self._init_legacy(min_confidence)

    def _init_tasks(self, model_path, num_poses, min_confidence) -> None:
        from mediapipe.tasks import python as mp_python
        from mediapipe.tasks.python import vision

        options = vision.PoseLandmarkerOptions(
            base_options=mp_python.BaseOptions(model_asset_path=model_path),
            running_mode=vision.RunningMode.VIDEO,
            num_poses=num_poses,
            min_pose_detection_confidence=min_confidence,
            min_tracking_confidence=min_confidence,
        )
        self._landmarker = vision.PoseLandmarker.create_from_options(options)
        self._mode = "tasks"

    def _init_legacy(self, min_confidence) -> None:
        self._legacy = self._mp.solutions.pose.Pose(
            min_detection_confidence=min_confidence,
            min_tracking_confidence=min_confidence,
        )
        self._mode = "legacy"

    def process(self, bgr_frame, timestamp_ms: int) -> list[list[tuple[float, float, float]]]:
        import cv2

        rgb = cv2.cvtColor(bgr_frame, cv2.COLOR_BGR2RGB)

        if self._mode == "tasks":
            mp_image = self._mp.Image(image_format=self._mp.ImageFormat.SRGB, data=rgb)
            result = self._landmarker.detect_for_video(mp_image, timestamp_ms)
            persons = []
            for landmarks in result.pose_landmarks:
                persons.append([(lm.x, lm.y, lm.visibility) for lm in landmarks])
            return persons

        result = self._legacy.process(rgb)
        if not result.pose_landmarks:
            return []
        return [[(lm.x, lm.y, lm.visibility) for lm in result.pose_landmarks.landmark]]

    def close(self) -> None:
        if self._landmarker is not None:
            self._landmarker.close()
        if self._legacy is not None:
            self._legacy.close()
