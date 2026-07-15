"""Build drift baseline artifact from SisFall training features."""

from __future__ import annotations

import argparse
from pathlib import Path

from api.inference.drift import DriftMonitor, DEFAULT_BASELINE_CSV, BASELINE_ARTIFACT


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", default=str(DEFAULT_BASELINE_CSV))
    parser.add_argument("--out", default=str(BASELINE_ARTIFACT))
    args = parser.parse_args()

    monitor = DriftMonitor(
        baseline_csv=Path(args.data),
        baseline_artifact=Path(args.out + ".tmp"),
    )
    monitor._persist_baseline(Path(args.out))
    print(f"OK drift baseline: {len(monitor.feature_names)} features → {args.out}")


if __name__ == "__main__":
    main()
