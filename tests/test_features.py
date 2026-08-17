"""Unit tests for the pure-Python feature math (no camera/ML deps)."""

import math
import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from capture.features import (  # noqa: E402
    BodyTracker,
    L_SHOULDER,
    L_WRIST,
    R_SHOULDER,
    R_WRIST,
    compute_pairs,
    crowd_energy,
    openness,
)
from capture.sim import make_phase44_persons, make_sim_persons  # noqa: E402

_N = 33


def person(cx, cy, wrist_spread=0.1):
    pts = [(cx, cy, 1.0)] * _N
    pts[L_SHOULDER] = (cx - 0.05, cy, 1.0)
    pts[R_SHOULDER] = (cx + 0.05, cy, 1.0)
    pts[L_WRIST] = (cx - wrist_spread, cy, 1.0)
    pts[R_WRIST] = (cx + wrist_spread, cy, 1.0)
    # hips at index 23/24 default to (cx,cy); set for a stable centroid
    pts[23] = (cx - 0.04, cy + 0.1, 1.0)
    pts[24] = (cx + 0.04, cy + 0.1, 1.0)
    return pts


class OpennessTest(unittest.TestCase):
    def test_open_greater_than_closed(self):
        closed = openness(person(0.5, 0.5, wrist_spread=0.02))
        wide = openness(person(0.5, 0.5, wrist_spread=0.3))
        self.assertGreater(wide, closed)

    def test_clamped_to_one(self):
        self.assertLessEqual(openness(person(0.5, 0.5, wrist_spread=0.9)), 1.0)


class TrackerTest(unittest.TestCase):
    def test_stable_id_for_moving_body(self):
        tr = BodyTracker()
        b0 = tr.update([person(0.5, 0.5)], t=0.0)
        b1 = tr.update([person(0.52, 0.5)], t=0.1)
        self.assertEqual(b0[0]["id"], b1[0]["id"])

    def test_new_id_for_distant_body(self):
        tr = BodyTracker(max_dist=0.1)
        first = tr.update([person(0.2, 0.2)], t=0.0)
        second = tr.update([person(0.9, 0.9)], t=0.1)
        self.assertNotEqual(first[0]["id"], second[0]["id"])

    def test_intensity_increases_with_speed(self):
        slow = BodyTracker()
        slow.update([person(0.5, 0.5)], t=0.0)
        slow_body = slow.update([person(0.51, 0.5)], t=0.1)[0]

        fast = BodyTracker()
        fast.update([person(0.5, 0.5)], t=0.0)
        fast_body = fast.update([person(0.6, 0.5)], t=0.1)[0]

        self.assertGreater(fast_body["intensity"], slow_body["intensity"])

    def test_stale_track_removed(self):
        tr = BodyTracker(timeout=0.5)
        tr.update([person(0.5, 0.5)], t=0.0)
        # Long gap with no persons -> track should be dropped.
        tr.update([], t=1.0)
        reappear = tr.update([person(0.5, 0.5)], t=1.1)
        self.assertEqual(reappear[0]["id"], 1)


class PairsTest(unittest.TestCase):
    def _bodies(self, x_a, x_b):
        return [
            {"id": 0, "x": x_a, "y": 0.5, "intensity": 0.2},
            {"id": 1, "x": x_b, "y": 0.5, "intensity": 0.4},
        ]

    def test_pair_within_threshold(self):
        pairs = compute_pairs(self._bodies(0.5, 0.6), threshold=0.35)
        self.assertEqual(len(pairs), 1)
        self.assertAlmostEqual(pairs[0]["mx"], 0.55, places=3)
        self.assertGreater(pairs[0]["proximity"], 0.0)

    def test_no_pair_when_far(self):
        pairs = compute_pairs(self._bodies(0.1, 0.9), threshold=0.35)
        self.assertEqual(pairs, [])

    def test_proximity_increases_when_closer(self):
        near = compute_pairs(self._bodies(0.5, 0.55), threshold=0.35)[0]["proximity"]
        far = compute_pairs(self._bodies(0.5, 0.8), threshold=0.35)[0]["proximity"]
        self.assertGreater(near, far)


class CrowdTest(unittest.TestCase):
    def test_empty_is_zero(self):
        self.assertEqual(crowd_energy([]), 0.0)

    def test_mean_intensity(self):
        bodies = [{"intensity": 0.2}, {"intensity": 0.4}]
        self.assertAlmostEqual(crowd_energy(bodies), 0.3, places=3)


class SimTest(unittest.TestCase):
    def test_two_bodies_with_valid_landmarks(self):
        persons = make_sim_persons(1.23)
        self.assertEqual(len(persons), 2)
        for p in persons:
            self.assertEqual(len(p), 33)
            for x, y, _ in p:
                self.assertTrue(math.isfinite(x) and math.isfinite(y))

    def test_phase44_sequence_covers_idle_one_multiple_idle(self):
        self.assertEqual(len(make_phase44_persons(0.5)), 0)
        self.assertEqual(len(make_phase44_persons(3.0)), 1)
        self.assertEqual(len(make_phase44_persons(7.0)), 2)
        self.assertEqual(len(make_phase44_persons(11.0)), 0)


if __name__ == "__main__":
    unittest.main()
