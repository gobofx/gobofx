// Cross Dissolve — linear blend from `from` to `to`.
// `ease` morphs the timing curve from linear (0) to smoothstep (1).

struct Params {
    ease: f32,
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let p = clamp(gobofx_globals.progress, 0.0, 1.0);
    let t = mix(p, smoothstep(0.0, 1.0, p), params.ease);
    return mix(a, b, t); // premultiplied: a plain mix is correct
}
