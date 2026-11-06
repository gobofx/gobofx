// Drop In — `to` falls into frame from the top over `from`, lands with a
// bounce and settles exactly on the last frame.
struct Params {
    bounce: f32, // float — 0 lands softly, 1 bounces hard
    shadow: f32, // float — the shadow `to` throws on `from` ahead of its edge
    ease: f32,   // float
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

// The classic ease-out bounce: four parabolas, exactly 1 at x = 1.
fn out_bounce(x: f32) -> f32 {
    let n = 7.5625;
    let d = 2.75;
    if (x < 1.0 / d) {
        return n * x * x;
    } else if (x < 2.0 / d) {
        let y = x - 1.5 / d;
        return n * y * y + 0.75;
    } else if (x < 2.5 / d) {
        let y = x - 2.25 / d;
        return n * y * y + 0.9375;
    }
    let y = x - 2.625 / d;
    return n * y * y + 0.984375;
}
fn out_cubic(x: f32) -> f32 {
    let y = 1.0 - x;
    return 1.0 - y * y * y;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    var f = mix(out_cubic(t), out_bounce(t), clamp(params.bounce, 0.0, 1.0));
    f = select(f, 1.0, t >= 1.0); // settle exactly
    // `to`'s bottom edge is at y = f; above it is `to`, below it `from`.
    let b = to_at(uv + vec2f(0.0, 1.0 - f));
    var a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    // Soft shadow on `from` just below the falling edge; none once settled.
    // The shadow grows in with the card, so nothing is cast while it is still off-frame.
    let dist = uv.y - f;
    let sh = clamp(params.shadow, 0.0, 1.0) * smoothstep(0.0, 0.1, f)
        * (1.0 - smoothstep(0.0, 0.12, dist)) * step(0.0, dist);
    a = vec4f(a.rgb * (1.0 - 0.7 * sh), a.a);
    // `from` stays underneath until the very end, then drops out so a
    // translucent `to` lands exactly on `to`.
    a = a * (1.0 - step(1.0, t));
    return over(b, a);
}
