// Clouds — fractal value noise, warped once by itself so the blobs get
// the curls and tears of real cumulus, thresholded by coverage and drifting
// sideways with time. Two colours: the sky and the cloud; give the sky an
// alpha of 0 for clouds alone over a clip.
struct Params {
    scale: f32,     // float — cloud cells across the frame height
    octaves: i32,   // int — fBm layers, 1..6
    speed: f32,     // float — drift in cells per second
    coverage: f32,  // float — 0 clear sky, 1 overcast
    softness: f32,  // float — 0 hard cut-outs, 1 wispy haze
    color_a: vec4f, // color — sky, premultiplied
    color_b: vec4f, // color — cloud, premultiplied
}
@group(1) @binding(0) var<uniform> params: Params;

fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
fn value_noise(p: vec2f) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);
    let a = hash21(i);
    let b = hash21(i + vec2f(1.0, 0.0));
    let c = hash21(i + vec2f(0.0, 1.0));
    let d = hash21(i + vec2f(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
fn fbm(p_in: vec2f, octaves: i32) -> f32 {
    var p = p_in;
    var sum = 0.0;
    var amp = 0.5;
    var norm = 0.0;
    for (var i = 0; i < 6; i++) {
        if (i >= octaves) { break; }
        sum += amp * value_noise(p);
        norm += amp;
        amp *= 0.5;
        p = p * 2.03 + vec2f(13.7, 7.1);
    }
    return sum / max(norm, 1e-4);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let t = gobofx_globals.time * params.speed;
    // Clouds drift sideways; the inner detail moves a little slower so the
    // shapes evolve instead of sliding as a sheet.
    let p = uv * vec2f(aspect, 1.0) * max(params.scale, 0.5) + vec2f(t, t * 0.1);
    let octaves = clamp(params.octaves, 1, 6);
    let warp = fbm(p * 0.7 + vec2f(t * 0.3, 0.0), octaves);
    let n = fbm(p + (warp - 0.5) * 1.2, octaves);
    // fBm of value noise sits around 0.5 with a spread of about ±0.25;
    // map coverage onto that range so 0 and 1 really are clear and overcast.
    let threshold = mix(0.78, 0.22, clamp(params.coverage, 0.0, 1.0));
    let w = mix(0.02, 0.3, clamp(params.softness, 0.0, 1.0));
    let cloud = smoothstep(threshold - w, threshold + w, n);
    return mix(params.color_a, params.color_b, cloud);
}
