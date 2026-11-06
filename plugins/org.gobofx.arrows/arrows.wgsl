// Arrows — a row of chevrons, drawn as a coloured band, sweeps across the
// frame with `to` following behind it.
struct Params {
    direction: u32, // choice
    count: i32,     // int — chevrons across the frame
    depth: f32,     // float — how far each chevron's tip leads its notches, in uv
    band: f32,      // float — width of the coloured band, in uv
    color: vec4f,   // color — premultiplied
    softness: f32,  // float — feather of the band's edges, in uv
    ease: f32,      // float
}
@group(1) @binding(0) var<uniform> params: Params;

fn eased(ease: f32) -> f32 {
    let p = clamp(gobofx_globals.progress, 0.0, 1.0);
    return mix(p, smoothstep(0.0, 1.0, p), clamp(ease, 0.0, 1.0));
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

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let x = axis(uv, params.direction);
    let across = select(uv.x, uv.y, params.direction <= 1u);
    let n = f32(clamp(params.count, 1, 16));
    let depth = clamp(params.depth, 0.0, 0.5);
    let band = clamp(params.band, 0.0, 0.3);
    // Never a zero-width feather: smoothstep with equal edges is undefined.
    let s = max(clamp(params.softness, 0.0, 0.1), 0.5 * gobofx_globals.texel.x);
    // Chevron profile: the tip of each tooth leads, its notches trail by `depth`.
    let chevron = depth * abs(fract(across * n) * 2.0 - 1.0);
    // The band travels far enough past both frame edges for the endpoints to be exact.
    let reach = depth + band + s;
    let lead = -reach + eased(params.ease) * (1.0 + 2.0 * reach);
    let front = lead - chevron;
    let back = front - band;
    let keep_a = smoothstep(front - s, front + s, x);
    let keep_b = 1.0 - smoothstep(back - s, back + s, x);
    let in_band = clamp(1.0 - keep_a - keep_b, 0.0, 1.0);
    return a * keep_a + b * keep_b + params.color * in_band;
}
