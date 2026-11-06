// Color Emboss — the picture pressed into relief, lit from one direction,
// keeping its colour: the tonal difference across a short step is added to
// the picture as light and shadow, instead of replacing it with grey.
struct Params {
    angle: f32,  // float — direction the light comes from, in degrees
    height: f32, // float — relief depth, the step between the two taps, in pixels
    amount: f32, // float — strength of the relief; 0 is the source
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// Gamma-encoded luma of the premultiplied sample, so an alpha edge is a
// ridge too and dark detail counts as much as bright.
fn lum_at(uv: vec2f) -> f32 {
    return pow(max(luma(src_at(uv).rgb), 0.0), 1.0 / 2.2);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let a = radians(params.angle);
    let h = clamp(params.height, 0.5, 10.0);
    let step_uv = vec2f(cos(a), sin(a)) * h * gobofx_globals.texel;
    // Lit side minus shadow side: a slope facing the light reads brighter.
    let relief = lum_at(uv - step_uv) - lum_at(uv + step_uv);
    let src = src_at(uv);
    let c = pow(max(unpremultiply(src), vec3f(0.0)), vec3f(1.0 / 2.2));
    let lit = max(c + vec3f(relief * clamp(params.amount, 0.0, 3.0)), vec3f(0.0));
    let o = pow(lit, vec3f(2.2));
    return vec4f(o * src.a, src.a);
}
