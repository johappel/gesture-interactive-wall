"""Compact, non-per-frame capture diagnostics.

Pure Python (no camera/ML deps) so it stays unit-testable. The tracker feeds
per-stage timings and per-frame counts; this module aggregates them and emits
one compact line per interval instead of a per-frame log flood.

Nothing here stores images or identity; only timing and count aggregates are
kept, and only for the current interval.
"""

from __future__ import annotations

from typing import Callable


class _Stat:
    __slots__ = ("total", "count")

    def __init__(self) -> None:
        self.total = 0.0
        self.count = 0

    def add(self, value: float) -> None:
        self.total += value
        self.count += 1

    def mean(self) -> float:
        return self.total / self.count if self.count else 0.0

    def reset(self) -> None:
        self.total = 0.0
        self.count = 0


class CaptureDiagnostics:
    """Accumulate capture-loop metrics and format a compact interval summary.

    Timing is injected (``now``) so the aggregation is deterministic and does
    not depend on a wall clock in tests.
    """

    STAGES = ("read", "pose", "features", "udp")

    def __init__(
        self,
        enabled: bool = False,
        interval: float = 1.0,
        printer: Callable[[str], None] = print,
    ) -> None:
        self.enabled = enabled
        self.interval = max(float(interval), 0.05)
        self._printer = printer
        self._stages = {name: _Stat() for name in self.STAGES}
        self._frames = 0
        self._raw_poses = 0
        self._accepted = 0
        self._dropped = 0
        self._tracks_last = 0
        self._missing_last = 0
        self._rejections: dict[str, int] = {}
        self._window_start: float | None = None
        # Camera facts are latched once negotiated and reprinted every interval.
        self.camera_backend = ""
        self.camera_fourcc = ""
        self.camera_width = 0
        self.camera_height = 0
        self.camera_fps = 0.0

    def set_camera_info(
        self,
        backend: str = "",
        fourcc: str = "",
        width: int = 0,
        height: int = 0,
        fps: float = 0.0,
    ) -> None:
        self.camera_backend = backend
        self.camera_fourcc = fourcc
        self.camera_width = int(width)
        self.camera_height = int(height)
        self.camera_fps = float(fps)

    def record_stage(self, name: str, seconds: float) -> None:
        if not self.enabled:
            return
        stat = self._stages.get(name)
        if stat is not None:
            stat.add(max(float(seconds), 0.0) * 1000.0)

    def record_frame(
        self,
        now: float,
        raw_poses: int = 0,
        accepted: int = 0,
        tracks: int = 0,
        temporarily_missing: int = 0,
        rejections: dict[str, int] | None = None,
        dropped: int = 0,
    ) -> None:
        if not self.enabled:
            return
        if self._window_start is None:
            self._window_start = now
        self._frames += 1
        self._raw_poses += int(raw_poses)
        self._accepted += int(accepted)
        self._dropped += int(dropped)
        self._tracks_last = int(tracks)
        self._missing_last = int(temporarily_missing)
        if rejections:
            for reason, count in rejections.items():
                self._rejections[reason] = self._rejections.get(reason, 0) + int(count)

    def maybe_report(self, now: float) -> str | None:
        """Emit and return a summary line when the interval elapsed, else None."""
        if not self.enabled or self._window_start is None:
            return None
        elapsed = now - self._window_start
        if elapsed < self.interval:
            return None
        line = self._format(elapsed)
        self._printer(line)
        self._reset(now)
        return line

    def _format(self, elapsed: float) -> str:
        loop_fps = self._frames / elapsed if elapsed > 0 else 0.0
        avg_raw = self._raw_poses / self._frames if self._frames else 0.0
        avg_acc = self._accepted / self._frames if self._frames else 0.0
        parts = [
            "[capture]",
            f"camera={self.camera_fps:.1f}fps",
            f"loop={loop_fps:.1f}fps",
        ]
        for name in self.STAGES:
            parts.append(f"{name}={self._stages[name].mean():.1f}ms")
        parts.append(f"raw_poses={avg_raw:.1f}")
        parts.append(f"accepted={avg_acc:.1f}")
        parts.append(f"tracks={self._tracks_last}")
        parts.append(f"missing={self._missing_last}")
        parts.append(f"dropped={self._dropped}")
        if self._rejections:
            reasons = ",".join(
                f"{reason}:{count}" for reason, count in sorted(self._rejections.items())
            )
            parts.append(f"rejected={reasons}")
        parts.append(f"backend={self.camera_backend or '?'}")
        parts.append(f"fourcc={self.camera_fourcc or '?'}")
        parts.append(f"resolution={self.camera_width}x{self.camera_height}")
        return " ".join(parts)

    def _reset(self, now: float) -> None:
        for stat in self._stages.values():
            stat.reset()
        self._frames = 0
        self._raw_poses = 0
        self._accepted = 0
        self._dropped = 0
        self._rejections = {}
        self._window_start = now
