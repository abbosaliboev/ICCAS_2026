"""Backward-compatible pose extraction entry point."""

import sys

from pose_motion.cli import main


if __name__ == "__main__":
    raise SystemExit(main(["extract", *sys.argv[1:]]))
