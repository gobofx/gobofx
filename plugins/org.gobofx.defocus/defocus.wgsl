// Defocus — a lens blur with a bokeh shape. Pass 1 gathers the source over a
// disc or hexagon footprint on a jittered Vogel spiral (a flat kernel, so
// highlights become discs rather than Gaussian smudges); pass 2 is a small
// tent that smooths the spiral's per-pixel noise. Radius 0 passes through.
const TAPS: i32 = 64;
const MAX_RADIUS: f32 = 48.0;
const GOLDEN: f32 = 2.39996323;
const PI: f32 = 3.14159265359;

struct Params {
    radius: f32,          // float — bokeh radius in pixels
    shape: u32,           // choice — 0 disc, 1 hexagon
    highlight_boost: f32, // float — how much brighter the highlights get before gathering
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

// Radius of a flat-topped unit hexagon in direction `ang`, so a disc sample
// at angle `ang` can be pushed out to the hexagon's edge.
fn hex_radius(ang: f32) -> f32 {
    let sector = PI / 3.0;
    let a = ang - sector * floor(ang / sector) - sector * 0.5;
    return cos(sector * 0.5) / cos(a);
}

// Highlights are lifted before gathering so bright points bloom into
// visible bokeh shapes instead of averaging away.
fn boosted(c: vec4f) -> vec4f {
    let y = luma(unpremultiply(c));
    let k = smoothstep(0.5, 1.0, y) * clamp(params.highlight_boost, 0.0, 4.0);
    return vec4f(c.rgb * (1.0 + k), c.a);
}

@fragment
fn fs_bokeh(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.radius, 0.0, MAX_RADIUS);
    if (r < 0.5) {
        return src_at(uv);
    }
    // One spiral per pixel, rotated by a hash so the pattern never aligns
    // between neighbours; the hexagon keeps its orientation because the
    // footprint is applied after the rotation.
    let phase = hash21(uv * gobofx_globals.resolution) * 2.0 * PI;
    let px = r * gobofx_globals.texel;
    var acc = vec4f(0.0);
    for (var i = 0; i < TAPS; i++) {
        let t = (f32(i) + 0.5) / f32(TAPS);
        let ang = f32(i) * GOLDEN + phase;
        var rad = sqrt(t);
        if (params.shape == 1u) {
            rad *= hex_radius(ang);
        }
        let offs = vec2f(cos(ang), sin(ang)) * rad * px;
        acc += boosted(src_at(uv + offs));
    }
    return acc / f32(TAPS);
}

@fragment
fn fs_smooth(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.radius, 0.0, MAX_RADIUS);
    if (r < 0.5) {
        return src_at(uv);
    }
    // A 5×5 tent whose spacing grows with the radius: it hides the spiral
    // noise without rounding off the bokeh edge.
    let step = clamp(r / 16.0, 0.5, 1.5) * gobofx_globals.texel;
    var acc = vec4f(0.0);
    var wsum = 0.0;
    for (var y = -2; y <= 2; y++) {
        for (var x = -2; x <= 2; x++) {
            let w = (3.0 - abs(f32(x))) * (3.0 - abs(f32(y)));
            acc += src_at(uv + vec2f(f32(x), f32(y)) * step) * w;
            wsum += w;
        }
    }
    return acc / wsum;
}
