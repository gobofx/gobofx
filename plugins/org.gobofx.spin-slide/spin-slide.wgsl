// Spin Slide — `from` spins as it slides out one side while `to` spins in
// from the other, both turning the same way; the frame between them is
// transparent.
const TAU: f32 = 6.28318530718;

struct Params {
    direction: u32, // choice — the way the pair travels
    turns: f32,     // float — rotations each frame makes on its way
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

// Where on a frame centred at `centre`, turned by `ang`, this pixel lands.
fn card(uv: vec2f, centre: vec2f, ang: f32, aspect: f32) -> vec2f {
    var l = (uv - centre) * vec2f(aspect, 1.0);
    l = vec2f(l.x * cos(ang) + l.y * sin(ang), -l.x * sin(ang) + l.y * cos(ang));
    return l / vec2f(aspect, 1.0) + 0.5;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let d = dir_vec(params.direction);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let turns = clamp(params.turns, 0.25, 2.0);
    // Travel just far enough that a frame at any angle has cleared the
    // screen: half the screen along the move plus the frame's half diagonal.
    let size = vec2f(aspect, 1.0);
    let along = abs(d.x) * size.x + abs(d.y) * size.y;
    let travel = (0.5 * along + 0.5 * length(size) + 0.02) / along;
    // `from` accelerates out and `to` decelerates in, so they meet in the
    // middle instead of leaving the frame empty at the midpoint.
    let ca = 0.5 + d * t * t * travel;
    let cb = 0.5 - d * (1.0 - t) * (1.0 - t) * travel;
    let aa = turns * TAU * t;
    let ab = -turns * TAU * (1.0 - t);
    // Exact at the ends: `from` is gone at 1, `to` absent at 0.
    let a = from_at(card(uv, ca, aa, aspect)) * (1.0 - step(1.0, t));
    let b = to_at(card(uv, cb, ab, aspect)) * select(0.0, 1.0, t > 0.0);
    return over(b, a);
}
