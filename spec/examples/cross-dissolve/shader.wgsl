// Cross Dissolve — linear blend from `from` to `to`.
// `ease` morphs the timing curve from linear (0) to smoothstep (1).

struct Params {
    ease: f32,
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let a = textureSampleLevel(wisp_input0, wisp_sampler, uv, 0.0);
    let b = textureSampleLevel(wisp_input1, wisp_sampler, uv, 0.0);
    let p = clamp(wisp_globals.progress, 0.0, 1.0);
    let t = mix(p, smoothstep(0.0, 1.0, p), params.ease);
    return mix(a, b, t); // premultiplied: a plain mix is correct
}
