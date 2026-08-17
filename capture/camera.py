"""Webcam capture wrapper (OpenCV).

On Windows several "cameras" may be present: physical webcams *and* virtual
cameras (OBS, manufacturer tools, phone-as-webcam drivers). ``VideoCapture(0)``
grabs whatever the OS enumerates first, which is often a virtual device showing
a logo — hence "0 Personen". Use ``list_cameras`` / the ``--list-cameras`` CLI
flag to find the real index, then set it via config or ``--camera``.
"""

from __future__ import annotations


def _backend_id(cv2, backend: str) -> int:
    name = (backend or "any").lower()
    if name == "any":
        return getattr(cv2, "CAP_ANY", 0)
    if name == "dshow":
        return getattr(cv2, "CAP_DSHOW", 700)
    if name == "msmf":
        return getattr(cv2, "CAP_MSMF", 1400)
    raise ValueError(f"Unbekanntes Kamera-Backend: {backend!r} (erlaubt: any, dshow, msmf)")


class Camera:
    def __init__(
        self,
        index: int = 0,
        width: int = 1280,
        height: int = 720,
        flip: bool = True,
        backend: str = "any",
    ) -> None:
        import cv2  # imported lazily so tests/sim run without OpenCV

        self._cv2 = cv2
        self.flip = flip
        self.index = index
        self.cap = cv2.VideoCapture(index, _backend_id(cv2, backend))
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        if not self.cap.isOpened():
            raise RuntimeError(
                f"Kamera {index} (backend={backend}) konnte nicht geöffnet werden. "
                "Verfügbare Kameras zeigt: python -m capture.tracker --list-cameras"
            )

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


def list_cameras(max_index: int = 8, backend: str = "any") -> list[dict]:
    """Probe camera indices [0, max_index) and return the ones that deliver frames.

    Each entry: {"index", "width", "height"}. Opening a device can be slow, so
    this is intended for interactive discovery, not the hot capture loop.
    """
    import cv2

    found: list[dict] = []
    api = _backend_id(cv2, backend)
    for index in range(max_index):
        cap = cv2.VideoCapture(index, api)
        try:
            if not cap.isOpened():
                continue
            ok, frame = cap.read()
            if not ok or frame is None:
                continue
            h, w = frame.shape[:2]
            found.append({"index": index, "width": int(w), "height": int(h)})
        finally:
            cap.release()
    return found
