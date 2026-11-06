// Line Art — pen-sketch outlines on paper. Sobel edges on perceptual luma
// become ink strokes; everything else is the paper colour, with a faint
// wash of the source tones so flat areas still read.
struct Params {
    threshold: f32, // float — gradient below this is not a line
    weight: f32,    // float — px; Sobel tap spacing, wider taps draw heavier strokes
    ink: vec4f,     // color — the pen (premultiplied)
    paper: vec4f,   // color — the sheet (premultiplied)
    amount: f32,    // float — 0 is the source, 1 is the sketch
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

// Gamma-encoded luma of the premultiplied sample, so a step in the shadows
// draws as readily as one in the highlights and alpha edges get a stroke.
fn lum_at(uv: vec2f) -> f32 {
    return pow(max(luma(src_at(uv).rgb), 0.0), 1.0 / 2.2);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = unpremultiply(src);
    let d = clamp(params.weight, 1.0, 6.0) * gobofx_globals.texel;
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
    let stroke = smoothstep(t, t + 0.08 + 0.2 * t, g);
    // A pen never lays a perfectly even line: a touch of grain in the stroke.
    let grain = 0.85 + 0.15 * hash21(floor(uv * gobofx_globals.resolution));
    let paper = unpremultiply(params.paper);
    let ink = unpremultiply(params.ink);
    // A faint wash of the source's tone keeps the dark areas from vanishing.
    let tone = pow(max(luma(c), 0.0), 1.0 / 2.2);
    let washed = mix(paper * 0.8, paper, smoothstep(0.0, 0.5, tone));
    let sketch = mix(washed, ink, stroke * grain * params.ink.a);
    let o = mix(c, sketch, clamp(params.amount, 0.0, 1.0));
    return vec4f(o * src.a, src.a);
}
