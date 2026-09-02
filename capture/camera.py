"""Local webcam discovery and capture (OpenCV).

Windows camera numbers are not stable: virtual cameras and a changed USB port
can move a physical webcam to another index. Discovery therefore keeps the
human-readable name and USB identity and uses OpenCV's backend-encoded Windows
indices (for example 701 for DirectShow camera 1).
"""

from __future__ import annotations

from typing import Any


def _backend_id(cv2, backend: str) -> int:
    name = (backend or "any").lower()
    if name == "any":
        return getattr(cv2, "CAP_ANY", 0)
    if name == "dshow":
        return getattr(cv2, "CAP_DSHOW", 700)
    if name == "msmf":
        return getattr(cv2, "CAP_MSMF", 1400)
    raise ValueError(f"Unbekanntes Kamera-Backend: {backend!r} (erlaubt: any, dshow, msmf)")


def _hex_id(value: Any) -> str:
    if value in (None, ""):
        return ""
    if isinstance(value, str):
        return value.strip().upper().removeprefix("0X").zfill(4)
    return f"{int(value):04X}"


def _identity_key(camera: dict) -> tuple:
    path = str(camera.get("path") or "").casefold()
    if path:
        # DirectShow and MSMF append different interface class GUIDs to the
        # same device-instance path. Strip that suffix to deduplicate only the
        # same hardware, while retaining two cameras of the same model.
        return ("path", path.split("#{", 1)[0])
    if camera.get("vid") and camera.get("pid"):
        return ("usb", camera["vid"], camera["pid"])
    return ("name", str(camera.get("name", "")).casefold())


def choose_camera(config: dict, cameras: list[dict]) -> dict | None:
    """Resolve a saved camera identity against current enumeration.

    Device path is most precise. VID/PID and then name survive USB port and
    numerical index changes. The old index/backend pair remains a fallback.
    """
    path = str(config.get("device_path") or "").casefold()
    if path:
        match = next((c for c in cameras if str(c.get("path") or "").casefold() == path), None)
        if match:
            return match

    vid, pid = _hex_id(config.get("vid")), _hex_id(config.get("pid"))
    if vid and pid:
        match = next((c for c in cameras if c.get("vid") == vid and c.get("pid") == pid), None)
        if match:
            return match

    name = str(config.get("name") or "").strip().casefold()
    if name:
        match = next((c for c in cameras if str(c.get("name") or "").casefold() == name), None)
        if match:
            return match

    try:
        index = int(config.get("index"))
    except (TypeError, ValueError):
        return None
    backend = str(config.get("backend") or "any").lower()
    return next(
        (
            c
            for c in cameras
            if int(c["index"]) == index and str(c.get("backend") or "any") == backend
        ),
        None,
    )


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


def _enumerated_windows_cameras(cv2, backend: str) -> list[dict]:
    from cv2_enumerate_cameras import enumerate_cameras

    requested = (backend or "any").lower()
    source_backends = ("dshow", "msmf") if requested == "any" else (requested,)
    found: list[dict] = []
    seen: set[tuple] = set()
    for source_backend in source_backends:
        api = _backend_id(cv2, source_backend)
        for info in enumerate_cameras(api):
            # CAP_ANY plus the backend in the high digits is more reliable for
            # some Windows cameras, notably the Logitech C920.
            encoded_index = int(info.index) + api
            item = {
                "index": encoded_index,
                "backend": "any",
                "source_backend": source_backend,
                "source_index": int(info.index),
                "name": str(info.name),
                "path": str(info.path or ""),
                "vid": _hex_id(info.vid),
                "pid": _hex_id(info.pid),
                "physical": info.vid is not None and info.pid is not None,
            }
            key = _identity_key(item)
            if key in seen:
                continue
            seen.add(key)
            found.append(item)
    return sorted(found, key=lambda camera: (not camera["physical"], camera["name"].casefold()))


def _probe_camera_indices(cv2, max_index: int, backend: str) -> list[dict]:
    """Compatibility fallback for platforms without named enumeration."""
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
            found.append(
                {
                    "index": index,
                    "backend": backend,
                    "source_backend": backend,
                    "source_index": index,
                    "name": f"Kamera {index}",
                    "path": "",
                    "vid": "",
                    "pid": "",
                    "physical": False,
                    "width": int(w),
                    "height": int(h),
                }
            )
        finally:
            cap.release()
    return found


def list_cameras(max_index: int = 8, backend: str = "any") -> list[dict]:
    """Return local cameras with stable names/USB identities where available."""
    import platform
    import cv2

    if platform.system() == "Windows":
        try:
            return _enumerated_windows_cameras(cv2, backend)
        except (ImportError, NotImplementedError):
            pass
    return _probe_camera_indices(cv2, max_index, backend)


def camera_works(index: int, backend: str = "any") -> bool:
    """Open a camera and read one frame without storing it."""
    import cv2

    cap = cv2.VideoCapture(int(index), _backend_id(cv2, backend))
    try:
        if not cap.isOpened():
            return False
        ok, frame = cap.read()
        return bool(ok and frame is not None)
    finally:
        cap.release()
