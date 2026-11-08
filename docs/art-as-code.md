# Art as code

Models, textures and sprites are Python scripts that **Blender runs on the GPU box**. They are text, so they diff, review and merge like code. A change is a commit, and every result can be traced to the commit that made it.

The loop:
1. Edit a script.
2. Commit it.
3. Run `scripts/delegate.sh <job> <name>`.
4. **Look at the preview** it brings back.
5. Copy the asset into the game and commit it.

Never run these scripts with a Blender on the laptop: versions differ, and the scripts expect the GPU box's Blender.

## 3D models: `art-src/models/<name>.py`

Each script builds one scene from the helpers in `common.py` and ends with `finish(out_path())`:

```python
"""Wooden chair (about 0.9 m)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()                                                  # empty scene
wood = mat("Wood", "#8A5A33", roughness=0.6)             # name, sRGB hex, metallic=, roughness=, emission=, strength=
root = empty("Chair")                                    # every part hangs off one root
box("Seat", (0.45, 0.45, 0.04), (0, 0, 0.45), wood, root, bevel=0.01)
for x in (-0.2, 0.2):
    for y in (-0.2, 0.2):
        cyl(f"Leg_{x}_{y}", 0.02, 0.45, (x, y, 0.225), wood, root, verts=12)
box("Back", (0.45, 0.03, 0.45), (0, 0.21, 0.7), wood, root, bevel=0.01)

finish(out_path())    # build/models/chair.glb + chair_preview.png
```

Build it with `scripts/delegate.sh models chair`.

**Helpers** (all in `common.py`):

| Helper | Makes |
|---|---|
| `reset()` | An empty scene |
| `mat(name, "#RRGGBB", metallic, roughness, emission, strength)` | A Principled material. Hex colours are sRGB; the conversion is done for you, and one material is shared per name |
| `empty(name, loc, parent)` | A joint or root. Its origin is the pivot Godot will rotate around |
| `box`, `cyl`, `cone`, `sphere`, `torus`, `ico` | Primitives with size, location, material, parent, rotation, and `bevel=` / `verts=` options |
| `polygon(name, verts, material, thickness=)` | A flat shape from 2D points, thickened |
| `finish(path, direction=…, size=…)` | Exports `.glb` and renders `<name>_preview.png` |
| `device()`, `cpu_only()` | Which Cycles device the preview uses (`--cpu` → CPU) |

**Conventions:**
- Units are metres, Blender's Z is up, and the model's **front faces −Y** (it ends up facing +Z in Godot).
- Moving parts (a door, a lid, an arm) are parented to an `empty` placed **at the hinge**, so the game rotates the empty.
- An object whose name ends in **`-convcolonly`** becomes only a convex collision shape in Godot. Use simple boxes around the model for collision.
- Keep polygon counts modest, and the preview size small, if the GPU is shared.

**In Godot:** copy `build/models/<name>.glb` into your project, for example `mygame/assets/models/`, and instance it. Large `.glb` files belong in Git LFS (see `.gitattributes`).

## Textures: `art-src/textures/pbr.py`

```bash
scripts/delegate.sh textures wood plaster      # or no names: every recipe
```

Each recipe is a function that builds Blender node outputs through a small builder `b` and returns the material's channels:

```python
def plaster(b):
    blotch, grain = b.noise(3, detail=3), b.noise(70, detail=3)       # tiling noise, 3 and 70 cells per tile
    col = b.mix(stretch(b, blotch, 0.35, 0.65), "#D6BE92", "#E4D0A6")  # two-tone colour by the blotch noise
    h = combine(b, (stretch(b, grain, 0.2, 0.8), 0.55), (stretch(b, blotch, 0.3, 0.7), 0.45))
    return dict(color=col, rough=0.9, height=h, strength=0.6, distance=0.004)
```

Register it in the `RECIPES = dict(...)` line at the bottom of the recipe section.

- **What it bakes:** 1024 px `<name>_albedo.png`, `<name>_normal.png` (from `height`; tangent space, +Y up, Godot's default) and `<name>_rough.png`.
- **Why they tile:** every noise is sampled on a 4D torus (cos and sin of u and v), so the textures wrap in both directions with no visible seam. `b.noise(ku, kv)` with different counts stretches the grain (wood, bark). Patterns made of whole cells (`b.brick`, planks) use whole-number counts per tile for the same reason.
- **Builder tools:**
  - `b.noise`, `b.voronoi` and `b.brick` make patterns;
  - `b.ramp(fac, [(pos, "#hex"), …])` maps a value to colours;
  - `b.mix`, `b.math` and `b.bw` combine and convert;
  - `stretch()` and `combine()` raise contrast and add weighted layers.
- **Using them:** these are textures without UVs. In Godot they work best with **triplanar** mapping on a StandardMaterial3D, or with UVs you lay out yourself.

## Sprites: `art-src/sprites/<name>.py`

2D sprites are small 3D scenes rendered with an orthographic camera into 8 frames, then tiled into one strip.

```python
from common import *
args = parse_args()                                      # out dir, --size, --samples
scene = reset_scene()
setup_render(scene, args.size, args.size, args.samples)  # transparent background, denoised
standard_lighting(scene); studio_world(scene)
add_camera(scene, ortho_scale=2.75)
pivot = new_pivot(scene)
# ... build objects, parent_to(obj, pivot) ...
def pose(t):                                             # t goes 0 -> 1 over the loop
    pivot.rotation_euler = (0, 0, t * 3.14159)
render_cycle(scene, args.out, pose)                      # frame_00.png ... frame_07.png
```

`scripts/sprites.sh` tiles the frames into `build/sprites/<name>_sheet.png` (8×1). A script called `background` renders one still instead. Add new names to the `NAMES=(…)` list in `scripts/sprites.sh` so `all` includes them. In Godot, use the sheet with an `AnimatedSprite2D` or a `Sprite2D` with `hframes = 8`.

## Rendering whole `.blend` files

If you build a scene by hand in Blender, using the **same version as the GPU box**, commit the `.blend` (LFS) and render it:

```bash
scripts/delegate.sh render art-src/shot.blend 1 120 --samples 64
scripts/delegate.sh encode renders/shot/frame_%04d.png renders/shot.mp4
```
