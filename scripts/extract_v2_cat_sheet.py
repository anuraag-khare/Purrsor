#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path

import cv2
import numpy as np


POSE_NAMES = [
    "idle",
    "blink",
    "typing",
    "petting",
    "stretch",
    "overheated",
]


@dataclass
class Bounds:
    x: int
    y: int
    width: int
    height: int

    @property
    def center_x(self) -> float:
        return self.x + (self.width / 2.0)

    @property
    def bottom(self) -> float:
        return self.y + self.height


@dataclass
class PoseReport:
    pose: str
    cell_bounds: Bounds
    alpha_bounds: Bounds
    body_bounds: Bounds
    output_path: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract equal-crop v2 cat poses from a 3x2 sprite sheet.",
    )
    parser.add_argument("input_png", type=Path, help="Path to the source sprite sheet PNG.")
    parser.add_argument("output_dir", type=Path, help="Directory to write extracted pose PNGs.")
    parser.add_argument(
        "--metadata-out",
        type=Path,
        default=None,
        help="Optional metadata JSON path for the macOS app.",
    )
    parser.add_argument(
        "--report-out",
        type=Path,
        default=None,
        help="Optional JSON report path.",
    )
    parser.add_argument(
        "--resource-prefix",
        default="cat-v2",
        help="Resource prefix used for generated PNG and metadata frame names.",
    )
    parser.add_argument(
        "--alpha-threshold",
        type=int,
        default=8,
        help="Alpha threshold used to detect visible pixels.",
    )
    parser.add_argument(
        "--body-brightness-threshold",
        type=int,
        default=52,
        help="Max RGB brightness treated as cat body when estimating the common layout slot.",
    )
    return parser.parse_args()


def load_rgba(path: Path) -> np.ndarray:
    image = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if image is None:
        raise ValueError(f"Failed to read image: {path}")
    if image.ndim != 3 or image.shape[2] != 4:
        raise ValueError(f"Expected RGBA sprite sheet: {path}")
    return image


def bounds_from_mask(mask: np.ndarray) -> Bounds:
    ys, xs = np.where(mask)
    if len(xs) == 0 or len(ys) == 0:
        raise ValueError("Mask does not contain any foreground pixels.")
    min_x = int(xs.min())
    max_x = int(xs.max())
    min_y = int(ys.min())
    max_y = int(ys.max())
    return Bounds(
        x=min_x,
        y=min_y,
        width=(max_x - min_x) + 1,
        height=(max_y - min_y) + 1,
    )


def largest_component(mask: np.ndarray) -> np.ndarray:
    component_count, labels, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
    if component_count <= 1:
        return mask

    largest_label = 1
    largest_area = 0
    for label in range(1, component_count):
        area = stats[label, cv2.CC_STAT_AREA]
        if area > largest_area:
            largest_area = int(area)
            largest_label = label

    return labels == largest_label


def detect_bounds(
    image: np.ndarray,
    alpha_threshold: int,
    body_brightness_threshold: int,
) -> tuple[Bounds, Bounds]:
    alpha_mask = image[:, :, 3] > alpha_threshold
    alpha_bounds = bounds_from_mask(alpha_mask)

    bgr = image[:, :, :3]
    brightness = np.max(bgr, axis=2)
    body_mask = alpha_mask & (brightness <= body_brightness_threshold)
    if np.count_nonzero(body_mask) == 0:
        body_mask = alpha_mask
    body_mask = largest_component(body_mask)
    body_bounds = bounds_from_mask(body_mask)
    return alpha_bounds, body_bounds


def slice_cells(image: np.ndarray) -> list[tuple[Bounds, np.ndarray]]:
    height, width = image.shape[:2]
    if width % 3 != 0 or height % 2 != 0:
        raise ValueError(f"Expected a 3x2 sheet with even cells, got {width}x{height}")

    cell_width = width // 3
    cell_height = height // 2
    cells: list[tuple[Bounds, np.ndarray]] = []

    for row in range(2):
        for col in range(3):
            x = col * cell_width
            y = row * cell_height
            cell_bounds = Bounds(x=x, y=y, width=cell_width, height=cell_height)
            cell = image[y : y + cell_height, x : x + cell_width].copy()
            cells.append((cell_bounds, cell))

    return cells


def align_to_reference(
    cell_image: np.ndarray,
    body_bounds: Bounds,
    reference_body: Bounds,
) -> np.ndarray:
    canvas_height, canvas_width = cell_image.shape[:2]
    offset_x = int(round(reference_body.center_x - body_bounds.center_x))
    offset_y = int(round(reference_body.bottom - body_bounds.bottom))

    aligned = np.zeros_like(cell_image)

    src_x0 = max(0, -offset_x)
    src_y0 = max(0, -offset_y)
    dst_x0 = max(0, offset_x)
    dst_y0 = max(0, offset_y)

    copy_width = min(canvas_width - src_x0, canvas_width - dst_x0)
    copy_height = min(canvas_height - src_y0, canvas_height - dst_y0)

    if copy_width <= 0 or copy_height <= 0:
        raise ValueError("Aligned pose falls outside the cell canvas.")

    aligned[
        dst_y0 : dst_y0 + copy_height,
        dst_x0 : dst_x0 + copy_width,
    ] = cell_image[
        src_y0 : src_y0 + copy_height,
        src_x0 : src_x0 + copy_width,
    ]

    return aligned


def to_appkit_rect(bounds: Bounds, canvas_height: int) -> dict[str, int]:
    return {
        "x": bounds.x,
        "y": canvas_height - (bounds.y + bounds.height),
        "width": bounds.width,
        "height": bounds.height,
    }


def main() -> int:
    args = parse_args()
    input_png = args.input_png.expanduser().resolve()
    output_dir = args.output_dir.expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    image = load_rgba(input_png)
    cells = slice_cells(image)

    if len(cells) != len(POSE_NAMES):
        raise SystemExit(f"Expected {len(POSE_NAMES)} cells, found {len(cells)}")

    canvas_height = cells[0][0].height
    canvas_width = cells[0][0].width
    _, reference_body = detect_bounds(
        cells[0][1],
        args.alpha_threshold,
        args.body_brightness_threshold,
    )
    reports: list[PoseReport] = []

    for (pose, (cell_bounds, cell_image)) in zip(POSE_NAMES, cells, strict=True):
        _, body_bounds = detect_bounds(
            cell_image,
            args.alpha_threshold,
            args.body_brightness_threshold,
        )
        aligned_image = align_to_reference(cell_image, body_bounds, reference_body)
        alpha_bounds, normalized_body_bounds = detect_bounds(
            aligned_image,
            args.alpha_threshold,
            args.body_brightness_threshold,
        )

        output_path = output_dir / f"{args.resource_prefix}-{pose}.png"
        cv2.imwrite(str(output_path), aligned_image)
        reports.append(
            PoseReport(
                pose=pose,
                cell_bounds=cell_bounds,
                alpha_bounds=alpha_bounds,
                body_bounds=normalized_body_bounds,
                output_path=str(output_path),
            )
        )

    if args.report_out:
        report_path = args.report_out.expanduser().resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            json.dumps([asdict(report) for report in reports], indent=2),
            encoding="utf-8",
        )

    if args.metadata_out:
        metadata_path = args.metadata_out.expanduser().resolve()
        metadata_path.parent.mkdir(parents=True, exist_ok=True)
        metadata_payload = {
            "version": 1,
            "canvasSize": {
                "width": canvas_width,
                "height": canvas_height,
            },
            "layoutRect": to_appkit_rect(reference_body, canvas_height),
            "frames": {
                f"{args.resource_prefix}-{pose}": {"eyeSocketsTopLeft": []}
                for pose in POSE_NAMES
            },
        }
        metadata_path.write_text(
            json.dumps(metadata_payload, indent=2),
            encoding="utf-8",
        )

    print(f"Extracted {len(reports)} poses into {output_dir}")
    if args.metadata_out:
        print(f"Metadata written to {args.metadata_out.expanduser().resolve()}")
    if args.report_out:
        print(f"Report written to {args.report_out.expanduser().resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
