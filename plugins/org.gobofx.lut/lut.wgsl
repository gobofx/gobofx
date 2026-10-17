// LUT — apply a .cube 3D lookup table (spec/assets.md). The LUT arrives on
// gobofx_input1 as the strip the spec fixes: N tiles of N×N, blue picks the
// tile, red the column, green the row. Two taps make the lookup trilinear.
// Nothing bound (a 1×1 texture) means identity.
struct Params {
    intensity: f32,   // float — 0 bypass … 1 full look (the `lut` asset param has no field)
    input_space: u32, // choice — 0 the LUT expects display sRGB, 1 linear light
}
@group(1) @binding(0) var<uniform> params: Params;

fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn linear_to_srgb(c: vec3f) -> vec3f {
    let lo = c * 12.92;
    let hi = 1.055 * pow(max(c, vec3f(0.0)), vec3f(1.0 / 2.4)) - 0.055;
    return select(hi, lo, c <= vec3f(0.0031308));
}
fn srgb_to_linear(c: vec3f) -> vec3f {
    let lo = c / 12.92;
    let hi = pow((max(c, vec3f(0.0)) + 0.055) / 1.055, vec3f(2.4));
    return select(hi, lo, c <= vec3f(0.04045));
}

// The reference lookup from spec/assets.md.
fn lut3d_sample(c: vec3f) -> vec3f {
    let dims = textureDimensions(gobofx_input1);
    if (dims.y <= 1u) { return c; }
    let n = f32(dims.y);
    let x = clamp(c, vec3f(0.0), vec3f(1.0)) * (n - 1.0);
    let b0 = floor(x.b);
    let b1 = min(b0 + 1.0, n - 1.0);
    let fb = x.b - b0;
    let uv0 = vec2f((b0 * n + x.r + 0.5) / (n * n), (x.g + 0.5) / n);
    let uv1 = vec2f((b1 * n + x.r + 0.5) / (n * n), (x.g + 0.5) / n);
    let s0 = textureSampleLevel(gobofx_input1, gobofx_sampler, uv0, 0.0).rgb;
    let s1 = textureSampleLevel(gobofx_input1, gobofx_sampler, uv1, 0.0).rgb;
    return mix(s0, s1, fb);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let lin = unpremultiply(src);
    var graded: vec3f;
    if (params.input_space == 1u) {
        graded = lut3d_sample(lin);
    } else {
        graded = srgb_to_linear(lut3d_sample(linear_to_srgb(lin)));
    }
    let o = mix(lin, graded, clamp(params.intensity, 0.0, 1.0));
    return vec4f(max(o, vec3f(0.0)) * src.a, src.a);
}
