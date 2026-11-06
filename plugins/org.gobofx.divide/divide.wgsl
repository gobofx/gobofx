// Divide — `from` splits into strips that slide off-frame in alternating
// directions, staggered, revealing `to` behind.
struct Params {
    strips: i32,      // int — number of strips
    orientation: u32, // choice — 0 horizontal strips (slide sideways), 1 vertical
    stagger: f32,     // float — 0 all at once … 1 one after another
    ease: f32,        // float
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
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let t = eased(params.ease);
    let n = f32(clamp(params.strips, 2, 32));
    let st = clamp(params.stagger, 0.0, 1.0);
    let across = select(uv.y, uv.x, params.orientation == 1u); // coordinate that indexes strips
    let idx = floor(across * n);
    let order = idx / max(n - 1.0, 1.0);
    // Local progress: strips start at order*st and all finish by t = 1.
    let lt = clamp((t * (1.0 + st) - order * st), 0.0, 1.0);
    let sign = select(-1.0, 1.0, (i32(idx) & 1) == 0);
    let shift = sign * lt;
    let src = select(uv + vec2f(shift, 0.0), uv + vec2f(0.0, shift), params.orientation == 1u);
    // Keep the sample inside the strip's own band so neighbours don't bleed in.
    let a = from_at(src);
    return over(a, b);
}
