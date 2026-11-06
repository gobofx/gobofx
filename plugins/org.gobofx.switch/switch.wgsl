// Switch — a push that waits, snaps across in a blink and settles, with
// motion blur proportional to the speed so the snap reads as movement.
const SAMPLES: i32 = 16;

struct Params {
    direction: u32, // choice — the way the pair travels
    snap: f32,      // float — 0 a smooth slide, 1 a hard snap at the midpoint
    blur: f32,      // float — motion blur at full speed
    ease: f32,      // float
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

// Position along the move and speed (0..1, peaking at the midpoint) for a
// symmetric power curve; the ends have zero speed so they stay sharp.
fn curve(t: f32, e: f32) -> vec2f {
    if (t < 0.5) {
        let x = 2.0 * t;
        return vec2f(0.5 * pow(x, e), pow(x, e - 1.0));
    }
    let x = 2.0 * (1.0 - t);
    return vec2f(1.0 - 0.5 * pow(x, e), pow(x, e - 1.0));
}
// `over`, not a sum: the two edge tests both pass on the exact seam, and a
// jittered sample can land there.
fn pushed(q: vec2f, d: vec2f, p: f32) -> vec4f {
    return over(to_at(q - d * (p - 1.0)), from_at(q - d * p));
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let e = 2.0 + 4.0 * clamp(params.snap, 0.0, 1.0);
    let cv = curve(t, e);
    let d = dir_vec(params.direction);
    let len = clamp(params.blur, 0.0, 1.0) * 0.35 * cv.y; // shutter, in frames
    if (len < 1e-5) {
        return pushed(uv, d, cv.x);
    }
    let j = hash21(uv * gobofx_globals.resolution); // per-pixel jitter hides the sample steps
    var acc = vec4f(0.0);
    for (var i = 0; i < SAMPLES; i++) {
        let k = (f32(i) + j) / f32(SAMPLES) - 0.5;
        acc += pushed(uv, d, cv.x + k * len);
    }
    return acc / f32(SAMPLES);
}
