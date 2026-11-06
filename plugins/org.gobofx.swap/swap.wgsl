// Swap — two cards trade places in depth: `from` swings aside and shrinks
// into the background while `to` swings out from behind it and grows to
// fill the frame. They pass each other at the midpoint.
const SWING: f32 = 0.45; // how far each card swings aside, in frames

struct Params {
    direction: u32, // choice — the side `from` swings to (`to` takes the other)
    depth: f32,     // float — how small the card at the back gets
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

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let side = -dir_vec(params.direction); // options are left, right, up, down
    let dp = clamp(params.depth, 0.0, 1.0);
    let swing = sin(t * 3.14159265) * SWING;
    let sa = 1.0 - dp * t;          // `from` shrinks …
    let sb = 1.0 - dp * (1.0 - t);  // … `to` grows
    let ca = 0.5 + side * swing;
    let cb = 0.5 - side * swing;
    var a = from_at((uv - ca) / sa + 0.5);
    var b = to_at((uv - cb) / sb + 0.5);
    // The card at the back sits in shade.
    a = vec4f(a.rgb * (1.0 - 0.4 * (1.0 - sa)), a.a);
    b = vec4f(b.rgb * (1.0 - 0.4 * (1.0 - sb)), b.a);
    // Fade the back card at the ends so translucent clips still land exactly.
    a = a * (1.0 - smoothstep(0.9, 1.0, t)) * (1.0 - step(1.0, t));
    b = b * smoothstep(0.0, 0.1, t);
    if (t < 0.5) {
        return over(a, b);
    }
    return over(b, a);
}
