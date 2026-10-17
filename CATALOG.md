# GoboFX reference catalogue

Status: **target list, draft 0.1.** The effects and transitions a complete
GoboFX plugin library should cover. Rows are ticked (✅ + id) as open-source
reference plugins land under `plugins/` — 22 effects, 21 transitions and 10
generators so far. A row in this list is a goal, not a promise of
availability in any host.

## How to read this

- **Kind** is the manifest `kind`: `effect`, `transition` or `generator` (no
  input image).
- **Category** becomes the manifest `category` and the browser grouping a host
  shows.
- **Priority** is the order we intend to build in. *Core* is the first wave.
  *Planned* follows. *Candidate* is on the list and open for contribution.
- **Needs** names a spec feature the row depends on beyond the 0.1 baseline
  (one or two input images, one output, no history). Blank means it can be
  written today.
- 360° effects and transitions are out of scope for this catalogue.

Behaviour every transition relies on from the host: the two clips must have
overlapping handle media (the host clamps the transition to the available
handle and shows that), the host offers an audio crossfade alongside the video
transition, and the usual shared controls are duration, ease, direction and
edge treatment. None of that is per-plugin work.

## Transitions

| Category | Title | Short description | Priority | Needs |
|---|---|---|---|---|
| Dissolves | ✅ Cross Dissolve | Blend A into B; linear or eased — `org.gobofx.cross-dissolve` | Core | |
| Dissolves | ✅ Fade To Color | Dip to a solid color (black default) and back — `org.gobofx.fade-to-color` | Core | |
| Dissolves | Flow | Morph-style dissolve that hides jump cuts in talking heads | Planned | optical flow (host-side) |
| Dissolves | ✅ Divide | Frame splits into strips that reveal B — `org.gobofx.divide` | Planned | |
| Blurs | ✅ Gaussian | Blur out A, blur in B; adjustable amount — `org.gobofx.blur-dissolve` | Planned | |
| Blurs | Simple | Plain blur dissolve | Planned | |
| Blurs | ✅ Zoom | Radial zoom blur through the cut — `org.gobofx.zoom-dissolve` | Planned | |
| Blurs | Zoom & Pan | Zoom blur with directional pan | Planned | |
| Lights | Bloom | Bright glow peaks at the edit point | Planned | |
| Lights | ✅ Flash | White flash-frame cut — `org.gobofx.flash` | Planned | |
| Lights | ✅ Static | TV-noise channel change — `org.gobofx.static` | Planned | |
| Movements | ✅ Doorway | A opens like double doors onto B — `org.gobofx.doorway` | Planned | |
| Movements | Drop In | B drops into frame over A | Planned | |
| Movements | Fall | A tips and falls away | Planned | |
| Movements | ✅ Flip | 3D card flip from A to B — `org.gobofx.flip` | Planned | |
| Movements | ✅ Mosaic | Tiles flip to reveal B — `org.gobofx.mosaic` | Planned | |
| Movements | Page Curl | A peels like a page | Planned | |
| Movements | Pinwheel | Rotating blades reveal B | Planned | |
| Movements | ✅ Push | B pushes A off-frame — `org.gobofx.push` | Core | |
| Movements | Puzzle | A breaks into jigsaw pieces | Planned | |
| Movements | ✅ Ripple | Water ripple from a center point — `org.gobofx.ripple` | Planned | |
| Movements | ✅ Scale | A shrinks or B grows to fill — `org.gobofx.scale` | Planned | |
| Movements | ✅ Slide | B slides over A — `org.gobofx.slide` | Planned | |
| Movements | ✅ Spin | A spins away into B — `org.gobofx.spin` | Planned | |
| Movements | Spin Slide | Spin combined with slide | Planned | |
| Movements | Swap | A and B trade places in 3D | Planned | |
| Movements | Switch | Quick swap with motion blur | Planned | |
| Objects | Leaves | Falling leaves cover the cut | Planned | bundled textures |
| Objects | Stars | Star shapes sweep through | Planned | |
| Clones | Clones | A multiplies into a grid, resolves to B | Planned | |
| Clones | Clone Spin | Cloned tiles spin into B | Planned | |
| Clones | Multi-Flip | Grid of tiles flips individually | Planned | |
| Clones | Reflection | Mirrored clones on a reflective floor | Planned | |
| Stylized | Arrows | Graphic arrows wipe across | Planned | |
| Stylized | Billboard | B appears on a rotating billboard | Planned | |
| Stylized | Band Sweep | Graphic band sweeps the lower frame | Planned | |
| Stylized | Album | Clips as pages in a photo album | Planned | |
| Wipes | ✅ Band | Multiple bands wipe across — `org.gobofx.band-wipe` | Planned | |
| Wipes | Center | Wipe opens from center | Planned | |
| Wipes | ✅ Checker | Checkerboard wipe — `org.gobofx.checker-wipe` | Planned | |
| Wipes | ✅ Clock | Radial clock-hand sweep — `org.gobofx.clock-wipe` | Planned | |
| Wipes | Gradient Image | Wipe shaped by a grayscale image | Planned | a third image input |
| Wipes | ✅ Inset | Box wipe from a corner — `org.gobofx.inset-wipe` | Planned | |
| Wipes | ✅ Letter X | X-shaped wipe — `org.gobofx.letter-x-wipe` | Planned | |
| Wipes | ✅ Mask | Shape-mask wipe — `org.gobofx.wipe` | Core | |
| Overlay | Overlay transitions | Transitions with graphic reveals over the cut | Candidate | overlay media, a third image input |

## Effects

Masks and keyframes are host features, not per-plugin work: a host can limit
any effect with a shape mask and animate any param marked `animatable`.

### Masks and Keying

| Title | Short description | Priority | Needs |
|---|---|---|---|
| Background Removal | ML background removal without a green screen | Candidate | a matte from the host, not a shader alone |
| ✅ Chroma Keyer | Chroma key for green or blue screen — `org.gobofx.chroma-key` | Core | |
| Luma Keyer | Key out by brightness | Planned | |
| ✅ Shape Mask | Rounded-rect or ellipse mask with feather — `org.gobofx.shape-mask` | Core | |
| Vignette Mask | Soft horizontal ellipse mask | Planned | |
| Graduated Mask | Soft-edge linear split | Planned | |
| Corner Mask | Four-corner quad mask, invertible | Planned | |
| Image Mask | Mask from another clip's alpha or luma | Planned | a second image input on an effect |

### Color

| Title | Short description | Priority | Needs |
|---|---|---|---|
| ✅ Color Adjustments | Exposure, contrast, saturation, temperature, tint in one — `org.gobofx.color-adjustments` | Core | |
| ✅ Reactive Grade | Saturation, contrast and temperature driven by audio and MIDI signals; notes C1, D1, E1 saturate, flash and punch — `org.gobofx.reactive-grade` | Core | signals |
| ✅ Chromatic Hue | Every key of an octave is a hue; pitch wheel fine-tunes, aftertouch saturates — `org.gobofx.chromatic-hue` | Core | signals: note range, bend, pressure |
| ✅ Hue/Saturation | Shift hue, saturation, value — `org.gobofx.hue-saturation` | Core | |
| Color Wheels | Lift, gamma, gain wheels | Planned | |
| Color Curves | Per-channel RGB curves | Planned | a curve param type |
| Hue/Saturation Curves | Hue-vs-hue, hue-vs-sat, hue-vs-luma curves | Planned | a curve param type |
| LUT | Apply a `.cube` lookup table | Core | a texture asset param type — not buildable on spec 0.1, so not in the library yet |
| Brightness | Linear brightness | Candidate | |
| Contrast | Contrast around a pivot | Candidate | |
| Gamma | Midtone gamma | Candidate | |
| Levels | Black, white and gamma per channel | Planned | |
| Channel Mixer | Remix RGB channels | Candidate | |
| Color Balance | Shadows, mids, highlights balance | Planned | |
| Colorize | Map blacks and whites to two colors | Candidate | |
| Gradient Colorize | Map luma to a gradient | Candidate | |
| Color Reduce | Limit to a few colors | Candidate | |
| Tint | Monochrome tint | Candidate | |
| Sepia | Sepia tone | Candidate | |
| ✅ Invert | Invert colors — `org.gobofx.invert` | Core | |
| Threshold | Hard black-and-white cutoff | Candidate | |
| HDR Tools | HDR and SDR tone mapping | Candidate | |

### Looks

Looks are presets over one grade plugin (a LUT or a preset of Color
Adjustments), not a shader each. Preset support is an open item for the
manifest.

| Title | Short description | Priority |
|---|---|---|
| Bleach Bypass | Desaturated, high-contrast silver look | Candidate |
| Warm Sun | Warm, sunny grade | Candidate |
| Chrome | Punchy, saturated look | Candidate |
| Cool | Blue-shifted grade | Candidate |
| Faded Film | Lifted blacks, faded print | Candidate |
| Instant Camera | Instant-photo look | Candidate |
| Mono | Black and white | Candidate |
| Desert | Dry, dusty grade | Candidate |
| Urban | Cool, high-contrast city look | Candidate |
| Noir | High-contrast black and white | Candidate |
| Cross Process | Cross-processed color shift | Candidate |
| Vintage | Period film stock look | Candidate |
| Soft Tonal | Soft black-and-white tonal | Candidate |
| Print Transfer | Old print transfer | Candidate |

### Blur

| Title | Short description | Priority | Needs |
|---|---|---|---|
| ✅ Gaussian Blur | Standard separable blur — `org.gobofx.gaussian-blur` | Core | |
| Channel Blur | Blur per RGBA channel | Candidate | |
| Circle Blur | Blur inside a circle | Candidate | |
| Compound Blur | Blur driven by a map image | Candidate | a second image input on an effect |
| Defocus | Lens defocus with bokeh | Planned | |
| ✅ Directional Blur | Motion blur at an angle — `org.gobofx.directional-blur` | Planned | |
| Gradient Blur | Tilt-shift style ramp | Planned | |
| Prism | Chromatic split blur | Candidate | |
| Radial Blur | Rotational blur | Planned | |
| Soft Focus | Dreamy diffusion | Candidate | |
| Variable Blur | Sharp center, blurred falloff | Candidate | |
| ✅ Zoom Blur | Push-in blur from a point — `org.gobofx.zoom-blur` | Planned | |

### Sharpen

| Title | Short description | Priority | Needs |
|---|---|---|---|
| ✅ Sharpen | Edge sharpening — `org.gobofx.sharpen` | Planned | |
| Unsharp Mask | Radius and threshold sharpening | Planned | |

### Distort

| Title | Short description | Priority | Needs |
|---|---|---|---|
| Droplet | Water-drop ripple rings | Planned | |
| Hex Lens | Compound-eye hexagonal lens | Candidate | |
| Black Hole | Pixels pulled into a point | Candidate | |
| Bulge | Spherical bulge or pinch | Planned | |
| Bump Map | Displace via a map image | Candidate | a second image input on an effect |
| Disc Warp | Wrap the image into a disc | Candidate | |
| Shake | Camera shake | Planned | |
| Fisheye | Wide-angle barrel distortion | Planned | |
| ✅ Flop | Flip horizontally or vertically — `org.gobofx.flop` | Core | |
| Stretch Mirror | Funhouse-mirror warp | Candidate | |
| Glass Block | Glass-brick refraction | Candidate | |
| Glass Distortion | Refraction through textured glass | Candidate | bundled texture |
| Mirror | Mirror around an axis | Planned | |
| Page Curl | Static page peel | Candidate | |
| Poke | Localized push dent | Candidate | |
| Polar | Rectangular-to-polar warp | Candidate | |
| Refraction | Refract via a map image | Candidate | a second image input on an effect |
| Ring Lens | Ring-shaped lens | Candidate | |
| Ripple | Concentric water ripples | Planned | |
| Scrape | Smear pixels from an edge | Candidate | |
| Sliced Scale | 9-slice scale preserving corners | Candidate | |
| Sphere | Wrap onto a sphere | Candidate | |
| Starburst | Radial streak burst | Candidate | |
| Stripes | Offset stripe slices | Candidate | |
| Target | Concentric ring offsets | Candidate | |
| Tiny Planet | Little-planet stereographic projection | Candidate | |
| ✅ Twirl | Swirl around the center — `org.gobofx.twirl` | Planned | |
| Underwater | Wavy underwater refraction | Candidate | |
| ✅ Wave | Sine-wave displacement — `org.gobofx.wave` | Planned | |

### Stylize

| Title | Short description | Priority | Needs |
|---|---|---|---|
| ✅ Film Grain | Grain or noise overlay — `org.gobofx.film-grain` | Core | |
| ✅ Old Film | Scratches, dust, flicker — `org.gobofx.old-film` | Planned | |
| Broken TV | Rolling scanline interference | Planned | |
| Circle Screen | Circular halftone screen | Candidate | |
| Dot Grid | Image as a grid of dots | Candidate | |
| Color Emboss | Emboss keeping color | Candidate | |
| Comic | Ink-and-color comic look | Candidate | |
| Crystallize | Voronoi crystal cells | Candidate | |
| Edges | Edge detection | Planned | |
| Extrude | 3D extruded alpha | Candidate | |
| Fill | Solid or gradient fill of alpha | Candidate | |
| Halftone | Print halftone dots | Planned | |
| Hatched Screen | Crosshatch screen | Candidate | |
| Highpass | Keep only fine detail | Candidate | |
| Indent | Press the image into a surface | Candidate | |
| Line Art | Pen-sketch outlines | Candidate | |
| Line Screen | Engraving line screen | Candidate | |
| MinMax | Erode or dilate | Candidate | |
| Noise Dissolve | Noisy dissolve to transparent | Candidate | |
| ✅ Pixellate | Block mosaic, censor — `org.gobofx.pixellate` | Core | |
| ✅ Posterize | Reduce tonal levels — `org.gobofx.posterize` | Planned | |
| Relief | Gray emboss | Candidate | |
| Slit Scan | Streaked slit-scan | Candidate | frame history |
| Slit Tunnel | Tunnel streaks | Candidate | frame history |
| Texture Screen | Texture-based screen | Candidate | bundled texture |
| ✅ Vignette | Darkened edges — `org.gobofx.vignette` | Core | |
| Wavy Screen | Wavy line screen | Candidate | |
| Drop Shadow | Shadow behind a layer with alpha | Planned | |

### Glow

| Title | Short description | Priority | Needs |
|---|---|---|---|
| Aura | Soft halo | Candidate | |
| Bloom | Highlights bleed | Planned | |
| Dazzle | Star-shaped glints | Candidate | |
| Glint | Specular glints | Candidate | |
| Gloom | Dark, moody glow | Candidate | |
| ✅ Glow | Brightness glow — `org.gobofx.glow` | Core | |
| Light Rays | Volumetric rays | Planned | |
| Neon | Neon edge glow | Candidate | |
| Outer Glow | Glow outside alpha | Candidate | |
| Overdrive | Blown-out glow | Candidate | |

### Tiling

| Title | Short description | Priority | Needs |
|---|---|---|---|
| ✅ Kaleidoscope | Radial mirror segments; the key picks the segment count, mod wheel spins, pitch wheel zooms — `org.gobofx.kaleidoscope` | Core | signals: note range, bend |
| Kaleidoscope Tile | Kaleidoscopic tiling | Candidate | |
| Offset | Wraparound offset | Candidate | |
| Parallelogram Tile | Skewed tiles | Candidate | |
| Perspective Tile | Tiles on a plane | Candidate | |
| Random Tile | Shuffled tiles | Candidate | |
| Tile | Grid repeat | Planned | |
| Triangle Tile | Triangular tiling | Candidate | |

### Border

| Title | Short description | Priority | Needs |
|---|---|---|---|
| Bevel | Beveled edge | Candidate | |
| Simple Border | Solid frame | Planned | |
| Stroke | Outline around alpha | Candidate | |
| ✅ Widescreen | Letterbox bars — `org.gobofx.widescreen` | Core | |

### Time

Time effects read frames other than the current one. Spec 0.1 gives a plugin
one frame per input image, so these need either a persistent target that
survives across frames or a host-provided frame-history input. Both are open
spec questions.

| Title | Short description | Priority | Needs |
|---|---|---|---|
| Echo | Ghosted frame echoes | Candidate | frame history |
| Hold | Hold or scrub the source frame | Candidate | host feature, not a shader |
| Strobe | Stepped frame rate | Candidate | host feature, not a shader |
| Trails | Motion trails | Candidate | frame history |
| Frame Blend | Multi-frame blend | Candidate | frame history |

### Reframe and Depth

| Title | Short description | Priority | Needs |
|---|---|---|---|
| Reframe | Highlight or punch-in reframing | Candidate | transform and automation in the host, not a shader |
| Depth of Field | Adjust focus points and depth of field | Candidate | depth data from the source |

## Generators

A generator takes no input image (`kind: "generator"`, added to spec 0.1 on
2026-10-15).

| Title | Short description | Priority |
|---|---|---|
| ✅ Solid | Solid color — `org.gobofx.solid` | Core |
| ✅ Gradient | Linear and radial gradients — `org.gobofx.gradient` | Core |
| ✅ Noise | Value, Perlin and cellular noise — `org.gobofx.noise` (and `org.gobofx.plasma`) | Planned |
| ✅ Patterns | Checker, stripes, grid, dots — `org.gobofx.checkerboard`, `stripes`, `grid`, `dots`, `color-bars` | Planned |
| ✅ Shapes | Rectangle, ellipse, polygon, star with fill and stroke — `org.gobofx.shape` | Planned |

## Editor features, not plugins

For orientation only. These belong to the host.

| Feature | Short description |
|---|---|
| Transform | Position, scale, rotation and crop of a clip in frame |
| Draw-on strokes | Freehand strokes animated with a draw-on reveal |
| Keyframing | Animate any `animatable` param over time |
| Effect masks | Per-effect shape mask limiting where an effect applies |
| Effect stack order | Reorder applied effects; lower ones modify those above |
| Copy and paste effects | Copy a full effect stack between clips |
