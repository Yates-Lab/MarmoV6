"""Reproducible spectral check for the Acuity_Continuous optic-flow stimulus.

This is an ensemble screen-buffer surrogate, not a photometric measurement or
an exact reproduction of Psychtoolbox motion history. It mirrors the protocol's
dot density, dot-size mapping, background, contrast normalization, and
polarity-specific placement. Circular dots are rasterized with a supersampled
coverage kernel before FFT analysis.
"""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


LASER_WIDTH_PX = 2560
LASER_HEIGHT_PX = 1440
LASER_WIDTH_CM = 59.6
LASER_DISTANCE_CM = 46.0
BACKGROUND = 127.0
LEGACY_DOT_LEVEL = 1.0
N_DOTS = 2500
MIN_CPD = 11.0
MAX_CPD = 19.0
N_CPD = 6
BALANCED_CONTRAST = 1.0
RMS_EXPONENT = 1.0
MIN_SEPARATION_DEG = 0.75
PLACEMENT_ATTEMPTS = 50


def pixels_per_degree(distance_cm: float, width_cm: float, width_px: int) -> float:
    screen_deg = 2 * math.atan2(width_cm / 2, distance_cm) * 180 / math.pi
    return width_px / screen_deg


def disk_coverage_kernel(diameter_px: float, oversample: int = 32) -> np.ndarray:
    radius = diameter_px / 2
    half_width = max(2, math.ceil(radius + 1))
    coords = np.arange(-half_width, half_width + 1, dtype=float)
    offsets = (np.arange(oversample) + 0.5) / oversample - 0.5
    yy, xx, oy, ox = np.meshgrid(coords, coords, offsets, offsets, indexing="ij")
    return ((xx + ox) ** 2 + (yy + oy) ** 2 <= radius**2).mean(axis=(2, 3))


def kernel_fft(kernel: np.ndarray, size: int) -> np.ndarray:
    grid = np.zeros((size, size), dtype=float)
    kh, kw = kernel.shape
    y0 = (size - kh) // 2
    x0 = (size - kw) // 2
    grid[y0 : y0 + kh, x0 : x0 + kw] = kernel
    return np.fft.fft2(np.fft.ifftshift(grid))


def bilinear_impulses(
    size: int, x: np.ndarray, y: np.ndarray, weights: np.ndarray
) -> np.ndarray:
    image = np.zeros((size, size), dtype=float)
    x0 = np.floor(x).astype(int) % size
    y0 = np.floor(y).astype(int) % size
    fx = x - np.floor(x)
    fy = y - np.floor(y)
    for xo, yo, w in (
        (0, 0, (1 - fx) * (1 - fy)),
        (1, 0, fx * (1 - fy)),
        (0, 1, (1 - fx) * fy),
        (1, 1, fx * fy),
    ):
        np.add.at(image, ((y0 + yo) % size, (x0 + xo) % size), weights * w)
    return image


def polarity_blue_noise_positions(
    size: int,
    polarity: np.ndarray,
    min_distance_px: float,
    rng: np.random.Generator,
    attempts: int,
):
    """Sequential periodic best-candidate sampling within each polarity."""
    x = np.empty(len(polarity), dtype=float)
    y = np.empty(len(polarity), dtype=float)
    fallback_count = 0
    min_distance_squared = min_distance_px**2
    for index, sign in enumerate(polarity):
        candidates_x = rng.uniform(0, size, attempts)
        candidates_y = rng.uniform(0, size, attempts)
        previous = np.flatnonzero(polarity[:index] == sign)
        if len(previous) == 0:
            nearest_squared = np.full(attempts, np.inf)
        else:
            dx = np.abs(candidates_x[:, None] - x[previous][None, :])
            dy = np.abs(candidates_y[:, None] - y[previous][None, :])
            dx = np.minimum(dx, size - dx)
            dy = np.minimum(dy, size - dy)
            nearest_squared = np.min(dx**2 + dy**2, axis=1)
        valid = np.flatnonzero(nearest_squared >= min_distance_squared)
        if len(valid):
            selected = int(valid[0])
        else:
            selected = int(np.argmax(nearest_squared))
            fallback_count += 1
        x[index] = candidates_x[selected]
        y[index] = candidates_y[selected]
    return x, y, fallback_count


def radial_setup(size: int, pix_per_deg: float, bin_width: float = 0.25):
    freq = np.fft.fftshift(np.fft.fftfreq(size)) * pix_per_deg
    fy, fx = np.meshgrid(freq, freq, indexing="ij")
    radius = np.hypot(fx, fy)
    bins = np.floor(radius / bin_width).astype(int)
    n_bins = int(bins.max()) + 1
    counts = np.bincount(bins.ravel(), minlength=n_bins)
    centers = (np.arange(n_bins) + 0.5) * bin_width
    return radius, bins, counts, centers


def simulate(args: argparse.Namespace):
    rng = np.random.default_rng(args.seed)
    ppd = pixels_per_degree(LASER_DISTANCE_CM, LASER_WIDTH_CM, LASER_WIDTH_PX)
    cpds = np.geomspace(MIN_CPD, MAX_CPD, N_CPD)
    density = N_DOTS / (LASER_WIDTH_PX * LASER_HEIGHT_PX)
    patch_dots = max(2, round(density * args.patch_size**2))
    if patch_dots % 2:
        patch_dots += 1

    radial_freq, radial_bins, radial_counts, bin_centers = radial_setup(
        args.patch_size, ppd
    )
    valid_freq = radial_freq > 0
    modes = ("legacy_dark", "balanced_random", "acuity_clean")
    summary_rows = []
    spectrum_rows = []
    spectra = {mode: {} for mode in modes}

    balanced_delta = BALANCED_CONTRAST * min(BACKGROUND, 255 - BACKGROUND)

    for cpd in cpds:
        diameter = ppd / (2 * cpd)
        transfer = kernel_fft(disk_coverage_kernel(diameter), args.patch_size)
        accum = {
            mode: {
                "radial_sum": np.zeros_like(bin_centers),
                "mean": [],
                "rms": [],
                "band_power": np.zeros(4),
                "total_power": 0.0,
            }
            for mode in modes
        }

        for _ in range(args.frames):
            x = rng.uniform(0, args.patch_size, patch_dots)
            y = rng.uniform(0, args.patch_size, patch_dots)
            polarity = np.ones(patch_dots)
            polarity[patch_dots // 2 :] = -1
            rng.shuffle(polarity)
            clean_x, clean_y, fallback_count = polarity_blue_noise_positions(
                args.patch_size,
                polarity,
                MIN_SEPARATION_DEG * ppd,
                rng,
                PLACEMENT_ATTEMPTS,
            )

            impulses = {
                "legacy_dark": bilinear_impulses(
                    args.patch_size, x, y, np.ones(patch_dots)
                ),
                "balanced_random": bilinear_impulses(
                    args.patch_size, x, y, polarity
                ),
                "acuity_clean": bilinear_impulses(
                    args.patch_size, clean_x, clean_y, polarity
                ),
            }

            for mode in modes:
                coverage = np.fft.ifft2(np.fft.fft2(impulses[mode]) * transfer).real
                if mode == "legacy_dark":
                    frame = BACKGROUND + (LEGACY_DOT_LEVEL - BACKGROUND) * coverage
                elif mode == "balanced_random":
                    frame = BACKGROUND + balanced_delta * coverage
                else:
                    effective_delta = balanced_delta * (cpd / MAX_CPD) ** RMS_EXPONENT
                    frame = BACKGROUND + effective_delta * coverage
                frame = np.clip(frame, 0, 255)
                contrast_frame = (frame - BACKGROUND) / BACKGROUND
                centered = contrast_frame - contrast_frame.mean()
                power = np.abs(np.fft.fftshift(np.fft.fft2(centered))) ** 2
                power /= args.patch_size**4

                radial_sum = np.bincount(
                    radial_bins.ravel(), weights=power.ravel(), minlength=len(bin_centers)
                )
                accum[mode]["radial_sum"] += radial_sum
                accum[mode]["mean"].append(float(frame.mean()))
                accum[mode]["rms"].append(float(contrast_frame.std()))
                total = float(power[valid_freq].sum())
                accum[mode]["total_power"] += total
                accum[mode].setdefault("placement_fallbacks", 0)
                if mode == "acuity_clean":
                    accum[mode]["placement_fallbacks"] += fallback_count
                bands = ((0, 2), (2, 5), (5, 10), (10, np.inf))
                for band_index, (low, high) in enumerate(bands):
                    mask = valid_freq & (radial_freq >= low) & (radial_freq < high)
                    accum[mode]["band_power"][band_index] += float(power[mask].sum())

        for mode in modes:
            radial_density = accum[mode]["radial_sum"] / np.maximum(radial_counts, 1)
            radial_density /= args.frames
            spectra[mode][float(cpd)] = radial_density
            annular_power = accum[mode]["radial_sum"].copy()
            annular_power[0] = 0
            cumulative = np.cumsum(annular_power)
            median_sf = float(bin_centers[np.searchsorted(cumulative, cumulative[-1] / 2)])
            total_power = accum[mode]["total_power"]
            band_fraction = accum[mode]["band_power"] / total_power
            summary_rows.append(
                {
                    "mode": mode,
                    "nominal_cpd": float(cpd),
                    "dot_diameter_px": float(diameter),
                    "patch_dots": patch_dots,
                    "frames": args.frames,
                    "mean_luminance": float(np.mean(accum[mode]["mean"])),
                    "mean_shift": float(np.mean(accum[mode]["mean"]) - BACKGROUND),
                    "rms_contrast": float(np.mean(accum[mode]["rms"])),
                    "power_lt_2_cpd": float(band_fraction[0]),
                    "power_2_5_cpd": float(band_fraction[1]),
                    "power_5_10_cpd": float(band_fraction[2]),
                    "power_ge_10_cpd": float(band_fraction[3]),
                    "median_power_sf_cpd": median_sf,
                    "placement_fallbacks": int(
                        accum[mode].get("placement_fallbacks", 0)
                    ),
                }
            )
            normalized = radial_density / max(radial_density[1:].max(), np.finfo(float).eps)
            for sf, value in zip(bin_centers, normalized):
                spectrum_rows.append(
                    {
                        "mode": mode,
                        "nominal_cpd": float(cpd),
                        "sf_cpd": float(sf),
                        "normalized_power_density": float(value),
                    }
                )

    return ppd, cpds, summary_rows, spectrum_rows, spectra


def font(size: int, bold: bool = False):
    name = "arialbd.ttf" if bold else "arial.ttf"
    path = Path("C:/Windows/Fonts") / name
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def map_point(x, y, bounds, xlim, ylim):
    left, top, right, bottom = bounds
    px = left + (x - xlim[0]) / (xlim[1] - xlim[0]) * (right - left)
    py = bottom - (y - ylim[0]) / (ylim[1] - ylim[0]) * (bottom - top)
    return px, py


def axes(draw, bounds, xlim, ylim, title, subtitle, xlabel, ylabel, y_ticks):
    left, top, right, bottom = bounds
    ink = "#20242c"
    grid = "#dfe3e8"
    draw.text((left, top - 64), title, fill=ink, font=font(22, True))
    draw.text((left, top - 36), subtitle, fill="#5b6573", font=font(14))
    draw.line((left, top, left, bottom), fill=ink, width=2)
    draw.line((left, bottom, right, bottom), fill=ink, width=2)
    for value in y_ticks:
        _, py = map_point(xlim[0], value, bounds, xlim, ylim)
        draw.line((left, py, right, py), fill=grid, width=1)
        label = f"{value:g}"
        draw.text((left - 10, py), label, anchor="rm", fill=ink, font=font(12))
    for value in np.linspace(xlim[0], xlim[1], 5):
        px, _ = map_point(value, ylim[0], bounds, xlim, ylim)
        draw.line((px, bottom, px, bottom + 5), fill=ink, width=1)
        draw.text((px, bottom + 10), f"{value:g}", anchor="ma", fill=ink, font=font(12))
    draw.text(((left + right) / 2, bottom + 40), xlabel, anchor="ma", fill=ink, font=font(14))
    if ylabel:
        draw.text((left - 62, (top + bottom) / 2), ylabel, anchor="mm", fill=ink, font=font(14))


def line(draw, bounds, xs, ys, xlim, ylim, colour, width=3):
    points = [map_point(x, y, bounds, xlim, ylim) for x, y in zip(xs, ys)]
    draw.line(points, fill=colour, width=width, joint="curve")


def make_figure(path: Path, ppd, cpds, summary_rows, spectra, frames):
    image = Image.new("RGB", (1800, 1200), "#fbfcfd")
    draw = ImageDraw.Draw(image)
    draw.text((60, 28), "Acuity continuous: simulated spatial-frequency and luminance checks", fill="#20242c", font=font(30, True))
    draw.text(
        (60, 70),
        f"Laser geometry ({ppd:.2f} px/deg), {frames} frames/condition; antialiased circular-dot surrogate",
        fill="#5b6573",
        font=font(16),
    )

    bounds1 = (90, 190, 800, 520)
    bounds2 = (990, 190, 1700, 520)
    bounds3 = (90, 760, 800, 1090)
    bounds4 = (990, 760, 1700, 1090)
    axes(draw, bounds1, (0, 30), (-40, 1), "Radial power density", "Clean stimulus; normalized power in dB", "Spatial frequency (cpd)", "", [-40, -30, -20, -10, 0])
    blue_shades = ["#c9d9ee", "#a6c1e1", "#7fa5d1", "#5689c1", "#326eae", "#174f88"]
    for colour, cpd in zip(blue_shades, cpds):
        density = spectra["acuity_clean"][float(cpd)]
        normalized = density / max(density[1:].max(), np.finfo(float).eps)
        db = 10 * np.log10(np.maximum(normalized, 1e-4))
        sf = (np.arange(len(db)) + 0.5) * 0.25
        keep = sf <= 30
        line(draw, bounds1, sf[keep], db[keep], (0, 30), (-40, 1), colour, 3)
        x_label = 28
        y_label = float(np.interp(x_label, sf[keep], db[keep]))
        px, py = map_point(x_label, y_label, bounds1, (0, 30), (-40, 1))
        draw.text((px + 4, py), f"{cpd:.1f}", anchor="lm", fill=colour, font=font(11, True))

    by_mode = {
        mode: sorted((r for r in summary_rows if r["mode"] == mode), key=lambda r: r["nominal_cpd"])
        for mode in ("legacy_dark", "balanced_random", "acuity_clean")
    }
    axes(draw, bounds2, (10.5, 19.5), (0, 5), "Low-SF power", "Non-DC power below 2 cpd", "Nominal inverse-size condition", "", [0, 1, 2, 3, 4, 5])
    mode_colours = {
        "legacy_dark": "#8793a1",
        "balanced_random": "#d4822b",
        "acuity_clean": "#2f6fb0",
    }
    for mode in mode_colours:
        rows = by_mode[mode]
        xs = [r["nominal_cpd"] for r in rows]
        ys = [100 * r["power_lt_2_cpd"] for r in rows]
        line(draw, bounds2, xs, ys, (10.5, 19.5), (0, 5), mode_colours[mode], 4)
        for x, y in zip(xs, ys):
            px, py = map_point(x, y, bounds2, (10.5, 19.5), (0, 5))
            draw.ellipse((px - 4, py - 4, px + 4, py + 4), fill=mode_colours[mode])

    axes(draw, bounds3, (10.5, 19.5), (0, 3), "RMS contrast", "Percent contrast across simulated frames", "Nominal inverse-size condition", "", [0, 0.5, 1, 1.5, 2, 2.5, 3])
    for mode in mode_colours:
        rows = by_mode[mode]
        xs = [r["nominal_cpd"] for r in rows]
        ys = [100 * r["rms_contrast"] for r in rows]
        line(draw, bounds3, xs, ys, (10.5, 19.5), (0, 3), mode_colours[mode], 4)
        for x, y in zip(xs, ys):
            px, py = map_point(x, y, bounds3, (10.5, 19.5), (0, 3))
            draw.ellipse((px - 4, py - 4, px + 4, py + 4), fill=mode_colours[mode])

    axes(draw, bounds4, (10.5, 19.5), (126.5, 127.1), "Frame mean luminance", "Digital level; background reference = 127", "Nominal inverse-size condition", "", [126.5, 126.6, 126.7, 126.8, 126.9, 127.0, 127.1])
    line(draw, bounds4, [10.5, 19.5], [127, 127], (10.5, 19.5), (126.5, 127.1), "#68717d", 2)
    for mode in mode_colours:
        rows = by_mode[mode]
        xs = [r["nominal_cpd"] for r in rows]
        ys = [r["mean_luminance"] for r in rows]
        line(draw, bounds4, xs, ys, (10.5, 19.5), (126.5, 127.1), mode_colours[mode], 4)
        for x, y in zip(xs, ys):
            px, py = map_point(x, y, bounds4, (10.5, 19.5), (126.5, 127.1))
            draw.ellipse((px - 4, py - 4, px + 4, py + 4), fill=mode_colours[mode])

    legend_y = 650
    legend_labels = {
        "legacy_dark": "Legacy dark/random",
        "balanced_random": "Balanced/random",
        "acuity_clean": "Clean: balanced + RMS + min-distance",
    }
    for index, mode in enumerate(mode_colours):
        x = 350 + index * 430
        draw.line((x, legend_y, x + 35, legend_y), fill=mode_colours[mode], width=5)
        draw.text((x + 45, legend_y), legend_labels[mode], anchor="lm", fill="#20242c", font=font(14, True))
    image.save(path)


def write_csv(path: Path, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def validate_summary(summary_rows):
    clean = sorted(
        (row for row in summary_rows if row["mode"] == "acuity_clean"),
        key=lambda row: row["nominal_cpd"],
    )
    random_balanced = sorted(
        (row for row in summary_rows if row["mode"] == "balanced_random"),
        key=lambda row: row["nominal_cpd"],
    )
    rms = np.array([row["rms_contrast"] for row in clean])
    checks = {
        "balanced_mean": max(abs(row["mean_shift"]) for row in clean) < 1e-3,
        "rms_range_within_8_percent": rms.max() / rms.min() < 1.08,
        "low_sf_not_increased": all(
            clean_row["power_lt_2_cpd"] <= random_row["power_lt_2_cpd"]
            for clean_row, random_row in zip(clean, random_balanced)
        ),
        "placement_constraints_feasible": all(
            row["placement_fallbacks"] == 0 for row in clean
        ),
        "dot_diameter_monotonic": all(
            clean[index]["dot_diameter_px"] > clean[index + 1]["dot_diameter_px"]
            for index in range(len(clean) - 1)
        ),
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise RuntimeError("Validation failed: " + ", ".join(failed))
    return checks


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--frames", type=int, default=128)
    parser.add_argument("--patch-size", type=int, default=512)
    parser.add_argument("--seed", type=int, default=20260829)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("Output") / "AcuitySpectrum",
    )
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    ppd, cpds, summary, spectrum, spectra = simulate(args)
    checks = validate_summary(summary)
    write_csv(args.output_dir / "opticflow_spectrum_summary.csv", summary)
    write_csv(args.output_dir / "opticflow_radial_spectra.csv", spectrum)
    make_figure(
        args.output_dir / "opticflow_spectrum_validation.png",
        ppd,
        cpds,
        summary,
        spectra,
        args.frames,
    )
    print(f"pix_per_degree={ppd:.6f}")
    print(f"dot_diameters_px={[round(ppd/(2*c), 4) for c in cpds]}")
    for row in summary:
        print(
            row["mode"],
            f"cpd={row['nominal_cpd']:.3f}",
            f"mean={row['mean_luminance']:.5f}",
            f"rms={row['rms_contrast']:.5f}",
            f"low_sf={100*row['power_lt_2_cpd']:.3f}%",
            f"median_sf={row['median_power_sf_cpd']:.3f}",
        )
    print("SPECTRAL_VALIDATION_CHECKS_PASS", ",".join(checks))


if __name__ == "__main__":
    main()
