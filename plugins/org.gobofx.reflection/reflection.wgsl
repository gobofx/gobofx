// Reflection — the frame pulls back to a card standing on a reflective
// floor; `from` rises out of the top while its reflection fades, `to` rises
// in from below to take its place, then fills the frame again.
struct Params {
    size: f32,       // float — the card's scale while it stands on the floor
    reflection: f32, // float — strength of the mirrored copy on the floor
    ease: f32,       // float
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
fn clip_at(uv: vec2f, which: u32) -> vec4f {
    if (which == 0u) { return from_at(uv); }
    return to_at(uv);
}
// A card centred horizontally at height `cy`, scaled by `s`; (0,0) if the
// pixel is off the card.
fn card(uv: vec2f, cy: f32, s: f32, which: u32) -> vec4f {
    let q = (uv - vec2f(0.5, cy)) / s;
    if (any(abs(q) > vec2f(0.5))) { return vec4f(0.0); }
    return clip_at(q + 0.5, which);
}
// The card's mirror image below its bottom edge, fading with distance.
fn reflection(uv: vec2f, cy: f32, s: f32, which: u32, k: f32) -> vec4f {
    let bottom = cy + 0.5 * s;
    if (k <= 0.0 || uv.y <= bottom) { return vec4f(0.0); }
    let dist = (uv.y - bottom) / s; // 0 at the edge, 1 a full card height below
    if (dist >= 1.0) { return vec4f(0.0); }
    let fade = k * (1.0 - dist) * (1.0 - dist);
    return card(vec2f(uv.x, 2.0 * bottom - uv.y), cy, s, which) * fade;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let pull = smoothstep(0.0, 0.3, t);  // the frame becomes a card on the floor
    let slide = smoothstep(0.3, 0.7, t); // `from` up and out, `to` up and in
    let push = smoothstep(0.7, 1.0, t);  // the card grows back to the frame
    let sz = clamp(params.size, 0.4, 0.9);
    let k = clamp(params.reflection, 0.0, 1.0);
    // Standing on the floor the card sits a little high, leaving room for its reflection.
    let rest = 0.5 - (1.0 - sz) * 0.35;
    let exit = rest + 0.5 * sz + 0.05;  // travel that takes the card off the top
    let enter = 1.0 + 0.5 * sz + 0.05;  // centre height that puts a card below the frame
    let sa = mix(1.0, sz, pull);
    let ca = mix(0.5, rest, pull) - slide * exit;
    let sb = mix(sz, 1.0, push);
    let cb = mix(mix(enter, rest, slide), 0.5, push);
    let ka = k * pull * (1.0 - slide);
    let kb = k * (1.0 - push);
    let floor_layer = over(reflection(uv, ca, sa, 0u, ka), reflection(uv, cb, sb, 1u, kb));
    return over(card(uv, ca, sa, 0u), over(card(uv, cb, sb, 1u), floor_layer));
}
