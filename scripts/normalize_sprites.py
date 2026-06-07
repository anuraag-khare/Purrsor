#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path

import cv2
import numpy as np


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
    def center_y(self) -> float:
        return self.y + (self.height / 2.0)

    @property
    def bottom(self) -> float:
        return self.y + self.height


@dataclass
class SpriteReport:
    name: str
    source_size: tuple[int, int]
    alpha_bounds: Bounds
    body_bounds: Bounds
    scale_applied: float
    canvas_size: tuple[int, int]
    output_path: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Normalize desktop pet sprite poses to a consistent body scale."
    )
    parser.add_argument("input_dir", type=Path, help="Directory containing source PNG sprites.")
    parser.add_argument("output_dir", type=Path, help="Directory to write normalized PNG sprites.")
    parser.add_argument(
        "--reference",
        default="idle.PNG",
        help="Reference sprite filename used for body scale and baseline alignment.",
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
        default=46,
        help="Max RGB brightness used to treat pixels as cat body.",
    )
    parser.add_argument(
        "--canvas-width",
        type=int,
        default=0,
        help="Optional output canvas width. Defaults to the widest input.",
    )
    parser.add_argument(
        "--canvas-height",
        type=int,
        default=0,
        help="Optional output canvas height. Defaults to the tallest input.",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=None,
        help="Optional JSON report path.",
    )
    parser.add_argument(
        "--metadata-out",
        type=Path,
        default=None,
        help="Optional sprite metadata JSON path for the macOS app.",
    )
    parser.add_argument(
        "--resource-prefix",
        default="cat-",
        help="Prefix used when generating metadata frame keys.",
    )
    return parser.parse_args()


def png_files(input_dir: Path) -> list[Path]:
    return sorted(
        path for path in input_dir.iterdir() if path.is_file() and path.suffix.lower() == ".png"
    )


def load_bgra(path: Path) -> np.ndarray:
    image = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if image is None:
        raise ValueError(f"Failed to read image: {path}")
    if image.ndim != 3 or image.shape[2] != 4:
        raise ValueError(f"Expected transparent PNG with alpha channel: {path}")
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


def fit_scale(
    source_image: np.ndarray,
    alpha_bounds: Bounds,
    body_bounds: Bounds,
    target_body: Bounds,
    canvas_width: int,
    canvas_height: int,
) -> float:
    del source_image

    height_scale = target_body.height / max(1.0, body_bounds.height)
    width_scale = target_body.width / max(1.0, body_bounds.width)
    preferred_scale = min(height_scale, width_scale)

    alpha_x0 = alpha_bounds.x - body_bounds.center_x
    alpha_x1 = alpha_bounds.x + alpha_bounds.width - body_bounds.center_x
    alpha_y0 = alpha_bounds.y - body_bounds.bottom
    alpha_y1 = alpha_bounds.y + alpha_bounds.height - body_bounds.bottom

    max_width_scale = canvas_width / max(1.0, alpha_x1 - alpha_x0)
    max_height_scale = canvas_height / max(1.0, alpha_y1 - alpha_y0)
    return float(max(0.05, min(preferred_scale, max_width_scale, max_height_scale)))


def transform_sprite(
    image: np.ndarray,
    alpha_bounds: Bounds,
    body_bounds: Bounds,
    target_body: Bounds,
    canvas_width: int,
    canvas_height: int,
) -> tuple[np.ndarray, float]:
    scale = fit_scale(
        source_image=image,
        alpha_bounds=alpha_bounds,
        body_bounds=body_bounds,
        target_body=target_body,
        canvas_width=canvas_width,
        canvas_height=canvas_height,
    )

    scaled = cv2.resize(
        image,
        dsize=(
            max(1, int(round(image.shape[1] * scale))),
            max(1, int(round(image.shape[0] * scale))),
        ),
        interpolation=cv2.INTER_NEAREST,
    )

    scaled_body = Bounds(
        x=int(round(body_bounds.x * scale)),
        y=int(round(body_bounds.y * scale)),
        width=int(round(body_bounds.width * scale)),
        height=int(round(body_bounds.height * scale)),
    )

    target_center_x = target_body.center_x
    target_bottom = target_body.bottom

    body_center_x = scaled_body.center_x
    body_bottom = scaled_body.bottom

    offset_x = int(round(target_center_x - body_center_x))
    offset_y = int(round(target_bottom - body_bottom))

    canvas = np.zeros((canvas_height, canvas_width, 4), dtype=np.uint8)

    src_x0 = max(0, -offset_x)
    src_y0 = max(0, -offset_y)
    dst_x0 = max(0, offset_x)
    dst_y0 = max(0, offset_y)

    copy_width = min(scaled.shape[1] - src_x0, canvas_width - dst_x0)
    copy_height = min(scaled.shape[0] - src_y0, canvas_height - dst_y0)

    if copy_width <= 0 or copy_height <= 0:
        raise ValueError("Normalized sprite falls outside output canvas.")

    canvas[
        dst_y0 : dst_y0 + copy_height,
        dst_x0 : dst_x0 + copy_width,
    ] = scaled[
        src_y0 : src_y0 + copy_height,
        src_x0 : src_x0 + copy_width,
    ]

    return canvas, scale


def detect_eye_sockets(
    image: np.ndarray,
    alpha_threshold: int,
    body_bounds: Bounds,
) -> list[Bounds]:
    alpha_mask = image[:, :, 3] > alpha_threshold
    bgr = image[:, :, :3]
    white_mask = alpha_mask & (np.min(bgr, axis=2) >= 240)
    component_count, _, stats, _ = cv2.connectedComponentsWithStats(
        white_mask.astype(np.uint8),
        8,
    )

    body_area = body_bounds.width * body_bounds.height
    left_candidates: list[tuple[float, int, Bounds]] = []
    right_candidates: list[tuple[float, int, Bounds]] = []

    for label in range(1, component_count):
        x, y, width, height, area = (int(value) for value in stats[label])
        if area < max(120, int(round(body_area * 0.0015))):
            continue
        if area > int(round(body_area * 0.02)):
            continue
        if height < width * 1.35:
            continue

        center_x = x + (width / 2.0)
        center_y = y + (height / 2.0)
        relative_x = (center_x - body_bounds.x) / max(1.0, body_bounds.width)
        relative_y = (center_y - body_bounds.y) / max(1.0, body_bounds.height)

        if not (0.14 <= relative_x <= 0.86 and 0.18 <= relative_y <= 0.58):
            continue
        if width > body_bounds.width * 0.12 or height > body_bounds.height * 0.18:
            continue

        bounds = Bounds(x=x, y=y, width=width, height=height)
        if center_x < body_bounds.center_x:
            score = abs(relative_x - 0.28) + abs(relative_y - 0.40)
            left_candidates.append((score, -area, bounds))
        else:
            score = abs(relative_x - 0.72) + abs(relative_y - 0.40)
            right_candidates.append((score, -area, bounds))

    if not left_candidates or not right_candidates:
        return []

    left = sorted(left_candidates, key=lambda candidate: (candidate[0], candidate[1]))[0][2]
    right = sorted(right_candidates, key=lambda candidate: (candidate[0], candidate[1]))[0][2]
    return sorted([left, right], key=lambda candidate: candidate.x)


def rect_payload(bounds: Bounds) -> dict[str, int]:
    return {
        "x": bounds.x,
        "y": bounds.y,
        "width": bounds.width,
        "height": bounds.height,
    }


def to_appkit_rect(bounds: Bounds, canvas_height: int) -> dict[str, int]:
    return {
        "x": bounds.x,
        "y": canvas_height - (bounds.y + bounds.height),
        "width": bounds.width,
        "height": bounds.height,
    }


def main() -> int:
    args = parse_args()
    input_dir: Path = args.input_dir.expanduser().resolve()
    output_dir: Path = args.output_dir.expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    files = png_files(input_dir)
    if not files:
        raise SystemExit(f"No PNG files found in {input_dir}")

    images = {path.name: load_bgra(path) for path in files}
    bounds = {
        name: detect_bounds(image, args.alpha_threshold, args.body_brightness_threshold)
        for name, image in images.items()
    }

    if args.reference not in images:
        raise SystemExit(f"Reference sprite not found: {args.reference}")

    canvas_width = args.canvas_width or max(image.shape[1] for image in images.values())
    canvas_height = args.canvas_height or max(image.shape[0] for image in images.values())

    _, reference_body = bounds[args.reference]
    target_body = Bounds(
        x=int(round((canvas_width / 2.0) - (reference_body.width / 2.0))),
        y=int(round(canvas_height - reference_body.height - 140)),
        width=reference_body.width,
        height=reference_body.height,
    )

    reports: list[SpriteReport] = []
    metadata_frames: dict[str, dict[str, list[dict[str, int]]]] = {}

    for name, image in images.items():
        alpha_bounds, body_bounds = bounds[name]
        normalized, scale = transform_sprite(
            image=image,
            alpha_bounds=alpha_bounds,
            body_bounds=body_bounds,
            target_body=target_body,
            canvas_width=canvas_width,
            canvas_height=canvas_height,
        )
        output_path = output_dir / name
        cv2.imwrite(str(output_path), normalized)

        _, normalized_body_bounds = detect_bounds(
            normalized,
            args.alpha_threshold,
            args.body_brightness_threshold,
        )
        eye_sockets = detect_eye_sockets(
            normalized,
            args.alpha_threshold,
            normalized_body_bounds,
        )
        resource_name = f"{args.resource_prefix}{Path(name).stem.lower()}"
        metadata_frames[resource_name] = {
            "eyeSocketsTopLeft": [rect_payload(socket) for socket in eye_sockets]
        }

        reports.append(
            SpriteReport(
                name=name,
                source_size=(int(image.shape[1]), int(image.shape[0])),
                alpha_bounds=alpha_bounds,
                body_bounds=body_bounds,
                scale_applied=scale,
                canvas_size=(canvas_width, canvas_height),
                output_path=str(output_path),
            )
        )

    if args.report:
        report_path = args.report.expanduser().resolve()
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
            "layoutRect": to_appkit_rect(target_body, canvas_height),
            "frames": metadata_frames,
        }
        metadata_path.write_text(
            json.dumps(metadata_payload, indent=2),
            encoding="utf-8",
        )

    print(f"Normalized {len(reports)} sprites into {output_dir}")
    if args.report:
        print(f"Report written to {args.report.expanduser().resolve()}")
    if args.metadata_out:
        print(f"Metadata written to {args.metadata_out.expanduser().resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
