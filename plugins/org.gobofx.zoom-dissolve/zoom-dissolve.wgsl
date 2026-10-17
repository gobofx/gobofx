// Zoom Dissolve — a radial zoom blur builds through the cut: `from` streaks
// outward as it fades, `to` arrives streaking inward.
const SAMPLES: i32 = 24;

struct Params {
    amount: f32,   // float — streak length as a fraction of the frame
    center: vec2f, // point — zoom origin
    ease: f32,     // float
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

fn zoom_from(uv: vec2f, strength: f32) -> vec4f {
    var acc = vec4f(0.0);
    let j = hash21(uv * gobofx_globals.resolution); // per-pixel jitter hides the sample steps
    for (var i = 0; i < SAMPLES; i++) {
        let k = (f32(i) + j) / f32(SAMPLES);
        let p = params.center + (uv - params.center) * (1.0 - strength * k);
        acc += textureSampleLevel(gobofx_input0, gobofx_sampler, p, 0.0);
    }
    return acc / f32(SAMPLES);
}
fn zoom_to(uv: vec2f, strength: f32) -> vec4f {
    var acc = vec4f(0.0);
    let j = hash21(uv * gobofx_globals.resolution);
    for (var i = 0; i < SAMPLES; i++) {
        let k = (f32(i) + j) / f32(SAMPLES);
        let p = params.center + (uv - params.center) * (1.0 + strength * k);
        acc += textureSampleLevel(gobofx_input1, gobofx_sampler, p, 0.0);
    }
    return acc / f32(SAMPLES);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let s = clamp(params.amount, 0.0, 1.0) * sin(t * 3.14159265);
    if (s < 1e-4) {
        let a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
        let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
        return mix(a, b, t);
    }
    return mix(zoom_from(uv, s), zoom_to(uv, s), t);
}
