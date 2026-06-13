"""Backward-compatible scale estimation entry point."""

import sys

from pose_motion.cli import main


if __name__ == "__main__":
    raise SystemExit(main(["scale", *sys.argv[1:]]))
