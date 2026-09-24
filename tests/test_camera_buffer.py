"""Unit tests for the latest-frame-wins buffer (no OpenCV, no camera).

Pins the low-latency contract: never a growing backlog, always the newest
frame, and an accurate dropped-frame count for diagnostics.
"""

import os
import sys
import threading
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from capture.camera import LatestFrameBuffer  # noqa: E402


class LatestFrameBufferTest(unittest.TestCase):
    def test_latest_frame_wins(self):
        buf = LatestFrameBuffer()
        buf.put("a")
        buf.put("b")
        buf.put("c")
        self.assertEqual(buf.get(), "c")

    def test_no_growing_backlog_only_one_slot(self):
        buf = LatestFrameBuffer()
        for frame in range(100):
            buf.put(frame)
        # A single slot: exactly one frame is retrievable, the rest were dropped.
        self.assertEqual(buf.get(), 99)
        self.assertIsNone(buf.get())
        self.assertEqual(buf.dropped, 99)

    def test_consumed_frames_are_not_recounted_as_dropped(self):
        buf = LatestFrameBuffer()
        buf.put("a")
        self.assertEqual(buf.get(), "a")
        buf.put("b")
        self.assertEqual(buf.get(), "b")
        self.assertEqual(buf.dropped, 0)
        self.assertEqual(buf.consumed, 2)

    def test_empty_buffer_returns_none(self):
        buf = LatestFrameBuffer()
        self.assertIsNone(buf.get())

    def test_concurrent_producer_consumer_stay_consistent(self):
        buf = LatestFrameBuffer()
        stop = threading.Event()

        def produce():
            count = 0
            while not stop.is_set():
                buf.put(count)
                count += 1

        worker = threading.Thread(target=produce)
        worker.start()
        try:
            for _ in range(2000):
                buf.get()
        finally:
            stop.set()
            worker.join(timeout=2.0)
        # Every produced frame was either consumed, explicitly dropped, or is
        # still sitting in the single slot. Peek the slot without consuming it,
        # since get() would itself increment ``consumed``.
        remaining = 1 if buf._frame is not None else 0
        self.assertEqual(buf.produced, buf.consumed + buf.dropped + remaining)


if __name__ == "__main__":
    unittest.main()
