// Hatched Screen — the picture as pen crosshatching: up to four passes of
// parallel ink lines at different angles, each pass only appearing where
// the picture is dark enough and thickening as it gets darker.
const MAX_LINES: i32 = 4;

struct Params {
    size: f32,    // float — line pitch in pixels (spacing within one pass)
    angle: f32,   // float — angle of the first pass in degrees
    lines: i32,   // int — number of hatching passes, 1..4
    ink: vec4f,   // color — the line colour (premultiplied)
    paper: vec4f, // color — the colour between lines (premultiplied)
    amount: f32,  // float — 0 is the source, 1 the full screen
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// Perceptual darkness at a point, 0 white .. 1 black.
fn dark_at(uv: vec2f) -> f32 {
    let c = pow(clamp(unpremultiply(src_at(uv)), vec3f(0.0), vec3f(1.0)), vec3f(1.0 / 2.2));
    return 1.0 - luma(c);
}

// Ink coverage of one hatching pass at `deg` for a pixel at `px`, given the
// darkness band this pass serves: it starts at `lo` and is solid at 1.
fn hatch(px: vec2f, deg: f32, s: f32, lo: f32) -> f32 {
    let a = radians(deg);
    let c = cos(a);
    let sn = sin(a);
    let r = vec2f(c * px.x + sn * px.y, -sn * px.x + c * px.y);
    let line = (floor(r.y / s) + 0.5) * s;
    let dist = abs(r.y - line);
    // Tone is read on the line's centre, straight across from this pixel,
    // so the stroke swells and thins along its length with the picture.
    let on_line = vec2f(c * r.x - sn * line, sn * r.x + c * line);
    let d = dark_at(on_line / gobofx_globals.resolution);
    let w = clamp((d - lo) / max(1.0 - lo, 1e-4), 0.0, 1.0);
    let hw = w * s * 0.5;
    return 1.0 - smoothstep(hw - 0.7, hw + 0.7, dist);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let res = gobofx_globals.resolution;
    let px = uv * res;
    let s = clamp(params.size, 2.0, 64.0);
    let n = clamp(params.lines, 1, MAX_LINES);
    // Pass angles in the order a pen would add them: the first diagonal,
    // its cross, then the horizontal and vertical.
    let offsets = array<f32, 4>(0.0, 90.0, 45.0, 135.0);
    var clear = 1.0;
    for (var k = 0; k < MAX_LINES; k++) {
        if (k >= n) {
            break;
        }
        let lo = f32(k) / f32(n);
        clear *= 1.0 - hatch(px, params.angle + offsets[k], s, lo);
    }
    let cover = 1.0 - clear;
    let o = mix(unpremultiply(params.paper), unpremultiply(params.ink), cover);
    let src = src_at(uv);
    // The print keeps the source's shape: transparent stays transparent.
    let screened = vec4f(o * src.a, src.a);
    return mix(src, screened, clamp(params.amount, 0.0, 1.0));
}
