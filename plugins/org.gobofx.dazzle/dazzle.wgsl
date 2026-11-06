// Dazzle — star-shaped glints on the highlights. Pass 1 keeps what is above
// the threshold; the star is drawn by marching from each pixel back along
// `points` directions through that image, so a highlight throws an arm out
// along each one. The arms are split over two passes (half the directions
// each) to keep the per-pixel tap count sane; pass 4 adds them to the
// source. Intensity 0 passes through.
override HALF: f32 = 0.0;
const MAX_POINTS: i32 = 8;
const STEPS: i32 = 24;
const PI: f32 = 3.14159265359;

struct Params {
    threshold: f32, // float — brightness that glints
    points: i32,    // int — arms on the star (4 to 8)
    length: f32,    // float — arm length in pixels
    intensity: f32, // float — strength
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
// Outside the frame nothing glints; clamp-to-edge would streak the border.
fn bright_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), src_at(uv), inside);
}

@fragment
fn fs_bright(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let y = luma(unpremultiply(src));
    let t = clamp(params.threshold, 0.0, 1.0);
    // Linear ramp from the threshold to white, so threshold 1 glints nothing.
    let k = clamp((y - t) / max(1.0 - t, 0.02), 0.0, 1.0);
    return src * k;
}

@fragment
fn fs_star(@location(0) uv: vec2f) -> @location(0) vec4f {
    let n = clamp(params.points, 4, MAX_POINTS);
    let first = (n + 1) / 2;
    let lo = select(0, first, HALF > 0.5);
    let hi = select(first, n, HALF > 0.5);
    let step = clamp(params.length, 1.0, 128.0) / f32(STEPS);
    // The earlier half's arms arrive on input1 (the 1×1 transparent texture
    // in the first star pass, so this is zero there).
    var acc = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    for (var i = 0; i < MAX_POINTS; i++) {
        if (i < lo || i >= hi) { continue; }
        // One arm points straight up; the rest are spread evenly.
        let ang = 2.0 * PI * f32(i) / f32(n) - PI * 0.5;
        let dir = vec2f(cos(ang), sin(ang)) * gobofx_globals.texel * step;
        var sum = vec4f(0.0);
        var wsum = 0.0;
        for (var s = 1; s <= STEPS; s++) {
            let x = f32(s) / f32(STEPS);
            let w = (1.0 - x) * (1.0 - x);
            // Looking back along -dir puts the arm out along +dir.
            sum += bright_at(uv - dir * f32(s)) * w;
            wsum += w;
        }
        acc += sum / wsum;
    }
    return acc;
}

@fragment
fn fs_add(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let star = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let k = clamp(params.intensity, 0.0, 3.0) * 0.5;
    let a = clamp(src.a + star.a * k, 0.0, 1.0);
    return vec4f(src.rgb + star.rgb * k, a);
}
