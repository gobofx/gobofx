// Glint — small, crisp sparkles on the brightest spots. Pass 1 keeps what is
// above the (high) threshold; pass 2 draws a four-ray sparkle of `size`
// pixels at `angle` from each of those spots, with a sharp falloff so it
// reads as a specular ping rather than a flare, and adds it to the source.
// Intensity 0 passes through.
const RAYS: i32 = 4;
const STEPS: i32 = 16;
const PI: f32 = 3.14159265359;

struct Params {
    threshold: f32, // float — brightness that sparkles
    size: f32,      // float — ray length in pixels
    intensity: f32, // float — strength
    angle: f32,     // float — rotation of the cross, degrees
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
// Outside the frame nothing sparkles; clamp-to-edge would streak the border.
fn bright_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0), inside);
}

@fragment
fn fs_bright(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let y = luma(unpremultiply(src));
    let t = clamp(params.threshold, 0.0, 1.0);
    // Linear ramp from the threshold to white, so threshold 1 sparkles nothing.
    let k = clamp((y - t) / max(1.0 - t, 0.02), 0.0, 1.0);
    return src * k;
}

@fragment
fn fs_sparkle(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let k = clamp(params.intensity, 0.0, 3.0);
    let step = clamp(params.size, 1.0, 48.0) / f32(STEPS);
    let base = radians(params.angle);
    var acc = vec4f(0.0);
    for (var i = 0; i < RAYS; i++) {
        let ang = base + f32(i) * PI * 0.5;
        let dir = vec2f(cos(ang), sin(ang)) * gobofx_globals.texel * step;
        var sum = vec4f(0.0);
        var wsum = 0.0;
        for (var s = 1; s <= STEPS; s++) {
            let x = f32(s) / f32(STEPS);
            // Cubic falloff: a bright pip with short, fast-fading rays.
            let w = (1.0 - x) * (1.0 - x) * (1.0 - x);
            sum += bright_at(uv - dir * f32(s)) * w;
            wsum += w;
        }
        acc += sum / wsum;
    }
    let sparkle = acc * 0.75 * k;
    let a = clamp(src.a + sparkle.a, 0.0, 1.0);
    return vec4f(src.rgb + sparkle.rgb, a);
}
