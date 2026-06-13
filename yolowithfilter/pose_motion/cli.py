import argparse
from pathlib import Path

from .config import AnalysisConfig, ExtractionConfig, PipelineConfig, ScaleConfig
from .constants import ALL_KEYPOINTS_FILENAME, HIP_POSITIONS_FILENAME, SELECTED_SCALE_FILENAME
from .pipeline import run_pipeline, save_analysis, save_pose_data, save_scale

DEFAULT_EXTRACTION = ExtractionConfig()
DEFAULT_SCALE = ScaleConfig()
DEFAULT_ANALYSIS = AnalysisConfig()


def _scale_config(args: argparse.Namespace) -> ScaleConfig:
    return ScaleConfig(
        height_m=args.height,
        shoulder_ankle_ratio=args.shoulder_ankle_ratio,
        window_size=args.scale_window,
    )


def _analysis_config(args: argparse.Namespace) -> AnalysisConfig:
    return AnalysisConfig(
        position_cutoff_hz=args.position_cutoff,
        velocity_cutoff_hz=args.velocity_cutoff,
        acceleration_cutoff_hz=args.acceleration_cutoff,
        filter_order=args.filter_order,
        invert_vertical_axis=not args.keep_image_axis,
    )


def _add_scale_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--height", type=float, default=DEFAULT_SCALE.height_m, help="Subject height in meters"
    )
    parser.add_argument(
        "--shoulder-ankle-ratio", type=float, default=DEFAULT_SCALE.shoulder_ankle_ratio
    )
    parser.add_argument("--scale-window", type=int, default=DEFAULT_SCALE.window_size)


def _add_analysis_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--position-cutoff", type=float, default=DEFAULT_ANALYSIS.position_cutoff_hz)
    parser.add_argument("--velocity-cutoff", type=float, default=DEFAULT_ANALYSIS.velocity_cutoff_hz)
    parser.add_argument(
        "--acceleration-cutoff", type=float, default=DEFAULT_ANALYSIS.acceleration_cutoff_hz
    )
    parser.add_argument("--filter-order", type=int, default=DEFAULT_ANALYSIS.filter_order)
    parser.add_argument("--keep-image-axis", action="store_true")
    parser.add_argument("--show-plot", action="store_true")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="YOLO pose-based vertical motion analysis")
    subparsers = parser.add_subparsers(dest="command", required=True)

    run = subparsers.add_parser("run", help="Run the complete pipeline")
    run.add_argument("video", type=Path)
    run.add_argument("-o", "--output-dir", type=Path, default=Path("."))
    run.add_argument("--model", type=Path, default=DEFAULT_EXTRACTION.model_path)
    run.add_argument("--confidence", type=float, default=DEFAULT_EXTRACTION.confidence_threshold)
    run.add_argument("--person-index", type=int, default=DEFAULT_EXTRACTION.person_index)
    _add_scale_options(run)
    _add_analysis_options(run)

    extract = subparsers.add_parser("extract", help="Extract pose data from a video")
    extract.add_argument("video", type=Path)
    extract.add_argument("-o", "--output-dir", type=Path, default=Path("."))
    extract.add_argument("--model", type=Path, default=DEFAULT_EXTRACTION.model_path)
    extract.add_argument("--confidence", type=float, default=DEFAULT_EXTRACTION.confidence_threshold)
    extract.add_argument("--person-index", type=int, default=DEFAULT_EXTRACTION.person_index)
    _add_scale_options(extract)

    scale = subparsers.add_parser("scale", help="Estimate scale from extracted keypoints")
    scale.add_argument("--keypoints", type=Path, default=Path(ALL_KEYPOINTS_FILENAME))
    scale.add_argument("-o", "--output", type=Path, default=Path(SELECTED_SCALE_FILENAME))
    _add_scale_options(scale)

    analyze = subparsers.add_parser("analyze", help="Calculate velocity and acceleration")
    analyze.add_argument("--hips", type=Path, default=Path(HIP_POSITIONS_FILENAME))
    analyze.add_argument("--scale", type=Path, default=Path(SELECTED_SCALE_FILENAME))
    analyze.add_argument("-o", "--output-dir", type=Path, default=Path("."))
    _add_analysis_options(analyze)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "run":
        paths = run_pipeline(
            PipelineConfig(
                video_path=args.video,
                output_dir=args.output_dir,
                extraction=ExtractionConfig(
                    model_path=args.model,
                    confidence_threshold=args.confidence,
                    person_index=args.person_index,
                ),
                scale=_scale_config(args),
                analysis=_analysis_config(args),
                show_plot=args.show_plot,
            )
        )
        for path in paths.values():
            print(f"Saved: {path}")
    elif args.command == "extract":
        save_pose_data(
            args.video,
            args.output_dir,
            ExtractionConfig(
                model_path=args.model,
                confidence_threshold=args.confidence,
                person_index=args.person_index,
            ),
            _scale_config(args),
        )
    elif args.command == "scale":
        result = save_scale(args.keypoints, args.output, _scale_config(args))
        print(result.to_string(index=False))
    elif args.command == "analyze":
        save_analysis(
            args.hips,
            args.scale,
            args.output_dir,
            _analysis_config(args),
            args.show_plot,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
