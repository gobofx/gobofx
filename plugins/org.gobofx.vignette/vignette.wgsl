// Vignette — darken (or tint) towards the edges.
struct Params {
    strength: f32,  // float — how dark the edges get
    size: f32,      // float — radius of the clear area in frame heights
    softness: f32,  // float — width of the falloff
    roundness: f32, // float — 0 follows the frame's rectangle, 1 circular
    center: vec2f,  // point
    color: vec4f,   // color — the edge colour
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

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let circ = length(d);
    let rect = max(abs(d.x) / aspect * 2.0, abs(d.y) * 2.0) * 0.5 * (1.0 + aspect) * 0.5;
    let dist = mix(rect, circ, clamp(params.roundness, 0.0, 1.0));
    let r = max(params.size, 0.1) * 0.5;
    let s = max(params.softness, 0.01) * r;
    let k = smoothstep(r, r + s, dist) * clamp(params.strength, 0.0, 1.0);
    let edge = unpremultiply(params.color);
    let o = mix(unpremultiply(src), edge, k);
    return vec4f(o * src.a, src.a);
}
