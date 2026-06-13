"""Backward-compatible complete pipeline entry point."""

import sys

from pose_motion.cli import main


if __name__ == "__main__":
    raise SystemExit(main(["run", *sys.argv[1:]]))
