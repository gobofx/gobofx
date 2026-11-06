// Indent — press the picture into a surface. Luma is read as a height map
// with bright pressed deepest, and a directional light shades the slopes
// over the original colour: an inner bevel that keeps the picture.
struct Params {
    angle: f32,  // float — degrees; where the light comes from, 0 is from the right, 90 from above
    depth: f32,  // float — px; how deep the press is (tap spacing and shading strength)
    amount: f32, // float — 0 is the source, 1 is the full press
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

// Gamma-encoded luma of the premultiplied sample: the height map. Alpha
// edges count as height steps too, so a cut-out gets its own bevel.
fn height_at(uv: vec2f) -> f32 {
    return pow(max(luma(src_at(uv).rgb), 0.0), 1.0 / 2.2);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = unpremultiply(src);
    let depth = clamp(params.depth, 0.0, 8.0);
    let d = max(depth, 1.0) * gobofx_globals.texel;
    // Sobel gradient of the height map, with a full step at 1.
    let tl = height_at(uv + vec2f(-d.x, -d.y));
    let tc = height_at(uv + vec2f(0.0, -d.y));
    let tr = height_at(uv + vec2f(d.x, -d.y));
    let ml = height_at(uv + vec2f(-d.x, 0.0));
    let mr = height_at(uv + vec2f(d.x, 0.0));
    let bl = height_at(uv + vec2f(-d.x, d.y));
    let bc = height_at(uv + vec2f(0.0, d.y));
    let br = height_at(uv + vec2f(d.x, d.y));
    let gx = ((tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl)) * 0.25;
    let gy = ((bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr)) * 0.25;
    let a = radians(params.angle);
    let light = vec2f(cos(a), -sin(a)); // y up, so 90 is from above
    // Pressed in: the slope facing the light is the one that falls away from
    // it, so the sign is the inverse of a raised emboss.
    let s = clamp(dot(vec2f(gx, gy), light) * depth * 1.5, -1.0, 1.0);
    let shaded = c * (1.0 + s) + vec3f(max(s, 0.0) * 0.35);
    let o = mix(c, max(shaded, vec3f(0.0)), clamp(params.amount, 0.0, 1.0));
    return vec4f(o * src.a, src.a);
}
