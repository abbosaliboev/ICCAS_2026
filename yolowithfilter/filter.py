"""Backward-compatible motion analysis entry point."""

import sys

from pose_motion.cli import main


if __name__ == "__main__":
    raise SystemExit(main(["analyze", *sys.argv[1:]]))
