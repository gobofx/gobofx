// Noise — value, Perlin (gradient) or cellular (Worley) noise, layered as
// fractal Brownian motion and drifting with time. Maps 0..1 onto two colours.
struct Params {
    style: u32,     // choice — 0 value, 1 perlin, 2 cellular
    scale: f32,     // float — cells across the frame height
    octaves: i32,   // int — fBm layers, 1..6
    speed: f32,     // float — drift in cells per second
    contrast: f32,  // float — 1 linear; higher sharpens
    color_a: vec4f, // color — at 0
    color_b: vec4f, // color — at 1
}
@group(1) @binding(0) var<uniform> params: Params;

// Integer-free hashes (portable, deterministic on every backend).
fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
fn hash22(p: vec2f) -> vec2f {
    let h = vec2f(hash21(p), hash21(p + vec2f(17.1, 31.7)));
    return h;
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
fn grad(i: vec2f) -> vec2f {
    let a = hash21(i) * 6.28318530718;
    return vec2f(cos(a), sin(a));
}
fn perlin_noise(p: vec2f) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    let a = dot(grad(i), f);
    let b = dot(grad(i + vec2f(1.0, 0.0)), f - vec2f(1.0, 0.0));
    let c = dot(grad(i + vec2f(0.0, 1.0)), f - vec2f(0.0, 1.0));
    let d = dot(grad(i + vec2f(1.0, 1.0)), f - vec2f(1.0, 1.0));
    return 0.5 + 0.5 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 1.4142;
}
fn cellular_noise(p: vec2f) -> f32 {
    let i = floor(p);
    let f = fract(p);
    var best = 8.0;
    for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
            let o = vec2f(f32(x), f32(y));
            let site = o + hash22(i + o);
            best = min(best, dot(site - f, site - f));
        }
    }
    return clamp(sqrt(best), 0.0, 1.0);
}

fn base(p: vec2f) -> f32 {
    switch params.style {
        case 0u: { return value_noise(p); }
        case 2u: { return 1.0 - cellular_noise(p); }
        default: { return perlin_noise(p); }
    }
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let drift = vec2f(0.37, 0.61) * gobofx_globals.time * params.speed;
    var p = uv * vec2f(aspect, 1.0) * max(params.scale, 0.5) + drift;
    let octaves = clamp(params.octaves, 1, 6);
    var sum = 0.0;
    var amp = 0.5;
    var norm = 0.0;
    for (var i = 0; i < 6; i++) {
        if (i >= octaves) { break; }
        sum += amp * base(p);
        norm += amp;
        amp *= 0.5;
        p = p * 2.03 + vec2f(13.7, 7.1);
    }
    var n = sum / max(norm, 1e-4);
    n = clamp(0.5 + (n - 0.5) * max(params.contrast, 0.2), 0.0, 1.0);
    return mix(params.color_a, params.color_b, n);
}
