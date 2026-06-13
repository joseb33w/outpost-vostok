#!/usr/bin/env python3
"""Generate the two seamless ground/structure textures (snow, metal panel) the
arena materials triplanar-tile. Self-contained (numpy + Pillow) so the build never
depends on a flaky texture CDN. Output: textures/snow.png, textures/metal_panel.png.
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "textures")
os.makedirs(OUT, exist_ok=True)
N = 256
rng = np.random.default_rng(20260613)


def _smooth_noise(size: int, octaves=(4, 8, 16, 32), seed=0) -> np.ndarray:
    """Tileable fractal value-noise in [0,1] (low-res lattices upsampled + wrapped)."""
    r = np.random.default_rng(seed)
    acc = np.zeros((size, size), np.float32)
    amp = 1.0
    total = 0.0
    for cells in octaves:
        base = r.random((cells, cells), np.float32)
        # tile the lattice by one cell so bilinear upsample wraps seamlessly
        tiled = np.zeros((cells + 1, cells + 1), np.float32)
        tiled[:cells, :cells] = base
        tiled[cells, :cells] = base[0, :]
        tiled[:cells, cells] = base[:, 0]
        tiled[cells, cells] = base[0, 0]
        img = Image.fromarray((tiled * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        acc += amp * (np.asarray(img, np.float32) / 255.0)
        total += amp
        amp *= 0.5
    acc /= total
    acc -= acc.min()
    acc /= max(acc.max(), 1e-6)
    return acc


def save(arr_rgb: np.ndarray, name: str) -> None:
    Image.fromarray(np.clip(arr_rgb, 0, 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name))
    print("wrote", name)


# ── snow: cold blue-white, soft fractal undulation + a few sparkle speckles ──
n = _smooth_noise(N, seed=11)
base = np.array([232, 238, 250], np.float32)
shade = np.array([200, 212, 234], np.float32)
snow = base[None, None, :] * n[..., None] + shade[None, None, :] * (1.0 - n[..., None])
sparkle = (rng.random((N, N)) > 0.992).astype(np.float32)
snow += sparkle[..., None] * 22.0
save(snow, "snow.png")

# ── metal panel: dark steel base + fractal grime + recessed seams on a grid ──
m = _smooth_noise(N, seed=29)
base_m = np.array([78, 86, 96], np.float32)
metal = base_m[None, None, :] * (0.82 + 0.36 * m[..., None])
ii, jj = np.meshgrid(np.arange(N), np.arange(N), indexing="ij")
seam = ((ii % 64 < 2) | (jj % 64 < 2)).astype(np.float32)        # recessed panel lines
bolt = (((ii % 64 - 8) ** 2 + (jj % 64 - 8) ** 2) < 6).astype(np.float32)  # corner bolts
metal *= (1.0 - 0.42 * seam[..., None])
metal += bolt[..., None] * 26.0
save(metal, "metal_panel.png")
