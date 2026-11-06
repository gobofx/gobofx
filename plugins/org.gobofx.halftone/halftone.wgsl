// Halftone — the picture as a print screen of dots. Mono lays one screen of
// ink on paper; CMYK lays four, at the classic press angles, and multiplies
// them like ink on a page.
struct Params {
    size: f32,    // float — screen pitch in pixels (dot-centre spacing)
    angle: f32,   // float — screen angle in degrees
    mode: u32,    // choice — 0 mono, 1 CMYK
    ink: vec4f,   // color — the mono ink and the K plate (premultiplied)
    paper: vec4f, // color — the paper (premultiplied)
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}
fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// Perceptual (gamma-encoded) straight colour at a point, 0..1.
fn tone_at(uv: vec2f) -> vec3f {
    let s = src_at(uv);
    return pow(clamp(unpremultiply(s), vec3f(0.0), vec3f(1.0)), vec3f(1.0 / 2.2));
}

struct Cell {
    centre: vec2f, // pixel position of the dot centre
    dist: f32,     // distance from this pixel to it, in pixels
}

// The screen cell this pixel falls in, for a screen at `deg` with pitch `s`.
fn cell(px: vec2f, deg: f32, s: f32) -> Cell {
    let a = radians(deg);
    let c = cos(a);
    let sn = sin(a);
    let r = vec2f(c * px.x + sn * px.y, -sn * px.x + c * px.y);
    let cc = (floor(r / s) + 0.5) * s;
    let back = vec2f(c * cc.x - sn * cc.y, sn * cc.x + c * cc.y);
    var out: Cell;
    out.centre = back;
    out.dist = distance(px, back);
    return out;
}

// Dot coverage 0..1 for an ink density `d` (0 none, 1 solid) in a cell of pitch `s`.
// Dot area tracks density; past ~0.8 the dots merge and the cell goes solid.
fn dot_cover(d: f32, dist: f32, s: f32) -> f32 {
    let r = sqrt(clamp(d, 0.0, 1.0)) * s * 0.62;
    return 1.0 - smoothstep(r - 0.7, r + 0.7, dist);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let res = gobofx_globals.resolution;
    let px = uv * res;
    let s = clamp(params.size, 2.0, 64.0);
    let paper = unpremultiply(params.paper);
    let ink = unpremultiply(params.ink);
    let src = src_at(uv);
    var o: vec3f;
    if (params.mode == 1u) {
        // Classic press angles: C 15°, M 75°, Y 0°, K 45°, all relative to the screen angle.
        let kc = cell(px, params.angle - 30.0, s);
        let km = cell(px, params.angle + 30.0, s);
        let ky = cell(px, params.angle - 45.0, s);
        let kk = cell(px, params.angle, s);
        let tc = tone_at(kc.centre / res);
        let tm = tone_at(km.centre / res);
        let ty = tone_at(ky.centre / res);
        let tk = tone_at(kk.centre / res);
        // Under-colour removal: the grey part of each pixel goes to the K plate.
        let kcv = 1.0 - max(max(tk.r, tk.g), tk.b);
        let c = dot_cover((1.0 - tc.r) - (1.0 - max(max(tc.r, tc.g), tc.b)), kc.dist, s);
        let m = dot_cover((1.0 - tm.g) - (1.0 - max(max(tm.r, tm.g), tm.b)), km.dist, s);
        let y = dot_cover((1.0 - ty.b) - (1.0 - max(max(ty.r, ty.g), ty.b)), ky.dist, s);
        let k = dot_cover(kcv, kk.dist, s);
        o = paper;
        o *= mix(vec3f(1.0), vec3f(0.0, 0.6, 0.9), c);
        o *= mix(vec3f(1.0), vec3f(0.9, 0.0, 0.5), m);
        o *= mix(vec3f(1.0), vec3f(1.0, 0.9, 0.0), y);
        o = mix(o, ink, k);
    } else {
        let kk = cell(px, params.angle, s);
        let d = 1.0 - luma(tone_at(kk.centre / res));
        o = mix(paper, ink, dot_cover(d, kk.dist, s));
    }
    // The print keeps the source's shape: transparent stays transparent.
    return vec4f(o * src.a, src.a);
}
