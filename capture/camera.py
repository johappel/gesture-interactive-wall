"""Local webcam discovery and capture (OpenCV).

Windows camera numbers are not stable: virtual cameras and a changed USB port
can move a physical webcam to another index. Discovery therefore keeps the
human-readable name and USB identity and uses OpenCV's backend-encoded Windows
indices (for example 701 for DirectShow camera 1).
"""

from __future__ import annotations

from typing import Any


class LatestFrameBuffer:
    """Single-slot, latest-frame-wins buffer (thread-safe, no OpenCV).

    The grab thread overwrites the slot; the consumer takes and clears it.
    ``dropped`` counts frames overwritten before they were consumed - exactly
    the backlog a naive ``cap.read()`` loop would have accumulated. Keeping only
    the newest frame is what stops the visible pose from falling behind reality.
    """

    def __init__(self) -> None:
        import threading

        self._lock = threading.Lock()
        self._frame = None
        self.produced = 0
        self.consumed = 0
        self.dropped = 0

    def put(self, frame) -> None:
        with self._lock:
            if self._frame is not None:
                self.dropped += 1
            self._frame = frame
            self.produced += 1

    def get(self):
        with self._lock:
            frame = self._frame
            self._frame = None
            if frame is not None:
                self.consumed += 1
            return frame


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
    """Local webcam with a low-latency, latest-frame-wins read path.

    On Windows the capture driver buffers frames: when pose inference is slower
    than the camera, ``cap.read()`` hands back ever older buffered frames and
    the visible pose falls behind reality. A background grab thread therefore
    keeps draining the buffer and retains only the newest frame, so ``read()``
    always returns the freshest image and never a growing backlog.

    The negotiated format is read back with ``cap.get(...)`` after every
    ``cap.set(...)`` — OpenCV silently ignores unsupported requests, so the
    effective values must be verified rather than assumed. Configuration is
    generic (FOURCC/FPS/resolution); there is no hard binding to a camera model.
    """

    def __init__(
        self,
        index: int = 0,
        width: int = 1280,
        height: int = 720,
        flip: bool = True,
        backend: str = "any",
        fps: int = 30,
        fourcc: str = "MJPG",
        latest_frame_wins: bool = True,
    ) -> None:
        import cv2  # imported lazily so tests/sim run without OpenCV

        self._cv2 = cv2
        self.flip = flip
        self.index = index
        self.cap = cv2.VideoCapture(index, _backend_id(cv2, backend))
        if not self.cap.isOpened():
            raise RuntimeError(
                f"Kamera {index} (backend={backend}) konnte nicht geöffnet werden. "
                "Verfügbare Kameras zeigt: python -m capture.tracker --list-cameras"
            )
        # Order matters for several drivers: pixel format before resolution,
        # then FPS. A shallow driver buffer further reduces latency where honored.
        if fourcc:
            self.cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*fourcc[:4]))
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        if fps:
            self.cap.set(cv2.CAP_PROP_FPS, fps)
        try:
            self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        except Exception:
            pass

        self.negotiated = self._read_back(width, height, fps, fourcc)

        self._latest_frame_wins = latest_frame_wins
        self._buffer = LatestFrameBuffer() if latest_frame_wins else None
        self._thread = None
        self._running = False
        if latest_frame_wins:
            import threading

            self._running = True
            self._thread = threading.Thread(target=self._grab_loop, name="camera-grab", daemon=True)
            self._thread.start()

    def _read_back(self, req_width: int, req_height: int, req_fps: int, req_fourcc: str) -> dict:
        cv2 = self._cv2
        raw_fourcc = int(self.cap.get(cv2.CAP_PROP_FOURCC))
        fourcc = _decode_fourcc(raw_fourcc)
        info = {
            "width": int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
            "height": int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
            "fps": float(self.cap.get(cv2.CAP_PROP_FPS)),
            "fourcc": fourcc,
        }
        if req_fourcc and fourcc and fourcc.strip() and fourcc[:4].upper() != req_fourcc[:4].upper():
            print(f"[camera] FOURCC angefragt {req_fourcc[:4]}, ausgehandelt {fourcc}")
        if info["width"] != req_width or info["height"] != req_height:
            print(
                f"[camera] Auflösung angefragt {req_width}x{req_height}, "
                f"ausgehandelt {info['width']}x{info['height']}"
            )
        return info

    def _grab_loop(self) -> None:
        while self._running:
            ok, frame = self.cap.read()
            if not ok or frame is None:
                continue
            self._buffer.put(frame)

    def read(self):
        """Return the newest BGR frame or None."""
        if self._latest_frame_wins:
            frame = self._buffer.get()
            if frame is None:
                return None
        else:
            ok, frame = self.cap.read()
            if not ok or frame is None:
                return None
        if self.flip:
            frame = self._cv2.flip(frame, 1)
        return frame

    @property
    def dropped_frames(self) -> int:
        """Frames grabbed but overwritten before ``read`` consumed them."""
        return self._buffer.dropped if self._buffer is not None else 0

    def describe(self) -> dict:
        """Negotiated capture format, for diagnostics (no image data)."""
        return dict(self.negotiated)

    def release(self) -> None:
        self._running = False
        if self._thread is not None:
            self._thread.join(timeout=1.0)
        self.cap.release()


def _decode_fourcc(value: int) -> str:
    if not value:
        return ""
    try:
        return "".join(chr((int(value) >> (8 * i)) & 0xFF) for i in range(4)).strip("\x00 ")
    except (ValueError, TypeError):
        return ""


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
