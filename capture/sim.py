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


LIFECYCLE_SCENARIOS = (
    "stable",
    "occlusion",
    "flicker",
    "crossing",
    "center_loss",
    "left_departure",
    "right_departure",
    "group_left_departure",
    "departure_return",
    "long_run",
    "stay_resonance",
    "aftereffect_waves",
    "crowd_aura",
    "proximity",
)


def make_lifecycle_persons(name: str, t: float) -> list[list[tuple[float, float, float]]]:
    """Return deterministic inputs for one Phase-4.5A lifecycle scenario.

    Times are deliberately short and externalised: unit tests can advance
    simulated time without camera, wall-clock delays, or a renderer.
    """
    if name == "stable":
        return [_person(0.40 + min(t, 2.0) * 0.04, 0.5, 0.4)] if t < 3.0 else []
    if name == "occlusion":
        if 0.2 <= t < 0.5:
            return []
        return [_person(0.50 + max(t - 0.5, 0.0) * 0.04, 0.5, 0.4)] if t < 1.0 else []
    if name == "flicker":
        if 0.1 <= t < 0.2:
            return []
        return [_person(0.50 + t * 0.03, 0.5, 0.4)] if t < 0.6 else []
    if name == "crossing":
        if t >= 2.0:
            return []
        return [_person(0.25 + t * 0.2, 0.46, 0.3), _person(0.75 - t * 0.2, 0.54, 0.6)]
    if name == "center_loss":
        return [_person(0.50 + t * 0.02, 0.5, 0.4)] if t < 0.2 else []
    if name == "left_departure":
        if t < 0.1:
            return [_person(0.16, 0.5, 0.4)]
        if t < 0.2:
            return [_person(0.04, 0.5, 0.4)]
        return []
    if name == "right_departure":
        if t < 0.1:
            return [_person(0.84, 0.5, 0.4)]
        if t < 0.2:
            return [_person(0.96, 0.5, 0.4)]
        return []
    if name == "group_left_departure":
        if t < 0.1:
            return [_person(0.18, 0.35, 0.2), _person(0.19, 0.5, 0.4), _person(0.18, 0.65, 0.6)]
        if t < 0.2:
            return [_person(0.04, 0.35, 0.2), _person(0.05, 0.5, 0.4), _person(0.04, 0.65, 0.6)]
        return []
    if name == "departure_return":
        if t < 0.1:
            return [_person(0.16, 0.5, 0.4)]
        if t < 0.2:
            return [_person(0.04, 0.5, 0.4)]
        if t < 1.0:
            return []
        return [_person(0.50, 0.5, 0.4)]
    if name == "long_run":
        phase = t % 3.0
        if phase < 0.5:
            return [_person(0.22 - phase * 0.2, 0.5, 0.4)]
        if phase < 1.2:
            return []
        if phase < 2.0:
            return [_person(0.5, 0.5, 0.4)]
        return make_sim_persons(t)
    if name == "stay_resonance":
        # A long, quiet episode with a brief detection gap.  It makes the
        # Phase-4.5B presence/stillness response inspectable without a camera.
        if t < 4.0:
            return [_person(0.5, 0.5, 0.25)]
        if t < 4.2:
            return []
        if t < 8.0:
            return [_person(0.5, 0.5, 0.25)]
        if t < 9.0:
            return [_person(0.5 + (t - 8.0) * 0.25, 0.5, 0.7)]
        return []
    if name == "aftereffect_waves":
        # One single exit, then a close group exit. Capture emits only the
        # anonymous edge events; the renderer owns the shared wave form.
        phase = t % 8.0
        if phase < 0.5:
            # Keep moving through the final observed frame. Holding a figure
            # still at the edge would correctly suppress a departure event.
            return [_person(0.18 - phase * 0.28, 0.50, 0.35)]
        if 3.0 <= phase < 3.5:
            x = 0.82 + (phase - 3.0) * 0.28
            return [_person(x, 0.38, 0.25), _person(x, 0.50, 0.4), _person(x, 0.62, 0.55)]
        return []
    if name == "crowd_aura":
        return _crowd_aura_persons(t)
    if name == "proximity":
        return _proximity_persons(t)
    raise ValueError(f"Unknown lifecycle scenario: {name}")


def _proximity_persons(t: float) -> list[list[tuple[float, float, float]]]:
    """Two people approach, stand together, then part — loops for viewing.

    This makes the proximity bridge (fire-orbs shuttling, then condensing into a
    shared pair field) inspectable without a camera.
    """
    phase = t % 20.0
    if phase < 2.0:
        return []
    if phase < 7.0:
        f = (phase - 2.0) / 5.0  # approach
        return [_person(0.30 + 0.14 * f, 0.5, 0.3), _person(0.70 - 0.14 * f, 0.5, 0.3)]
    if phase < 13.0:
        # Standing together. Around 9.3-10.0 s the two overlap so much that only
        # one pose is detected (real MediaPipe occlusion); the bridge must ride
        # through this brief merge on the grace period instead of blinking out.
        if 9.3 <= phase < 10.0:
            return [_person(0.5, 0.5, 0.12)]
        return [_person(0.46, 0.5, 0.12), _person(0.54, 0.5, 0.12)]
    if phase < 18.0:
        f = (phase - 13.0) / 5.0  # part
        return [_person(0.46 - 0.16 * f, 0.5, 0.35), _person(0.54 + 0.16 * f, 0.5, 0.35)]
    return []


def _crowd_aura_persons(t: float) -> list[list[tuple[float, float, float]]]:
    """Deterministic crowd growth, movement, stillness, split and departure.

    This scenario exists so crowd_aura can be judged without a camera: the
    shared field must build up, reshape with the group's spread, stay present
    for a quiet group, and fade out calmly while aftereffect_waves takes over.
    """
    phase = t % 72.0
    if phase < 3.0:
        return []
    if phase < 6.0:
        return _crowd(1, t, spread=0.0, cx=0.5, cy=0.5, motion=0.6)
    if phase < 9.0:
        return _crowd(2, t, spread=0.22, cx=0.5, cy=0.5, motion=0.6)
    if phase < 14.0:
        return _crowd(4, t, spread=0.34, cx=0.5, cy=0.5, motion=0.6)
    if phase < 22.0:
        return _crowd(7, t, spread=0.52, cx=0.5, cy=0.5, motion=0.6)
    if phase < 32.0:
        return _crowd(14, t, spread=0.72, cx=0.5, cy=0.5, motion=0.6)
    if phase < 40.0:
        # The whole group drifts through the space; the field should follow
        # slowly instead of snapping to every pose.
        cx = 0.5 + 0.18 * math.sin((phase - 32.0) * 0.5)
        return _crowd(12, t, spread=0.66, cx=cx, cy=0.5, motion=0.6)
    if phase < 48.0:
        # A quiet group: presence stays, energy drops, the aura must remain.
        return _crowd(10, t, spread=0.6, cx=0.5, cy=0.5, motion=0.05)
    if phase < 56.0:
        # The group splits into two clusters; the field should widen.
        left = _crowd(5, t, spread=0.16, cx=0.26, cy=0.5, motion=0.4)
        right = _crowd(5, t, spread=0.16, cx=0.74, cy=0.5, motion=0.4)
        return left + right
    if phase < 64.0:
        # People leave one by one; the aura recedes gradually.
        remaining = max(1, int(10 - (phase - 56.0) * 1.2))
        return _crowd(remaining, t, spread=0.5, cx=0.5, cy=0.5, motion=0.4)
    return []


def _crowd(
    count: int,
    t: float,
    spread: float,
    cx: float,
    cy: float,
    motion: float,
) -> list[list[tuple[float, float, float]]]:
    """Place `count` people in a horizontal band around (cx, cy)."""
    persons = []
    for index in range(count):
        fraction = 0.0 if count == 1 else (index / (count - 1)) - 0.5
        x = cx + fraction * spread
        y = cy + 0.06 * math.sin(index * 1.7)
        arm = 0.5 + 0.5 * math.sin(t * 1.6 + index)
        persons.append(_person(x, y, arm * motion))
    return persons


def make_simulation_persons(name: str, t: float) -> list[list[tuple[float, float, float]]]:
    """Select the established Phase-4.4 sequence or a lifecycle scenario."""
    if name == "phase44":
        return make_phase44_persons(t)
    return make_lifecycle_persons(name, t)
