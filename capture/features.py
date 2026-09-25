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
TORSO_LANDMARKS = (L_SHOULDER, R_SHOULDER, L_HIP, R_HIP)

Landmark = Sequence[float]
Person = Sequence[Landmark]


def _pt(landmarks: Person, i: int) -> tuple[float, float]:
    lm = landmarks[i]
    return float(lm[0]), float(lm[1])


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def centroid(landmarks: Person) -> tuple[float, float]:
    """Torso center from shoulders and hips."""
    xs = [float(landmarks[i][0]) for i in TORSO_LANDMARKS]
    ys = [float(landmarks[i][1]) for i in TORSO_LANDMARKS]
    return sum(xs) / len(xs), sum(ys) / len(ys)


def is_plausible_person(
    landmarks: Person,
    min_torso_visibility: float = 0.5,
    active_region: dict | None = None,
) -> bool:
    """Return whether a pose has a visible torso inside the active region.

    MediaPipe can occasionally describe object edges as a pose.  Four visible,
    finite torso landmarks are a deliberately small, non-biometric quality
    gate; no identity or body interpretation is inferred.  A region is only
    active when explicitly enabled in configuration.
    """
    return classify_person(landmarks, min_torso_visibility, active_region) == POSE_ACCEPTED


# Non-biometric rejection reasons, surfaced only for diagnostics.
POSE_ACCEPTED = "accepted"
REJECT_INVALID_LANDMARKS = "invalid_landmarks"
REJECT_OUTSIDE_FRAME = "outside_frame"
REJECT_TORSO_VISIBILITY = "torso_visibility"
REJECT_ACTIVE_REGION = "active_region"


def classify_person(
    landmarks: Person,
    min_torso_visibility: float = 0.5,
    active_region: dict | None = None,
) -> str:
    """Return ``POSE_ACCEPTED`` or the first failing quality-gate reason.

    Splitting acceptance from the reason lets the diagnostic mode report *why*
    a pose was dropped (e.g. a partly occluded torso) without changing the
    non-biometric gate itself.
    """
    if len(landmarks) <= R_HIP:
        return REJECT_INVALID_LANDMARKS
    for index in TORSO_LANDMARKS:
        landmark = landmarks[index]
        if len(landmark) < 3:
            return REJECT_INVALID_LANDMARKS
        x, y, visibility = float(landmark[0]), float(landmark[1]), float(landmark[2])
        if not all(math.isfinite(value) for value in (x, y, visibility)):
            return REJECT_INVALID_LANDMARKS
        # MediaPipe may extrapolate a visible shoulder or hip a little beyond
        # the image edge. This is a valid partial pose, provided its torso
        # center stays in the camera image. Reject distant extrapolations.
        if not -0.25 <= x <= 1.25 or not -0.25 <= y <= 1.25:
            return REJECT_OUTSIDE_FRAME
        if visibility < min_torso_visibility:
            return REJECT_TORSO_VISIBILITY

    x, y = centroid(landmarks)
    if not 0.0 <= x <= 1.0 or not 0.0 <= y <= 1.0:
        return REJECT_OUTSIDE_FRAME

    if not active_region or not active_region.get("enabled", False):
        return POSE_ACCEPTED
    try:
        x_min = float(active_region["x_min"])
        x_max = float(active_region["x_max"])
        y_min = float(active_region["y_min"])
        y_max = float(active_region["y_max"])
    except (KeyError, TypeError, ValueError):
        return REJECT_ACTIVE_REGION
    if not (0.0 <= x_min < x_max <= 1.0 and 0.0 <= y_min < y_max <= 1.0):
        return REJECT_ACTIVE_REGION
    if x_min <= x <= x_max and y_min <= y <= y_max:
        return POSE_ACCEPTED
    return REJECT_ACTIVE_REGION


def torso_visibilities(landmarks: Person) -> dict[str, float]:
    """LS/RS/LH/RH visibility, for a compact diagnostic on a rejected pose."""
    labels = ("LS", "RS", "LH", "RH")
    result: dict[str, float] = {}
    for label, index in zip(labels, TORSO_LANDMARKS):
        if index < len(landmarks) and len(landmarks[index]) >= 3:
            try:
                result[label] = round(float(landmarks[index][2]), 2)
            except (TypeError, ValueError):
                result[label] = float("nan")
        else:
            result[label] = float("nan")
    return result


def filter_plausible_persons(
    persons: list[Person], min_torso_visibility: float = 0.5, active_region: dict | None = None
) -> list[Person]:
    """Keep only non-biometrically plausible poses for the resonance space."""
    return [
        person
        for person in persons
        if is_plausible_person(person, min_torso_visibility, active_region)
    ]


def filter_with_diagnostics(
    persons: list[Person],
    min_torso_visibility: float = 0.5,
    active_region: dict | None = None,
) -> tuple[list[Person], dict[str, int], list[dict]]:
    """Filter poses and report why any were rejected.

    Returns the accepted poses, a per-reason rejection count, and a small
    per-rejection detail list (torso visibilities + threshold) for the
    diagnostic mode. No identity or image data is retained.
    """
    accepted: list[Person] = []
    counts: dict[str, int] = {}
    details: list[dict] = []
    for person in persons:
        reason = classify_person(person, min_torso_visibility, active_region)
        if reason == POSE_ACCEPTED:
            accepted.append(person)
            continue
        counts[reason] = counts.get(reason, 0) + 1
        detail: dict = {"reason": reason, "threshold": round(float(min_torso_visibility), 2)}
        if reason == REJECT_TORSO_VISIBILITY:
            detail["visibility"] = torso_visibilities(person)
        details.append(detail)
    return accepted, counts, details


def shoulder_width(landmarks: Person) -> float:
    return max(distance(_pt(landmarks, L_SHOULDER), _pt(landmarks, R_SHOULDER)), 1e-6)


def openness(landmarks: Person) -> float:
    """0 = arms closed, 1 = arms spread wide (relative to shoulder width)."""
    spread = distance(_pt(landmarks, L_WRIST), _pt(landmarks, R_WRIST))
    return min(spread / (shoulder_width(landmarks) * 3.0), 1.0)


class _Track:
    __slots__ = (
        "id",
        "centroid",
        "smooth",
        "wrists",
        "t",
        "intensity",
        "vx",
        "vy",
        "state",
        "missing_since",
        "seen_frames",
        "presence_started_at",
        "stillness",
    )

    def __init__(self, tid: int, c: tuple[float, float], wrists, t: float) -> None:
        self.id = tid
        self.centroid = c
        # ``centroid`` stays the raw last observation (matching, prediction,
        # departure edge test); ``smooth`` is the low-pass position that leaves
        # the tracker so pose jitter does not make the rendered body jump.
        self.smooth = c
        self.wrists = wrists
        self.t = t
        self.intensity = 0.0
        self.vx = 0.0
        self.vy = 0.0
        self.state = "active"
        self.missing_since: float | None = None
        self.seen_frames = 1
        # This is an anonymous presence episode, not an identity.  Its clock
        # deliberately survives a short missing-detection grace period.
        self.presence_started_at = t
        self.stillness = 0.0


class BodyTracker:
    """Anonymous presence-episode tracker with a bounded missing-track grace period.

    A track represents only its current episode in the resonance space.  It is
    never re-used after it has been ended, whether that end was a plausible
    departure or an inconclusive tracking loss.
    """

    def __init__(
        self,
        max_dist: float = 0.25,
        timeout: float = 0.6,
        intensity_scale: float = 1.5,
        smoothing: float = 0.4,
        grace_period: float | None = None,
        departure_edge_margin: float = 0.08,
        departure_min_speed: float = 0.05,
        confirmation_frames: int = 1,
        stillness_speed_threshold: float = 0.08,
        stillness_rise_seconds: float = 2.5,
        stillness_fall_seconds: float = 0.8,
        position_smoothing: float = 1.0,
    ) -> None:
        self.max_dist = max_dist
        # ``timeout`` remains accepted for existing callers.  New configs use
        # the clearer lifecycle name ``grace_period``.
        self.timeout = timeout
        self.grace_period = timeout if grace_period is None else grace_period
        self.intensity_scale = intensity_scale
        self.smoothing = smoothing
        # 1.0 forwards the raw centroid unchanged; smaller values low-pass the
        # emitted position (EMA blend factor per matched frame).
        self.position_smoothing = min(max(float(position_smoothing), 1e-3), 1.0)
        self.departure_edge_margin = departure_edge_margin
        self.departure_min_speed = departure_min_speed
        self.confirmation_frames = max(int(confirmation_frames), 1)
        self.stillness_speed_threshold = max(float(stillness_speed_threshold), 1e-6)
        self.stillness_rise_seconds = max(float(stillness_rise_seconds), 1e-3)
        self.stillness_fall_seconds = max(float(stillness_fall_seconds), 1e-3)
        self._tracks: dict[int, _Track] = {}
        self._next_id = 0
        self._departures: list[dict] = []

    def take_departures(self) -> list[dict]:
        """Return departure events accumulated since the previous call.

        Events are intentionally drained: a renderer can receive a departure
        once, while the tracker never exposes it as a persistent body state.
        """
        departures = self._departures
        self._departures = []
        return departures

    def temporarily_missing_ids(self) -> list[int]:
        """Return confirmed anonymous episodes currently inside the grace period.

        This is transient renderer metadata only. Missing tracks remain absent
        from bodies, pairs and crowd calculations; a renderer can merely avoid
        fading their already-visible light before the bounded grace period ends.
        """
        return sorted(
            tr.id
            for tr in self._tracks.values()
            if tr.state == "temporarily_missing" and tr.seen_frames >= self.confirmation_frames
        )

    @property
    def track_count(self) -> int:
        """Number of active or temporarily missing tracks, for diagnostics."""
        return len(self._tracks)

    def nearest_track_distance(self) -> float | None:
        """Smallest normalized distance between two confirmed tracks, or None.

        Diagnostic only: it shows whether people are actually close enough to
        form a proximity pair, independent of the pair threshold. If this stays
        above ``proximity_threshold`` while people look "together", the camera
        frames a wider area than the threshold assumes.
        """
        points = [
            tr.smooth
            for tr in self._tracks.values()
            if tr.seen_frames >= self.confirmation_frames
            and tr.state in ("active", "temporarily_missing")
        ]
        if len(points) < 2:
            return None
        nearest = float("inf")
        for i in range(len(points)):
            for j in range(i + 1, len(points)):
                nearest = min(nearest, math.hypot(points[i][0] - points[j][0], points[i][1] - points[j][1]))
        return round(nearest, 4)

    def _predicted_centroid(self, tr: _Track, t: float) -> tuple[float, float]:
        # One noisy observation can produce a very large instantaneous
        # velocity, especially when inference has a low or uneven frame rate.
        # Keep prediction local; the last observed position remains a fallback
        # for reassociation after a longer detection gap.
        elapsed = min(max(t - tr.t, 0.0), 0.2)
        return tr.centroid[0] + tr.vx * elapsed, tr.centroid[1] + tr.vy * elapsed

    def _departure_event(self, tr: _Track) -> dict | None:
        """Classify a finalised missing track only when exit evidence agrees.

        Being close to an edge is insufficient.  The last observed velocity
        must point through that same edge, so an occlusion at an edge does not
        automatically become an aesthetically meaningful departure.
        """
        x, y = tr.centroid
        margin = self.departure_edge_margin
        candidates: list[tuple[float, str, bool]] = []
        if x <= margin:
            candidates.append((x, "left", tr.vx <= -self.departure_min_speed))
        if x >= 1.0 - margin:
            candidates.append((1.0 - x, "right", tr.vx >= self.departure_min_speed))
        if y <= margin:
            candidates.append((y, "top", tr.vy <= -self.departure_min_speed))
        if y >= 1.0 - margin:
            candidates.append((1.0 - y, "bottom", tr.vy >= self.departure_min_speed))
        if not candidates:
            return None
        outward_candidates = [candidate for candidate in candidates if candidate[2]]
        if not outward_candidates:
            return None
        _distance, edge, _outward = min(outward_candidates, key=lambda item: item[0])
        if tr.seen_frames < self.confirmation_frames:
            return None
        return {
            "id": tr.id,
            "edge": edge,
            "x": round(x, 4),
            "y": round(y, 4),
            "vx": round(tr.vx, 4),
            "vy": round(tr.vy, 4),
        }

    def _update_stillness(self, tr: _Track, speed: float, dt: float) -> None:
        """Blend observed movement into a continuous, non-semantic calmness value."""
        target = min(max(1.0 - speed / self.stillness_speed_threshold, 0.0), 1.0)
        time_constant = (
            self.stillness_rise_seconds if target >= tr.stillness else self.stillness_fall_seconds
        )
        alpha = 1.0 - math.exp(-max(dt, 0.0) / time_constant)
        tr.stillness += (target - tr.stillness) * alpha

    def update(self, persons: list[Person], t: float) -> list[dict]:
        cents = [centroid(p) for p in persons]
        wrists = [(_pt(p, L_WRIST), _pt(p, R_WRIST)) for p in persons]

        # Globally sort feasible track/person candidates.  This small,
        # deterministic assignment prevents the iteration order of tracks from
        # assigning one detection twice and uses a velocity prediction during a
        # short occlusion.
        assigned: dict[int, int] = {}  # person index -> track id
        candidates: list[tuple[float, int, int]] = []
        for tid, tr in self._tracks.items():
            if t - tr.t > self.grace_period:
                continue
            predicted = self._predicted_centroid(tr, t)
            for i, c in enumerate(cents):
                d = min(distance(predicted, c), distance(tr.centroid, c) + 0.02)
                if d <= self.max_dist:
                    candidates.append((d, tid, i))
        used_tracks: set[int] = set()
        used_persons: set[int] = set()
        for _distance, tid, i in sorted(candidates):
            if tid not in used_tracks and i not in used_persons:
                assigned[i] = tid
                used_tracks.add(tid)
                used_persons.add(i)

        bodies: list[dict] = []
        visible_tracks: set[int] = set()
        for i, p in enumerate(persons):
            c = cents[i]
            if i in assigned:
                tr = self._tracks[assigned[i]]
                dt = max(t - tr.t, 1e-3)
                reassociated_after_gap = tr.state == "temporarily_missing"
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
                # A gap carries no observed movement.  Do not turn the
                # position delta across it into an artificial stillness reset;
                # the next contiguous observation resumes the smooth update.
                if not reassociated_after_gap:
                    self._update_stillness(tr, speed, dt)
                # A gap freezes the smoothed position; on reassociation snap it
                # to the fresh observation instead of gliding across the gap.
                if reassociated_after_gap:
                    tr.smooth = c
                else:
                    beta = self.position_smoothing
                    tr.smooth = (
                        tr.smooth[0] + (c[0] - tr.smooth[0]) * beta,
                        tr.smooth[1] + (c[1] - tr.smooth[1]) * beta,
                    )
                tr.centroid, tr.wrists, tr.t = c, wrists[i], t
                tr.vx, tr.vy = vx, vy
                tr.state = "active"
                tr.missing_since = None
                tr.seen_frames += 1
            else:
                tr = _Track(self._next_id, c, wrists[i], t)
                self._next_id += 1
                self._tracks[tr.id] = tr
                vx = vy = 0.0

            visible_tracks.add(tr.id)

            if tr.seen_frames >= self.confirmation_frames:
                bodies.append(
                    {
                        "id": tr.id,
                        "x": round(tr.smooth[0], 4),
                        "y": round(tr.smooth[1], 4),
                        "vx": round(vx, 4),
                        "vy": round(vy, 4),
                        "intensity": round(tr.intensity, 4),
                        "openness": round(openness(p), 4),
                        "presence_time": round(max(t - tr.presence_started_at, 0.0), 4),
                        "stillness": round(tr.stillness, 4),
                    }
                )

        # An unmatched track becomes temporarily missing.  It remains eligible
        # for reassociation during the grace period, but never appears in
        # ``bodies``/pairs/crowd until it is actually detected again.
        for tid, tr in self._tracks.items():
            if tid not in visible_tracks and tr.missing_since is None:
                tr.state = "temporarily_missing"
                tr.missing_since = t

        # Once the bounded grace period has elapsed, distinguish a plausible
        # outward edge exit from an inconclusive loss and then forget the
        # episode in both cases.  This makes departure exactly-once by design.
        stale = [tid for tid, tr in self._tracks.items() if t - tr.t > self.grace_period]
        for tid in stale:
            departure = self._departure_event(self._tracks[tid])
            if departure is not None:
                self._departures.append(departure)
            del self._tracks[tid]

        return bodies

    def compute_pairs(self, threshold: float = 0.35) -> list[dict]:
        """Proximity bridges that survive a brief occlusion of one partner.

        A relationship is not the same as two visible detections. When two
        people stand together, MediaPipe frequently reports only one pose; the
        other track then sits in the bounded grace period. Keeping the pair
        alive with that partner's last known position lets the bridge stay put —
        and condense into the shared field — instead of blinking out at the very
        moment the two come together. A pair needs at least one currently
        detected endpoint, so two invisible people are never bridged. Call this
        immediately after ``update`` (stale tracks are already pruned there, so
        any remaining missing track is within the grace period).
        """
        endpoints: list[tuple[int, float, float, bool]] = []
        for tr in self._tracks.values():
            if tr.seen_frames < self.confirmation_frames:
                continue
            if tr.state not in ("active", "temporarily_missing"):
                continue
            endpoints.append((tr.id, tr.smooth[0], tr.smooth[1], tr.state == "active"))

        pairs: list[dict] = []
        for i in range(len(endpoints)):
            for j in range(i + 1, len(endpoints)):
                id_i, xi, yi, active_i = endpoints[i]
                id_j, xj, yj, active_j = endpoints[j]
                if not (active_i or active_j):
                    continue
                d = math.hypot(xi - xj, yi - yj)
                if d >= threshold:
                    continue
                if id_i <= id_j:
                    a_id, ax, ay, a_vis = id_i, xi, yi, active_i
                    b_id, bx, by, b_vis = id_j, xj, yj, active_j
                else:
                    a_id, ax, ay, a_vis = id_j, xj, yj, active_j
                    b_id, bx, by, b_vis = id_i, xi, yi, active_i
                pairs.append(
                    {
                        "a": a_id,
                        "b": b_id,
                        "proximity": round(1.0 - d / threshold, 4),
                        "mx": round((ax + bx) / 2.0, 4),
                        "my": round((ay + by) / 2.0, 4),
                        "ax": round(ax, 4),
                        "ay": round(ay, 4),
                        "bx": round(bx, 4),
                        "by": round(by, 4),
                        # Visibility of each endpoint this frame. ``occluded``
                        # means one partner is only remembered (grace period):
                        # the renderer must then freeze the bridge instead of
                        # inventing motion for an unobserved person.
                        "a_visible": bool(a_vis),
                        "b_visible": bool(b_vis),
                        "occluded": not (a_vis and b_vis),
                    }
                )
        return pairs


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
                        "ax": round(a["x"], 4),
                        "ay": round(a["y"], 4),
                        "bx": round(b["x"], 4),
                        "by": round(b["y"], 4),
                    }
                )
    return pairs


def crowd_energy(bodies: list[dict]) -> float:
    if not bodies:
        return 0.0
    return round(sum(b["intensity"] for b in bodies) / len(bodies), 4)
