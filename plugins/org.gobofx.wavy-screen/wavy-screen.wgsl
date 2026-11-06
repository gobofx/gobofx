// Wavy Screen — a line screen whose lines undulate: parallel ink lines
// bent by a sine wave, swelling where the picture is dark.
struct Params {
    pitch: f32,     // float — px; distance between line centres
    amplitude: f32, // float — px; how far the lines wander from straight
    frequency: f32, // float — waves per 100 px along the line
    angle: f32,     // float — degrees; direction of the lines, 0 is horizontal
    ink: vec4f,     // color — the line colour (premultiplied)
    paper: vec4f,   // color — the colour between the lines (premultiplied)
    amount: f32,    // float — 0 is the source, 1 is the full screen
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

const TAU: f32 = 6.28318530718;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = unpremultiply(src);
    let s = clamp(params.pitch, 2.0, 64.0);
    let a = radians(params.angle);
    let px = uv * gobofx_globals.resolution;
    // Rotate into the screen's frame: `along` runs with the lines, `across` crosses them.
    let along = cos(a) * px.x + sin(a) * px.y;
    let across = -sin(a) * px.x + cos(a) * px.y;
    let wave = clamp(params.amplitude, 0.0, 32.0) * sin(along * TAU * clamp(params.frequency, 0.1, 10.0) / 100.0);
    let dist = abs(fract((across + wave) / s) - 0.5) * s;
    // Ink density from the perceptual tone; the line's half-width follows it.
    let tone = pow(clamp(luma(c), 0.0, 1.0), 1.0 / 2.2);
    let half_w = (1.0 - tone) * s * 0.5;
    let cover = 1.0 - smoothstep(half_w - 0.6, half_w + 0.6, dist);
    let paper = unpremultiply(params.paper);
    let ink = unpremultiply(params.ink);
    let screen = mix(paper, ink, cover * params.ink.a);
    let o = mix(c, screen, clamp(params.amount, 0.0, 1.0));
    // The print keeps the source's shape: transparent stays transparent.
    return vec4f(o * src.a, src.a);
}
