// Brightness — add a constant to every channel in linear light and clamp at
// black. An offset, not a gain: the blacks lift or sink along with the rest,
// which is what the word means on a monitor. The default is a no-op.
struct Params {
    amount: f32, // float — -1 black .. 1, added to linear light
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = max(unpremultiply(src) + vec3f(clamp(params.amount, -1.0, 1.0)), vec3f(0.0));
    return vec4f(c * src.a, src.a);
}
