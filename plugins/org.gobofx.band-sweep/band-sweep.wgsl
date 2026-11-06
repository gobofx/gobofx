// Band Sweep — a graphic band sweeps across the lower part of the frame;
// the cut to `to` is a slanted wipe that rides on its trailing edge.
struct Params {
    direction: u32, // choice — 0 left to right, 1 right to left
    height: f32,    // float — band height, fraction of the frame
    offset: f32,    // float — gap between the band and the bottom edge
    width: f32,     // float — band length, fraction of the frame width
    slant: f32,     // float — tilt of the band ends and the wipe edge, degrees
    color: vec4f,   // color — premultiplied
    softness: f32,  // float — feather of every edge, in uv
    ease: f32,      // float
}
@group(1) @binding(0) var<uniform> params: Params;

fn eased(ease: f32) -> f32 {
    let p = clamp(gobofx_globals.progress, 0.0, 1.0);
    return mix(p, smoothstep(0.0, 1.0, p), clamp(ease, 0.0, 1.0));
}
// Premultiplied `over`.
fn over(top: vec4f, bottom: vec4f) -> vec4f {
    return top + bottom * (1.0 - top.a);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let x = select(uv.x, 1.0 - uv.x, params.direction == 1u);
    let h = clamp(params.height, 0.05, 0.5);
    let bottom = 1.0 - clamp(params.offset, 0.0, 0.5);
    let top = bottom - h;
    let mid = 0.5 * (top + bottom);
    let w = clamp(params.width, 0.1, 1.0);
    let slant = tan(radians(clamp(params.slant, -40.0, 40.0)));
    // Never a zero-width feather: smoothstep with equal edges is undefined.
    let s = max(clamp(params.softness, 0.0, 0.1), 0.5 * gobofx_globals.texel.x);
    // The slanted edge is a straight line through the band's middle; the band
    // starts and ends far enough off-frame for both endpoints to be exact.
    let xs = x + (uv.y - mid) * slant;
    let reach = abs(slant) + s;
    let lead = -reach + eased(params.ease) * (1.0 + w + 2.0 * reach);
    let trail = lead - w;
    let keep_b = 1.0 - smoothstep(trail - s, trail + s, xs);
    let along = smoothstep(trail - s, trail + s, xs) * (1.0 - smoothstep(lead - s, lead + s, xs));
    let within = smoothstep(top - s, top + s, uv.y) * (1.0 - smoothstep(bottom - s, bottom + s, uv.y));
    return over(params.color * along * within, mix(a, b, keep_b));
}
