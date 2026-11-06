// Wipe — a straight soft edge sweeps across, revealing `to`. The `wobble`
// signal bends the edge.
struct Params {
    direction: u32, // choice
    softness: f32,  // float — edge width in uv units
    ease: f32,      // float
}
@group(1) @binding(0) var<uniform> params: Params;

struct Signals {
    wobble: f32,    // 0..1, cc 1 — bends the wipe edge
}
@group(1) @binding(1) var<uniform> gobofx_signals: Signals;

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
    let x = axis(uv, params.direction);
    let t = eased(params.ease);
    let s = clamp(params.softness, 0.0, 0.5);
    let wobble = 0.05 * gobofx_signals.wobble * sin(uv.y * 40.0 + gobofx_globals.time * 6.0);
    // The edge travels from -s to 1+s (plus the wobble's reach) so both ends are exact.
    let reach = s + 0.05;
    let edge = t * (1.0 + 2.0 * reach) - reach + wobble;
    let keep_a = smoothstep(edge - s, edge + s, x);
    return mix(b, a, keep_a);
}
