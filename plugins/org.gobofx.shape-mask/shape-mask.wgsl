// Shape Mask — keep the picture inside a rounded rectangle or ellipse,
// transparent outside, with a feathered edge.
struct Params {
    shape: u32,     // choice — 0 rectangle, 1 ellipse
    center: vec2f,  // point
    width: f32,     // float — in frame heights
    height: f32,    // float — in frame heights
    roundness: f32, // float — rectangle corner radius as a fraction of the shorter side
    feather: f32,   // float — edge width in frame heights
    rotation: f32,  // float — degrees
    invert: u32,    // bool
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

fn sd_box(p: vec2f, b: vec2f) -> f32 {
    let d = abs(p) - b;
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let a = radians(params.rotation);
    var d = (uv - params.center) * vec2f(aspect, 1.0);
    d = vec2f(d.x * cos(a) + d.y * sin(a), -d.x * sin(a) + d.y * cos(a));
    let half = vec2f(max(params.width, 0.02), max(params.height, 0.02)) * 0.5;
    var dist: f32;
    if (params.shape == 1u) {
        let k0 = length(d / half);
        let k1 = length(d / (half * half));
        dist = k0 * (k0 - 1.0) / max(k1, 1e-5);
    } else {
        let r = clamp(params.roundness, 0.0, 1.0) * min(half.x, half.y);
        dist = sd_box(d, half - r) - r;
    }
    let f = max(params.feather, 1.5 * gobofx_globals.texel.y);
    var m = 1.0 - smoothstep(-f * 0.5, f * 0.5, dist);
    if (params.invert == 1u) { m = 1.0 - m; }
    return src * m;
}
