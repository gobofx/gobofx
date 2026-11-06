// Edges — Sobel edge detection on perceptual luma, drawn in a colour on
// black, over the source, or as alpha so the lines stack on other clips.
struct Params {
    threshold: f32,    // float — gradient below this is not an edge
    thickness: f32,    // float — Sobel tap spacing in pixels; wider taps, wider lines
    mode: u32,         // choice — 0 on black, 1 over source, 2 as alpha
    edge_color: vec4f, // color — the line colour (premultiplied)
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}
fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// Gamma-encoded luma of the premultiplied sample: a dark-to-dark step
// counts as much as a bright one, and an alpha edge counts as an edge.
fn lum_at(uv: vec2f) -> f32 {
    let s = src_at(uv);
    return pow(max(luma(s.rgb), 0.0), 1.0 / 2.2);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let d = clamp(params.thickness, 1.0, 6.0) * gobofx_globals.texel;
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
    // /4 puts a full black-to-white step at 1.
    let g = length(vec2f(gx, gy)) * 0.25;
    let t = clamp(params.threshold, 0.0, 1.0);
    let e = smoothstep(t, t + 0.1 + 0.2 * t, g);
    let ink = unpremultiply(params.edge_color);
    let ea = e * params.edge_color.a;
    let src = src_at(uv);
    if (params.mode == 1u) {
        // Lines over the picture; where the source is transparent the line still shows.
        let a = src.a + ea * (1.0 - src.a);
        return vec4f(mix(src.rgb, ink, ea), a);
    }
    if (params.mode == 2u) {
        return vec4f(ink * ea, ea);
    }
    return vec4f(ink * ea, 1.0);
}
