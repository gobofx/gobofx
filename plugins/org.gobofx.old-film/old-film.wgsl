// Old Film — scratches, dust, flicker, gate jitter, grain, sepia and a vignette.
struct Params {
    scratches: f32, // float
    dust: f32,      // float
    flicker: f32,   // float — brightness flicker
    jitter: f32,    // float — vertical frame weave
    grain: f32,     // float
    sepia: f32,     // float
    vignette: f32,  // float
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

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let res = gobofx_globals.resolution;
    let frame = floor(gobofx_globals.time * 24.0);
    // Gate weave: the whole frame jumps a little every frame.
    let weave = (hash21(vec2f(frame, 3.0)) - 0.5) * 0.03 * params.jitter;
    let src = src_at(uv + vec2f(0.0, weave));
    var c = unpremultiply(src);
    // Sepia.
    let y = luma(c);
    let sep = vec3f(y * 1.1, y * 0.95, y * 0.75);
    c = mix(c, sep, clamp(params.sepia, 0.0, 1.0));
    // Flicker.
    c *= 1.0 + (hash21(vec2f(frame, 7.0)) - 0.5) * 0.4 * params.flicker;
    // Grain.
    let g = hash21(floor(uv * res / 1.5) + frame * 5.0) - 0.5;
    c += g * 0.15 * params.grain;
    // Scratches: a few vertical hairlines that drift from frame to frame.
    var sc = 0.0;
    for (var i = 0; i < 4; i++) {
        let fi = f32(i);
        let x = hash21(vec2f(fi, floor(frame / 3.0) + fi)) + (hash21(vec2f(frame, fi)) - 0.5) * 0.01;
        let on = step(1.0 - params.scratches * 0.9, hash21(vec2f(frame * 0.5, fi + 20.0)));
        sc += on * (1.0 - smoothstep(0.0, 1.5 * gobofx_globals.texel.x, abs(uv.x - x)));
    }
    c = mix(c, vec3f(0.9), clamp(sc, 0.0, 1.0) * 0.7);
    // Dust: dark specks in a coarse grid that changes every frame.
    let cell = floor(uv * res / 12.0);
    let hd = hash21(cell + frame * 11.0);
    let spot = length(fract(uv * res / 12.0) - 0.5 - (vec2f(hash21(cell + 1.0), hash21(cell + 2.0)) - 0.5) * 0.6);
    let dust = step(1.0 - params.dust * 0.08, hd) * (1.0 - smoothstep(0.0, 0.18, spot));
    c = mix(c, vec3f(0.05), dust);
    // Vignette.
    let aspect = res.x / res.y;
    let d = (uv - 0.5) * vec2f(aspect, 1.0);
    c *= 1.0 - params.vignette * smoothstep(0.35, 0.9, length(d));
    c = max(c, vec3f(0.0));
    return vec4f(c * src.a, src.a);
}
