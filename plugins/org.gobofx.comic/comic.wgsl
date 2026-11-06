// Comic — the ink-and-colour comic look: colour posterised to a few flat
// levels, slightly punched, with dark Sobel edges inked on top.
struct Params {
    levels: i32,    // int — flat colour steps per channel
    threshold: f32, // float — gradient needed to ink an edge; 0 traces everything
    ink: vec4f,     // color — the line colour (premultiplied)
    amount: f32,    // float — 0 is the source, 1 the full look
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

// Gamma-encoded luma of the premultiplied sample: dark steps count as much
// as bright ones, and the alpha edge of a cut-out gets a line too.
fn lum_at(uv: vec2f) -> f32 {
    return pow(max(luma(src_at(uv).rgb), 0.0), 1.0 / 2.2);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    // Sobel over a 1.5 px tap spacing: lines thick enough to read as ink.
    let d = 1.5 * gobofx_globals.texel;
    let tl = lum_at(uv + vec2f(-d.x, -d.y));
    let tc = lum_at(uv + vec2f(0.0, -d.y));
    let tr = lum_at(uv + vec2f(d.x, -d.y));
    let ml = lum_at(uv + vec2f(-d.x, 0.0));
    let mr = lum_at(uv + vec2f(d.x, 0.0));
    let bl = lum_at(uv + vec2f(-d.x, d.y));
    let bc = lum_at(uv + vec2f(0.0, d.y));
    let br = lum_at(uv + vec2f(d.x, d.y));
    let gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
    let gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
    let g = length(vec2f(gx, gy)) * 0.25;
    let t = clamp(params.threshold, 0.0, 1.0);
    let e = smoothstep(t, t + 0.1 + 0.2 * t, g) * params.ink.a;

    // Flat colour: posterise each channel in display gamma, then a little
    // extra saturation so the fills pop like printed colour.
    let src = src_at(uv);
    let c = max(unpremultiply(src), vec3f(0.0));
    let n = f32(clamp(params.levels, 2, 16)) - 1.0;
    let p = pow(c, vec3f(1.0 / 2.2));
    var flat = pow(round(p * n) / n, vec3f(2.2));
    flat = max(mix(vec3f(luma(flat)), flat, 1.3), vec3f(0.0));

    let o = mix(flat, unpremultiply(params.ink), e);
    let comic = vec4f(o * src.a, src.a);
    return mix(src, comic, clamp(params.amount, 0.0, 1.0));
}
