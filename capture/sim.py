"""Synthetic body generator for testing the renderer without a camera.

Produces the same "persons" structure (33 landmarks) that PoseTracker returns,
so the full feature pipeline runs unchanged.
"""

from __future__ import annotations

import math

_N_LANDMARKS = 33
from .features import (  # noqa: E402
    L_HIP,
    L_SHOULDER,
    L_WRIST,
    NOSE,
    R_HIP,
    R_SHOULDER,
    R_WRIST,
)


def _person(cx: float, cy: float, arm: float, scale: float = 0.12):
    """Build a minimal stick figure around center (cx, cy)."""
    pts = [(cx, cy, 1.0)] * _N_LANDMARKS
    pts[NOSE] = (cx, cy - scale * 1.3, 1.0)
    pts[L_SHOULDER] = (cx - scale, cy - scale * 0.6, 1.0)
    pts[R_SHOULDER] = (cx + scale, cy - scale * 0.6, 1.0)
    pts[L_HIP] = (cx - scale * 0.7, cy + scale, 1.0)
    pts[R_HIP] = (cx + scale * 0.7, cy + scale, 1.0)
    # Wrists swing outward/upward with `arm` in [0, 1] -> openness + intensity.
    pts[L_WRIST] = (cx - scale * (1.0 + arm * 2.0), cy - scale * arm, 1.0)
    pts[R_WRIST] = (cx + scale * (1.0 + arm * 2.0), cy - scale * arm, 1.0)
    return pts


def make_sim_persons(t: float) -> list[list[tuple[float, float, float]]]:
    a = _person(
        0.35 + 0.12 * math.sin(t * 0.7),
        0.5 + 0.08 * math.sin(t * 1.1),
        0.5 + 0.5 * math.sin(t * 2.3),
    )
    b = _person(
        0.65 + 0.12 * math.sin(t * 0.7 + math.pi),
        0.5 + 0.08 * math.cos(t * 0.9),
        0.5 + 0.5 * math.sin(t * 1.7 + 1.0),
    )
    return [a, b]


def make_phase44_persons(t: float) -> list[list[tuple[float, float, float]]]:
    """Return a repeatable idle -> one -> two -> idle acceptance sequence.

    This only exercises the existing body/intensity/openness pipeline. It does
    not add any Phase-4.5 signals or departure semantics.
    """
    phase = t % 14.0
    if phase < 2.0 or phase >= 10.0:
        return []
    if phase < 6.0:
        return [
            _person(
                0.5 + 0.12 * math.sin(t * 0.7),
                0.5 + 0.08 * math.sin(t * 1.1),
                0.5 + 0.5 * math.sin(t * 2.3),
            )
        ]
    return make_sim_persons(t)
