// Circle Screen — the picture as a print screen of concentric rings around
// one point: ink on paper, each ring's width following the tone along it.
struct Params {
    center: vec2f, // point — the rings' common centre
    size: f32,     // float — ring pitch in pixels (centre-to-centre spacing)
    ink: vec4f,    // color — the ring colour (premultiplied)
    paper: vec4f,  // color — the colour between rings (premultiplied)
    amount: f32,   // float — 0 is the source, 1 is the full screen
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

// Perceptual (gamma-encoded) straight colour at a point, 0..1.
fn tone_at(uv: vec2f) -> vec3f {
    let s = src_at(uv);
    return pow(clamp(unpremultiply(s), vec3f(0.0), vec3f(1.0)), vec3f(1.0 / 2.2));
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let res = gobofx_globals.resolution;
    let px = uv * res;
    let s = clamp(params.size, 2.0, 64.0);
    let centre = params.center * res;
    let rel = px - centre;
    let r = length(rel);
    // The ring this pixel falls in, and its centre line's radius.
    let rc = (floor(r / s) + 0.5) * s;
    let dist = abs(r - rc);
    // Tone is read on the ring's centre line, radially in from this pixel,
    // so the ring thickens and thins along its length with the picture.
    let dir = select(vec2f(1.0, 0.0), rel / max(r, 1e-4), r > 1e-4);
    let on_ring = centre + dir * rc;
    let d = 1.0 - luma(tone_at(on_ring / res));
    // Ink width is the darkness: a black area is a solid ring, a white one none.
    let hw = clamp(d, 0.0, 1.0) * s * 0.5;
    let cover = 1.0 - smoothstep(hw - 0.7, hw + 0.7, dist);
    let o = mix(unpremultiply(params.paper), unpremultiply(params.ink), cover);
    let src = src_at(uv);
    // The print keeps the source's shape: transparent stays transparent.
    let screened = vec4f(o * src.a, src.a);
    return mix(src, screened, clamp(params.amount, 0.0, 1.0));
}
