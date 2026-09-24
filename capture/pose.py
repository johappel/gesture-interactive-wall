"""MediaPipe pose tracking wrapper.

Prefers the Tasks API PoseLandmarker (multi-person). Falls back to the legacy
solutions.pose (single person) if the model file is missing.

Both paths return a list of "persons", each a list of (x, y, visibility)
normalized landmarks, matching capture.features expectations.

The inference image can be downscaled independently of the camera resolution:
WIRKLICHT only needs normalized pose coordinates, which are invariant to a
resize, so there is no reason to run heavy full-HD inference just because the
camera delivers full HD.
"""

from __future__ import annotations

import os

from .features import filter_with_diagnostics


class PoseTracker:
    def __init__(
        self,
        model_path: str,
        num_poses: int = 4,
        min_confidence: float = 0.5,
        min_torso_visibility: float = 0.5,
        active_region: dict | None = None,
        min_presence_confidence: float | None = None,
        min_tracking_confidence: float | None = None,
        inference_width: int = 0,
        inference_height: int = 0,
    ) -> None:
        import mediapipe as mp

        self._mp = mp
        self._mode = None
        self._landmarker = None
        self._legacy = None
        self._min_torso_visibility = min_torso_visibility
        self._active_region = active_region
        # 0 disables downscaling and feeds the full camera frame to MediaPipe.
        self._inference_width = max(int(inference_width), 0)
        self._inference_height = max(int(inference_height), 0)
        # Last-frame filter diagnostics (raw/accepted/rejections), read by the
        # tracker only when the diagnostic mode is on. No image/identity kept.
        self.last_raw_poses = 0
        self.last_accepted = 0
        self.last_rejections: dict[str, int] = {}
        self.last_rejection_details: list[dict] = []

        detection = min_confidence
        presence = min_confidence if min_presence_confidence is None else min_presence_confidence
        tracking = min_confidence if min_tracking_confidence is None else min_tracking_confidence

        if os.path.exists(model_path):
            self._init_tasks(model_path, num_poses, detection, presence, tracking)
        else:
            print(
                f"[pose] Modell '{model_path}' nicht gefunden — Rückfall auf "
                "Einzelperson-Tracking. Für Multi-Person: python capture/download_model.py"
            )
            self._init_legacy(detection, tracking)

    def _init_tasks(self, model_path, num_poses, detection, presence, tracking) -> None:
        from mediapipe.tasks import python as mp_python
        from mediapipe.tasks.python import vision

        options = vision.PoseLandmarkerOptions(
            base_options=mp_python.BaseOptions(model_asset_path=model_path),
            running_mode=vision.RunningMode.VIDEO,
            num_poses=num_poses,
            min_pose_detection_confidence=detection,
            min_pose_presence_confidence=presence,
            min_tracking_confidence=tracking,
        )
        self._landmarker = vision.PoseLandmarker.create_from_options(options)
        self._mode = "tasks"

    def _init_legacy(self, detection, tracking) -> None:
        self._legacy = self._mp.solutions.pose.Pose(
            min_detection_confidence=detection,
            min_tracking_confidence=tracking,
        )
        self._mode = "legacy"

    def _prepare_rgb(self, bgr_frame):
        import cv2

        frame = bgr_frame
        if self._inference_width > 0 and self._inference_height > 0:
            h, w = bgr_frame.shape[:2]
            if w != self._inference_width or h != self._inference_height:
                # A resize keeps normalized landmark coordinates valid: they map
                # to the same field of view regardless of pixel dimensions.
                frame = cv2.resize(
                    bgr_frame,
                    (self._inference_width, self._inference_height),
                    interpolation=cv2.INTER_AREA,
                )
        return cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    def process(self, bgr_frame, timestamp_ms: int) -> list[list[tuple[float, float, float]]]:
        rgb = self._prepare_rgb(bgr_frame)

        if self._mode == "tasks":
            mp_image = self._mp.Image(image_format=self._mp.ImageFormat.SRGB, data=rgb)
            result = self._landmarker.detect_for_video(mp_image, timestamp_ms)
            persons = [
                [(lm.x, lm.y, lm.visibility) for lm in landmarks]
                for landmarks in result.pose_landmarks
            ]
        else:
            result = self._legacy.process(rgb)
            if not result.pose_landmarks:
                persons = []
            else:
                persons = [
                    [(lm.x, lm.y, lm.visibility) for lm in result.pose_landmarks.landmark]
                ]

        accepted, counts, details = filter_with_diagnostics(
            persons, self._min_torso_visibility, self._active_region
        )
        self.last_raw_poses = len(persons)
        self.last_accepted = len(accepted)
        self.last_rejections = counts
        self.last_rejection_details = details
        return accepted

    def close(self) -> None:
        if self._landmarker is not None:
            self._landmarker.close()
        if self._legacy is not None:
            self._legacy.close()
