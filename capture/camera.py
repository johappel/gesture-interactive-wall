"""Webcam capture wrapper (OpenCV)."""

from __future__ import annotations


class Camera:
    def __init__(self, index: int = 0, width: int = 1280, height: int = 720, flip: bool = True) -> None:
        import cv2  # imported lazily so tests/sim run without OpenCV

        self._cv2 = cv2
        self.flip = flip
        self.cap = cv2.VideoCapture(index)
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        if not self.cap.isOpened():
            raise RuntimeError(f"Kamera {index} konnte nicht geöffnet werden.")

    def read(self):
        """Return a BGR frame or None."""
        ok, frame = self.cap.read()
        if not ok:
            return None
        if self.flip:
            frame = self._cv2.flip(frame, 1)
        return frame

    def release(self) -> None:
        self.cap.release()
