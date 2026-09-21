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
from capture.sim import (  # noqa: E402
    LIFECYCLE_SCENARIOS,
    make_lifecycle_persons,
    make_phase44_persons,
    make_sim_persons,
)

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


class TrackLifecycleTest(unittest.TestCase):
    def _tracker(self):
        return BodyTracker(
            max_dist=0.3,
            timeout=0.5,
            grace_period=0.5,
            departure_edge_margin=0.08,
            departure_min_speed=0.05,
        )

    def _update_scenario(self, tracker, name, times):
        result = []
        for t in times:
            bodies = tracker.update(make_lifecycle_persons(name, t), t)
            result.append((bodies, tracker.take_departures()))
        return result

    def test_stable_presence_keeps_one_id(self):
        tracker = self._tracker()
        result = self._update_scenario(tracker, "stable", (0.0, 0.2, 0.4, 0.6))
        self.assertEqual({bodies[0]["id"] for bodies, _events in result}, {0})
        self.assertTrue(all(not events for _bodies, events in result))

    def test_short_occlusion_reassociates_without_departure(self):
        tracker = self._tracker()
        result = self._update_scenario(tracker, "occlusion", (0.0, 0.2, 0.4, 0.5, 0.7))
        self.assertEqual(tracker._tracks[0].state, "active")
        self.assertEqual(result[0][0][0]["id"], result[3][0][0]["id"])
        self.assertTrue(all(not events for _bodies, events in result))

    def test_one_frame_flicker_keeps_id_without_departure(self):
        tracker = self._tracker()
        result = self._update_scenario(tracker, "flicker", (0.0, 0.1, 0.2, 0.3))
        self.assertEqual(result[0][0][0]["id"], result[2][0][0]["id"])
        self.assertTrue(all(not events for _bodies, events in result))

    def test_center_loss_ends_without_departure(self):
        tracker = self._tracker()
        result = self._update_scenario(tracker, "center_loss", (0.0, 0.1, 0.2, 0.8))
        self.assertEqual(result[-1][1], [])
        self.assertEqual(tracker.track_count, 0)

    def test_edge_loss_without_outward_motion_is_not_departure(self):
        tracker = self._tracker()
        tracker.update([person(0.02, 0.5)], t=0.0)
        tracker.update([person(0.05, 0.5)], t=0.1)
        tracker.update([], t=0.2)
        tracker.take_departures()
        tracker.update([], t=0.8)
        self.assertEqual(tracker.take_departures(), [])

    def test_left_departure_is_emitted_once(self):
        tracker = self._tracker()
        result = self._update_scenario(tracker, "left_departure", (0.0, 0.1, 0.2, 0.8, 1.0))
        events = [event for _bodies, frame_events in result for event in frame_events]
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["id"], 0)
        self.assertEqual(events[0]["edge"], "left")
        self.assertLess(events[0]["vx"], 0.0)

    def test_right_departure_is_emitted_once(self):
        tracker = self._tracker()
        result = self._update_scenario(tracker, "right_departure", (0.0, 0.1, 0.2, 0.8, 1.0))
        events = [event for _bodies, frame_events in result for event in frame_events]
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["edge"], "right")
        self.assertGreater(events[0]["vx"], 0.0)

    def test_departed_episode_is_not_reused_on_return(self):
        tracker = self._tracker()
        result = self._update_scenario(tracker, "departure_return", (0.0, 0.1, 0.2, 0.8, 1.0))
        departures = [event for _bodies, events in result for event in events]
        self.assertEqual(departures[0]["id"], 0)
        self.assertEqual(result[-1][0][0]["id"], 1)

    def test_crossing_has_unique_ids_and_valid_pair_references(self):
        tracker = self._tracker()
        for t in (0.0, 0.5, 1.0, 1.5):
            bodies = tracker.update(make_lifecycle_persons("crossing", t), t)
            ids = {body["id"] for body in bodies}
            self.assertEqual(len(ids), len(bodies))
            for pair in compute_pairs(bodies, threshold=1.0):
                self.assertIn(pair["a"], ids)
                self.assertIn(pair["b"], ids)
                self.assertNotEqual(pair["a"], pair["b"])
            self.assertEqual(tracker.take_departures(), [])

    def test_group_departure_has_one_event_per_episode(self):
        tracker = self._tracker()
        result = self._update_scenario(
            tracker, "group_left_departure", (0.0, 0.1, 0.2, 0.8, 1.0)
        )
        events = [event for _bodies, frame_events in result for event in frame_events]
        self.assertEqual(len(events), 3)
        self.assertEqual({event["id"] for event in events}, {0, 1, 2})
        self.assertTrue(all(event["edge"] == "left" for event in events))

    def test_long_run_cleans_up_tracks_without_duplicate_bodies(self):
        tracker = self._tracker()
        for step in range(100):
            t = step * 0.1
            bodies = tracker.update(make_lifecycle_persons("long_run", t), t)
            self.assertEqual(len({body["id"] for body in bodies}), len(bodies))
            tracker.take_departures()
        tracker.update([], 11.0)
        self.assertEqual(tracker.track_count, 0)


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

    def test_lifecycle_scenarios_are_available_and_deterministic(self):
        self.assertEqual(len(LIFECYCLE_SCENARIOS), 10)
        for scenario in LIFECYCLE_SCENARIOS:
            self.assertEqual(
                make_lifecycle_persons(scenario, 0.1),
                make_lifecycle_persons(scenario, 0.1),
            )


if __name__ == "__main__":
    unittest.main()
