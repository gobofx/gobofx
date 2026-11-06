# GoboFX reference catalogue

Status: **target list, draft 0.1.** The effects and transitions a complete
GoboFX plugin library should cover. Rows are ticked (✅ + id) as open-source
reference plugins land under `plugins/` — 23 effects, 21 transitions and 10
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
| Blurs | ✅ Simple | Plain blur dissolve — `org.gobofx.simple-blur` | Planned | |
| Blurs | ✅ Zoom | Radial zoom blur through the cut — `org.gobofx.zoom-dissolve` | Planned | |
| Blurs | ✅ Zoom & Pan | Zoom blur with directional pan — `org.gobofx.zoom-pan` | Planned | |
| Lights | ✅ Bloom | Bright glow peaks at the edit point — `org.gobofx.bloom-dissolve` | Planned | |
| Lights | ✅ Flash | White flash-frame cut — `org.gobofx.flash` | Planned | |
| Lights | ✅ Static | TV-noise channel change — `org.gobofx.static` | Planned | |
| Movements | ✅ Doorway | A opens like double doors onto B — `org.gobofx.doorway` | Planned | |
| Movements | ✅ Drop In | B drops into frame over A — `org.gobofx.drop-in` | Planned | |
| Movements | ✅ Fall | A tips and falls away — `org.gobofx.fall` | Planned | |
| Movements | ✅ Flip | 3D card flip from A to B — `org.gobofx.flip` | Planned | |
| Movements | ✅ Mosaic | Tiles flip to reveal B — `org.gobofx.mosaic` | Planned | |
| Movements | ✅ Page Curl | A peels like a page — `org.gobofx.page-curl` | Planned | |
| Movements | ✅ Pinwheel | Rotating blades reveal B — `org.gobofx.pinwheel` | Planned | |
| Movements | ✅ Push | B pushes A off-frame — `org.gobofx.push` | Core | |
| Movements | ✅ Puzzle | A breaks into jigsaw pieces — `org.gobofx.puzzle` | Planned | |
| Movements | ✅ Ripple | Water ripple from a center point — `org.gobofx.ripple` | Planned | |
| Movements | ✅ Scale | A shrinks or B grows to fill — `org.gobofx.scale` | Planned | |
| Movements | ✅ Slide | B slides over A — `org.gobofx.slide` | Planned | |
| Movements | ✅ Spin | A spins away into B — `org.gobofx.spin` | Planned | |
| Movements | ✅ Spin Slide | Spin combined with slide — `org.gobofx.spin-slide` | Planned | |
| Movements | ✅ Swap | A and B trade places in 3D — `org.gobofx.swap` | Planned | |
| Movements | ✅ Switch | Quick swap with motion blur — `org.gobofx.switch` | Planned | |
| Objects | Leaves | Falling leaves cover the cut | Planned | bundled textures |
| Objects | ✅ Stars | Star shapes sweep through — `org.gobofx.stars` | Planned | |
| Clones | ✅ Clones | A multiplies into a grid, resolves to B — `org.gobofx.clones` | Planned | |
| Clones | ✅ Clone Spin | Cloned tiles spin into B — `org.gobofx.clone-spin` | Planned | |
| Clones | ✅ Multi-Flip | Grid of tiles flips individually — `org.gobofx.multi-flip` | Planned | |
| Clones | ✅ Reflection | Mirrored clones on a reflective floor — `org.gobofx.reflection` | Planned | |
| Stylized | ✅ Arrows | Graphic arrows wipe across — `org.gobofx.arrows` | Planned | |
| Stylized | ✅ Billboard | B appears on a rotating billboard — `org.gobofx.billboard` | Planned | |
| Stylized | ✅ Band Sweep | Graphic band sweeps the lower frame — `org.gobofx.band-sweep` | Planned | |
| Stylized | ✅ Album | Clips as pages in a photo album — `org.gobofx.album` | Planned | |
| Wipes | ✅ Band | Multiple bands wipe across — `org.gobofx.band-wipe` | Planned | |
| Wipes | ✅ Center | Wipe opens from center — `org.gobofx.center-wipe` | Planned | |
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
| ✅ Luma Keyer | Key out by brightness — `org.gobofx.luma-key` | Planned | |
| ✅ Shape Mask | Rounded-rect or ellipse mask with feather — `org.gobofx.shape-mask` | Core | |
| ✅ Vignette Mask | Soft horizontal ellipse mask — `org.gobofx.vignette-mask` | Planned | |
| ✅ Graduated Mask | Soft-edge linear split — `org.gobofx.graduated-mask` | Planned | |
| ✅ Corner Mask | Four-corner quad mask, invertible — `org.gobofx.corner-mask` | Planned | |
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
| ✅ LUT | Apply a `.cube` lookup table — `org.gobofx.lut` | Core | `spec/assets.md` (lut3d assets + the `asset` param type) |
| ✅ Brightness | Linear brightness — `org.gobofx.brightness` | Candidate | |
| ✅ Contrast | Contrast around a pivot — `org.gobofx.contrast` | Candidate | |
| ✅ Gamma | Midtone gamma — `org.gobofx.gamma` | Candidate | |
| ✅ Levels | Black, white and gamma per channel — `org.gobofx.levels` | Planned | |
| ✅ Channel Mixer | Remix RGB channels — `org.gobofx.channel-mixer` | Candidate | |
| ✅ Color Balance | Shadows, mids, highlights balance — `org.gobofx.color-balance` | Planned | |
| ✅ Colorize | Map blacks and whites to two colors — `org.gobofx.colorize` | Candidate | |
| ✅ Gradient Colorize | Map luma to a gradient — `org.gobofx.gradient-colorize` | Candidate | |
| ✅ Color Reduce | Limit to a few colors — `org.gobofx.color-reduce` | Candidate | |
| ✅ Tint | Monochrome tint — `org.gobofx.tint` | Candidate | |
| ✅ Sepia | Sepia tone — `org.gobofx.sepia` | Candidate | |
| ✅ Invert | Invert colors — `org.gobofx.invert` | Core | |
| ✅ Threshold | Hard black-and-white cutoff — `org.gobofx.threshold` | Candidate | |
| HDR Tools | HDR and SDR tone mapping | Candidate | |

### Looks

Looks are presets over one grade plugin (a LUT or a preset of Color
Adjustments), not a shader each: `manifest.presets[]` (spec/manifest.md
§Presets, 2026-11-06). They land on `org.gobofx.color-adjustments` and
`org.gobofx.lut` and a host shows them as one Looks rail.

| Title | Short description | Priority |
|---|---|---|
| ✅ Bleach Bypass | Desaturated, high-contrast silver look — `org.gobofx.color-adjustments` preset `bleach_bypass` | Candidate |
| ✅ Warm Sun | Warm, sunny grade — `org.gobofx.color-adjustments` preset `warm_sun` | Candidate |
| ✅ Chrome | Punchy, saturated look — `org.gobofx.color-adjustments` preset `chrome` | Candidate |
| ✅ Cool | Blue-shifted grade — `org.gobofx.color-adjustments` preset `cool` | Candidate |
| ✅ Faded Film | Lifted blacks, faded print — `org.gobofx.lut` preset `faded_film` | Candidate |
| ✅ Instant Camera | Instant-photo look — `org.gobofx.lut` preset `instant_camera` | Candidate |
| ✅ Mono | Black and white — `org.gobofx.color-adjustments` preset `mono` | Candidate |
| ✅ Desert | Dry, dusty grade — `org.gobofx.color-adjustments` preset `desert` | Candidate |
| ✅ Urban | Cool, high-contrast city look — `org.gobofx.color-adjustments` preset `urban` | Candidate |
| ✅ Noir | High-contrast black and white — `org.gobofx.color-adjustments` preset `noir` | Candidate |
| ✅ Cross Process | Cross-processed color shift — `org.gobofx.lut` preset `cross_process` | Candidate |
| ✅ Vintage | Period film stock look — `org.gobofx.lut` preset `vintage` | Candidate |
| ✅ Soft Tonal | Soft black-and-white tonal — `org.gobofx.lut` preset `soft_tonal` | Candidate |
| ✅ Print Transfer | Old print transfer — `org.gobofx.lut` preset `print_transfer` | Candidate |

### Blur

| Title | Short description | Priority | Needs |
|---|---|---|---|
| ✅ Gaussian Blur | Standard separable blur — `org.gobofx.gaussian-blur` | Core | |
| ✅ Channel Blur | Blur per RGBA channel — `org.gobofx.channel-blur` | Candidate | |
| ✅ Circle Blur | Blur inside a circle — `org.gobofx.circle-blur` | Candidate | |
| Compound Blur | Blur driven by a map image | Candidate | a second image input on an effect |
| ✅ Defocus | Lens defocus with bokeh — `org.gobofx.defocus` | Planned | |
| ✅ Directional Blur | Motion blur at an angle — `org.gobofx.directional-blur` | Planned | |
| ✅ Gradient Blur | Tilt-shift style ramp — `org.gobofx.gradient-blur` | Planned | |
| ✅ Prism | Chromatic split blur — `org.gobofx.prism` | Candidate | |
| ✅ Radial Blur | Rotational blur — `org.gobofx.radial-blur` | Planned | |
| ✅ Soft Focus | Dreamy diffusion — `org.gobofx.soft-focus` | Candidate | |
| ✅ Variable Blur | Sharp center, blurred falloff — `org.gobofx.variable-blur` | Candidate | |
| ✅ Zoom Blur | Push-in blur from a point — `org.gobofx.zoom-blur` | Planned | |

### Sharpen

| Title | Short description | Priority | Needs |
|---|---|---|---|
| ✅ Sharpen | Edge sharpening — `org.gobofx.sharpen` | Planned | |
| ✅ Unsharp Mask | Radius and threshold sharpening — `org.gobofx.unsharp-mask` | Planned | |

### Distort

| Title | Short description | Priority | Needs |
|---|---|---|---|
| ✅ Droplet | Water-drop ripple rings — `org.gobofx.droplet` | Planned | |
| ✅ Hex Lens | Compound-eye hexagonal lens — `org.gobofx.hex-lens` | Candidate | |
| ✅ Black Hole | Pixels pulled into a point — `org.gobofx.black-hole` | Candidate | |
| ✅ Bulge | Spherical bulge or pinch — `org.gobofx.bulge` | Planned | |
| Bump Map | Displace via a map image | Candidate | a second image input on an effect |
| ✅ Disc Warp | Wrap the image into a disc — `org.gobofx.disc-warp` | Candidate | |
| ✅ Shake | Camera shake — `org.gobofx.shake` | Planned | |
| ✅ Fisheye | Wide-angle barrel distortion — `org.gobofx.fisheye` | Planned | |
| ✅ Flop | Flip horizontally or vertically — `org.gobofx.flop` | Core | |
| ✅ Stretch Mirror | Funhouse-mirror warp — `org.gobofx.stretch-mirror` | Candidate | |
| ✅ Glass Block | Glass-brick refraction — `org.gobofx.glass-block` | Candidate | |
| Glass Distortion | Refraction through textured glass | Candidate | bundled texture |
| ✅ Mirror | Mirror around an axis — `org.gobofx.mirror` | Planned | |
| ✅ Page Curl | Static page peel — `org.gobofx.curled-page` | Candidate | |
| ✅ Poke | Localized push dent — `org.gobofx.poke` | Candidate | |
| ✅ Polar | Rectangular-to-polar warp — `org.gobofx.polar` | Candidate | |
| Refraction | Refract via a map image | Candidate | a second image input on an effect |
| ✅ Ring Lens | Ring-shaped lens — `org.gobofx.ring-lens` | Candidate | |
| ✅ Ripple | Concentric water ripples — `org.gobofx.water-ripple` | Planned | |
| ✅ Scrape | Smear pixels from an edge — `org.gobofx.scrape` | Candidate | |
| ✅ Sliced Scale | 9-slice scale preserving corners — `org.gobofx.sliced-scale` | Candidate | |
| ✅ Sphere | Wrap onto a sphere — `org.gobofx.sphere` | Candidate | |
| ✅ Starburst | Radial streak burst — `org.gobofx.starburst` | Candidate | |
| ✅ Stripes | Offset stripe slices — `org.gobofx.slice-stripes` | Candidate | |
| ✅ Target | Concentric ring offsets — `org.gobofx.target` | Candidate | |
| ✅ Tiny Planet | Little-planet stereographic projection — `org.gobofx.tiny-planet` | Candidate | |
| ✅ Twirl | Swirl around the center — `org.gobofx.twirl` | Planned | |
| ✅ Underwater | Wavy underwater refraction — `org.gobofx.underwater` | Candidate | |
| ✅ Wave | Sine-wave displacement — `org.gobofx.wave` | Planned | |

### Stylize

| Title | Short description | Priority | Needs |
|---|---|---|---|
| ✅ Film Grain | Grain or noise overlay — `org.gobofx.film-grain` | Core | |
| ✅ Old Film | Scratches, dust, flicker — `org.gobofx.old-film` | Planned | |
| ✅ Broken TV | Rolling scanline interference — `org.gobofx.broken-tv` | Planned | |
| ✅ Circle Screen | Circular halftone screen — `org.gobofx.circle-screen` | Candidate | |
| ✅ Dot Grid | Image as a grid of dots — `org.gobofx.dot-grid` | Candidate | |
| ✅ Color Emboss | Emboss keeping color — `org.gobofx.color-emboss` | Candidate | |
| ✅ Comic | Ink-and-color comic look — `org.gobofx.comic` | Candidate | |
| ✅ Crystallize | Voronoi crystal cells — `org.gobofx.crystallize` | Candidate | |
| ✅ Edges | Edge detection — `org.gobofx.edges` | Planned | |
| ✅ Extrude | 3D extruded alpha — `org.gobofx.extrude` | Candidate | |
| ✅ Fill | Solid or gradient fill of alpha — `org.gobofx.fill` | Candidate | |
| ✅ Halftone | Print halftone dots — `org.gobofx.halftone` | Planned | |
| ✅ Hatched Screen | Crosshatch screen — `org.gobofx.hatched-screen` | Candidate | |
| ✅ Highpass | Keep only fine detail — `org.gobofx.highpass` | Candidate | |
| ✅ Indent | Press the image into a surface — `org.gobofx.indent` | Candidate | |
| ✅ Line Art | Pen-sketch outlines — `org.gobofx.line-art` | Candidate | |
| ✅ Line Screen | Engraving line screen — `org.gobofx.line-screen` | Candidate | |
| ✅ MinMax | Erode or dilate — `org.gobofx.minmax` | Candidate | |
| ✅ Noise Dissolve | Noisy dissolve to transparent — `org.gobofx.noise-dissolve` | Candidate | |
| ✅ Pixellate | Block mosaic, censor — `org.gobofx.pixellate` | Core | |
| ✅ Posterize | Reduce tonal levels — `org.gobofx.posterize` | Planned | |
| ✅ Relief | Gray emboss — `org.gobofx.relief` | Candidate | |
| Slit Scan | Streaked slit-scan | Candidate | frame history |
| Slit Tunnel | Tunnel streaks | Candidate | frame history |
| Texture Screen | Texture-based screen | Candidate | bundled texture |
| ✅ Vignette | Darkened edges — `org.gobofx.vignette` | Core | |
| ✅ Wavy Screen | Wavy line screen — `org.gobofx.wavy-screen` | Candidate | |
| ✅ Drop Shadow | Shadow behind a layer with alpha — `org.gobofx.drop-shadow` | Planned | |

### Glow

| Title | Short description | Priority | Needs |
|---|---|---|---|
| Aura | Soft halo | Candidate | |
| ✅ Bloom | Highlights bleed — `org.gobofx.bloom` | Planned | |
| Dazzle | Star-shaped glints | Candidate | |
| Glint | Specular glints | Candidate | |
| Gloom | Dark, moody glow | Candidate | |
| ✅ Glow | Brightness glow — `org.gobofx.glow` | Core | |
| ✅ Light Rays | Volumetric rays — `org.gobofx.light-rays` | Planned | |
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
| ✅ Tile | Grid repeat — `org.gobofx.tile` | Planned | |
| Triangle Tile | Triangular tiling | Candidate | |

### Border

| Title | Short description | Priority | Needs |
|---|---|---|---|
| ✅ Bevel | Beveled edge — `org.gobofx.bevel` | Candidate | |
| ✅ Simple Border | Solid frame — `org.gobofx.simple-border` | Planned | |
| ✅ Stroke | Outline around alpha — `org.gobofx.stroke` | Candidate | |
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
Categories: `solid`, `gradient`, `noise`, `pattern`, `shapes`, `light` (light
sources and film artefacts that sit over footage).

| Title | Short description | Priority |
|---|---|---|
| ✅ Solid | Solid color — `org.gobofx.solid` | Core |
| ✅ Gradient | Linear and radial gradients — `org.gobofx.gradient` | Core |
| ✅ Noise | Value, Perlin and cellular noise — `org.gobofx.noise` (and `org.gobofx.plasma`) | Planned |
| ✅ Patterns | Checker, stripes, grid, dots — `org.gobofx.checkerboard`, `stripes`, `grid`, `dots`, `color-bars` | Planned |
| ✅ Shapes | Rectangle, ellipse, polygon, star with fill and stroke — `org.gobofx.shape` | Planned |
| ✅ Spotlight | A soft light pool over transparent: centre, radius, aspect, softness, colour — `org.gobofx.spotlight` | Planned |
| ✅ Sunburst | Rays radiating from a centre, turning with speed — `org.gobofx.sunburst` | Planned |
| ✅ Starfield | Hash-per-cell stars on a sky, twinkling; background alpha 0 to stack — `org.gobofx.starfield` | Planned |
| ✅ Scanlines | Horizontal lines over transparent, optional roll — `org.gobofx.scanlines` | Planned |
| ✅ Hex Grid | Honeycomb lines over transparent, optional fill — `org.gobofx.hex-grid` | Planned |
| ✅ Caustics | Underwater light web, two drifting cellular layers — `org.gobofx.caustics` | Planned |
| ✅ Clouds | Self-warped fBm cumulus over a sky colour, drifting — `org.gobofx.clouds` | Planned |
| ✅ Lens Flare | Source glow, anamorphic streak and tinted ghosts over transparent — `org.gobofx.lens-flare` | Planned |
| ✅ Light Leak | Warm noise-shaped leaks creeping in from an edge, drifting — `org.gobofx.light-leak` | Planned |
| ✅ Film Burn | A burning-film front eating in from an edge, boiling with time — `org.gobofx.film-burn` | Planned |

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
