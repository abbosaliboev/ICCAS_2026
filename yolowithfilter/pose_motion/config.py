from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class ExtractionConfig:
    model_path: Path = Path("yolo11n-pose.pt")
    confidence_threshold: float = 0.5
    person_index: int = 0


@dataclass(frozen=True)
class ScaleConfig:
    height_m: float = 1.84
    shoulder_ankle_ratio: float = 0.867
    window_size: int = 30
    time_weight: float = 3.0
    length_weight: float = 2.0
    ratio_weight: float = 1.0

    @property
    def shoulder_ankle_length_m(self) -> float:
        return self.height_m * self.shoulder_ankle_ratio


@dataclass(frozen=True)
class AnalysisConfig:
    position_cutoff_hz: float = 5.0
    velocity_cutoff_hz: float = 10.0
    acceleration_cutoff_hz: float = 8.0
    filter_order: int = 4
    invert_vertical_axis: bool = True


@dataclass(frozen=True)
class PipelineConfig:
    video_path: Path
    output_dir: Path = Path(".")
    extraction: ExtractionConfig = field(default_factory=ExtractionConfig)
    scale: ScaleConfig = field(default_factory=ScaleConfig)
    analysis: AnalysisConfig = field(default_factory=AnalysisConfig)
    show_plot: bool = False

    def output_path(self, filename: str) -> Path:
        return self.output_dir / filename
