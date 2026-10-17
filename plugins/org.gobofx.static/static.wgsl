// Static — a TV channel change: snow and rolling scanlines swallow the cut.
struct Params {
    width: f32,     // float — how much of the transition is static
    density: f32,   // float — how much snow at the peak (0 shows the cut through)
    scanlines: f32, // float — strength of the horizontal line pattern
    grain: f32,     // float — snow cell size in pixels
}
@group(1) @binding(0) var<uniform> params: Params;

fn from_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}
fn to_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0), inside);
}
fn eased(ease: f32) -> f32 {
    let p = clamp(gobofx_globals.progress, 0.0, 1.0);
    return mix(p, smoothstep(0.0, 1.0, p), clamp(ease, 0.0, 1.0));
}
// Premultiplied `over`.
fn over(top: vec4f, bottom: vec4f) -> vec4f {
    return top + bottom * (1.0 - top.a);
}
fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
// Direction 0..3 → the axis coordinate that grows along the wipe.
fn axis(uv: vec2f, direction: u32) -> f32 {
    switch direction {
        case 1u: { return 1.0 - uv.x; }
        case 2u: { return uv.y; }
        case 3u: { return 1.0 - uv.y; }
        default: { return uv.x; }
    }
}
fn dir_vec(direction: u32) -> vec2f {
    switch direction {
        case 1u: { return vec2f(-1.0, 0.0); }
        case 2u: { return vec2f(0.0, 1.0); }
        case 3u: { return vec2f(0.0, -1.0); }
        default: { return vec2f(1.0, 0.0); }
    }
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let p = clamp(gobofx_globals.progress, 0.0, 1.0);
    let cut = select(a, b, p >= 0.5);
    let half = clamp(params.width, 0.05, 1.0) * 0.5;
    let k = (1.0 - smoothstep(0.0, half, abs(p - 0.5))) * clamp(params.density, 0.0, 1.0);
    let cell = max(params.grain, 1.0);
    let frame = floor(gobofx_globals.time * 30.0);
    let g = floor(uv * gobofx_globals.resolution / cell) + vec2f(frame * 7.0, frame * 13.0);
    let snow = hash21(g);
    let line = 0.5 + 0.5 * sin(uv.y * gobofx_globals.resolution.y * 1.5 + gobofx_globals.time * 40.0);
    let v = mix(0.15, 1.0, snow) * mix(1.0, 0.4 + 0.6 * line, clamp(params.scanlines, 0.0, 1.0));
    return mix(cut, vec4f(vec3f(v), 1.0), k);
}
