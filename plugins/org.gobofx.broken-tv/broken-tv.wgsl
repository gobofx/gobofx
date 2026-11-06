// Broken TV — a hum bar rolls up the picture; inside it the rows tear
// sideways, snow breaks through and the colours misconverge. Everything
// is keyed off a 24 fps frame counter, so a given time always renders the
// same frame.
struct Params {
    speed: f32,       // float — rolls per second
    band_height: f32, // float — height of the interference band, % of frame
    tear: f32,        // float — horizontal row displacement inside the band, px
    noise: f32,       // float — snow inside the band
    fringing: f32,    // float — red/blue misconvergence, px
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
    let texel = gobofx_globals.texel;
    let frame = floor(gobofx_globals.time * 24.0);
    // The band rolls upward; its centre wraps around the frame.
    let roll = fract(gobofx_globals.time * params.speed);
    let half = clamp(params.band_height, 2.0, 100.0) * 0.005;
    let dy = abs(fract(uv.y + roll + 0.5) - 0.5);
    // Flat top with a soft shoulder, so the bar reads as a bar, not a glow.
    let band = 1.0 - smoothstep(half * 0.6, half, dy);
    // Tear: every 2 px row inside the band slides by its own amount, on top
    // of a shift the whole band shares this frame.
    let row = floor(uv.y * res.y * 0.5);
    let band_shift = (hash21(vec2f(frame, 1.0)) - 0.5) * 0.6;
    let per_row = hash21(vec2f(row, frame)) - 0.5;
    let dx = (band_shift + per_row) * params.tear * band * texel.x;
    let p = vec2f(uv.x + dx, uv.y);
    // Misconvergence: red and blue drift apart, a little everywhere and
    // fully inside the band.
    let f = params.fringing * (0.3 + 0.7 * band) * texel.x;
    let sc = src_at(p);
    let sr = src_at(p + vec2f(f, 0.0));
    let sb = src_at(p - vec2f(f, 0.0));
    var c = vec3f(unpremultiply(sr).r, unpremultiply(sc).g, unpremultiply(sb).b);
    // Snow: per-pixel static that only breaks through inside the band, plus
    // the dark 2 px scanlines of a tube.
    let h = hash21(floor(uv * res) + frame * vec2f(3.1, 7.3));
    let snow = h * h * h * h * 1.2; // mostly dark with bright specks, not a grey wash
    let k = clamp(params.noise, 0.0, 1.0);
    c = mix(c, vec3f(snow), k * band * 0.6);
    c *= 1.0 - 0.25 * k * step(0.5, fract(uv.y * res.y * 0.5));
    // The bar itself is dark, with a bright leading edge.
    c *= 1.0 - 0.6 * band;
    let rim = 1.0 - smoothstep(0.0, half * 0.2, abs(dy - half * 0.7));
    c += vec3f(0.25) * band * rim;
    c = max(c, vec3f(0.0));
    return vec4f(c * sc.a, sc.a);
}
