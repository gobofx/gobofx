// Flip — a card with `from` on the front and `to` on the back turns over.
struct Params {
    axis: u32,        // choice — 0 turn about the vertical axis, 1 about the horizontal
    perspective: f32, // float — 0 flat, 1 strong foreshortening
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
    let t = eased(params.ease);
    let theta = t * 3.14159265;
    let c = cos(theta);
    let s = sin(theta);
    // Work in card space centred on the frame; `u` is the axis that foreshortens.
    var p = uv - 0.5;
    if (params.axis == 1u) { p = vec2f(p.y, p.x); }
    if (abs(c) < 1e-4) { return vec4f(0.0); } // edge-on: nothing visible
    let u = p.x / c;                                   // undo the foreshortening
    let k = clamp(params.perspective, 0.0, 1.0) * 0.8;
    let v = p.y / (1.0 + k * u * s);                   // the near edge looks bigger
    if (abs(u) > 0.5 || abs(v) > 0.5) { return vec4f(0.0); }
    var card = vec2f(u, v) + 0.5;
    if (params.axis == 1u) { card = vec2f(card.y, card.x); }
    if (c > 0.0) {
        return textureSampleLevel(gobofx_input0, gobofx_sampler, card, 0.0);
    }
    // Back face: mirrored along the turning axis so `to` reads correctly at the end.
    var back = card;
    if (params.axis == 1u) { back.y = 1.0 - back.y; } else { back.x = 1.0 - back.x; }
    return textureSampleLevel(gobofx_input1, gobofx_sampler, back, 0.0);
}
