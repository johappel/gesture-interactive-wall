"""Feature extraction and lightweight multi-person tracking.

Pure-Python (no camera/ML deps) so it stays unit-testable. Input is a list of
"persons", each a sequence of MediaPipe Pose landmarks as (x, y[, visibility])
in normalized [0, 1] image coordinates.
"""

from __future__ import annotations

import math
from typing import Sequence

# MediaPipe Pose landmark indices used here.
NOSE = 0
L_SHOULDER = 11
R_SHOULDER = 12
L_WRIST = 15
R_WRIST = 16
L_HIP = 23
R_HIP = 24

Landmark = Sequence[float]
Person = Sequence[Landmark]


def _pt(landmarks: Person, i: int) -> tuple[float, float]:
    lm = landmarks[i]
    return float(lm[0]), float(lm[1])


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def centroid(landmarks: Person) -> tuple[float, float]:
    """Torso center from shoulders and hips."""
    ids = (L_SHOULDER, R_SHOULDER, L_HIP, R_HIP)
    xs = [float(landmarks[i][0]) for i in ids]
    ys = [float(landmarks[i][1]) for i in ids]
    return sum(xs) / len(xs), sum(ys) / len(ys)


def shoulder_width(landmarks: Person) -> float:
    return max(distance(_pt(landmarks, L_SHOULDER), _pt(landmarks, R_SHOULDER)), 1e-6)


def openness(landmarks: Person) -> float:
    """0 = arms closed, 1 = arms spread wide (relative to shoulder width)."""
    spread = distance(_pt(landmarks, L_WRIST), _pt(landmarks, R_WRIST))
    return min(spread / (shoulder_width(landmarks) * 3.0), 1.0)


class _Track:
    __slots__ = ("id", "centroid", "wrists", "t", "intensity")

    def __init__(self, tid: int, c: tuple[float, float], wrists, t: float) -> None:
        self.id = tid
        self.centroid = c
        self.wrists = wrists
        self.t = t
        self.intensity = 0.0


class BodyTracker:
    """Greedy nearest-centroid tracker that assigns stable ids across frames."""

    def __init__(
        self,
        max_dist: float = 0.25,
        timeout: float = 0.6,
        intensity_scale: float = 1.5,
        smoothing: float = 0.4,
    ) -> None:
        self.max_dist = max_dist
        self.timeout = timeout
        self.intensity_scale = intensity_scale
        self.smoothing = smoothing
        self._tracks: dict[int, _Track] = {}
        self._next_id = 0

    def update(self, persons: list[Person], t: float) -> list[dict]:
        cents = [centroid(p) for p in persons]
        wrists = [(_pt(p, L_WRIST), _pt(p, R_WRIST)) for p in persons]

        # Match existing tracks to closest unused person.
        assigned: dict[int, int] = {}  # person index -> track id
        used: set[int] = set()
        for tid, tr in self._tracks.items():
            best, best_d = -1, self.max_dist
            for i, c in enumerate(cents):
                if i in used:
                    continue
                d = distance(tr.centroid, c)
                if d < best_d:
                    best, best_d = i, d
            if best >= 0:
                assigned[best] = tid
                used.add(best)

        bodies: list[dict] = []
        for i, p in enumerate(persons):
            c = cents[i]
            if i in assigned:
                tr = self._tracks[assigned[i]]
                dt = max(t - tr.t, 1e-3)
                vx = (c[0] - tr.centroid[0]) / dt
                vy = (c[1] - tr.centroid[1]) / dt
                wrist_speed = (
                    distance(wrists[i][0], tr.wrists[0])
                    + distance(wrists[i][1], tr.wrists[1])
                ) / (2.0 * dt)
                speed = math.hypot(vx, vy) + wrist_speed
                raw = min(speed * self.intensity_scale, 1.0)
                alpha = self.smoothing
                tr.intensity = tr.intensity * (1.0 - alpha) + raw * alpha
                tr.centroid, tr.wrists, tr.t = c, wrists[i], t
            else:
                tr = _Track(self._next_id, c, wrists[i], t)
                self._next_id += 1
                self._tracks[tr.id] = tr
                vx = vy = 0.0

            bodies.append(
                {
                    "id": tr.id,
                    "x": round(c[0], 4),
                    "y": round(c[1], 4),
                    "vx": round(vx, 4),
                    "vy": round(vy, 4),
                    "intensity": round(tr.intensity, 4),
                    "openness": round(openness(p), 4),
                }
            )

        # Drop tracks not seen within timeout.
        stale = [tid for tid, tr in self._tracks.items() if t - tr.t > self.timeout]
        for tid in stale:
            del self._tracks[tid]

        return bodies


def compute_pairs(bodies: list[dict], threshold: float = 0.35) -> list[dict]:
    """Return proximity bridges for body pairs closer than ``threshold``."""
    pairs: list[dict] = []
    for i in range(len(bodies)):
        for j in range(i + 1, len(bodies)):
            a, b = bodies[i], bodies[j]
            d = math.hypot(a["x"] - b["x"], a["y"] - b["y"])
            if d < threshold:
                pairs.append(
                    {
                        "a": a["id"],
                        "b": b["id"],
                        "proximity": round(1.0 - d / threshold, 4),
                        "mx": round((a["x"] + b["x"]) / 2.0, 4),
                        "my": round((a["y"] + b["y"]) / 2.0, 4),
                    }
                )
    return pairs


def crowd_energy(bodies: list[dict]) -> float:
    if not bodies:
        return 0.0
    return round(sum(b["intensity"] for b in bodies) / len(bodies), 4)
