// Film Burn — a frame catching fire in the gate, over transparent. The
// burn eats in from one edge: past the front the film is gone and the
// lamp shows through as white; at the front it bubbles orange, with a
// thin charred brown rim. Noise warps the front and crawls with time so
// the edge boils instead of sliding.
struct Params {
    amount: f32, // float — how far the burn has eaten in, 0 none, 1 the whole frame
    glow: f32,   // float — width of the glowing edge, in frame heights
    speed: f32,  // float — how fast the front boils; 0 freezes it
    color: vec4f,// color — the glow, premultiplied
    angle: f32,  // float — the edge it starts from, degrees; 0 is the right
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
fn fbm4(p_in: vec2f) -> f32 {
    var p = p_in;
    var sum = 0.0;
    var amp = 0.5;
    for (var i = 0; i < 4; i++) {
        sum += amp * value_noise(p);
        amp *= 0.5;
        p = p * 2.07 + vec2f(3.1, 9.7);
    }
    return sum / 0.9375;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let a = radians(params.angle);
    var p = (uv - 0.5) * vec2f(aspect, 1.0);
    p = vec2f(p.x * cos(a) + p.y * sin(a), -p.x * sin(a) + p.y * cos(a));
    let t = gobofx_globals.time * params.speed;
    // The front: a line across the frame whose position follows amount,
    // from just past the edge (0) to past the far edge (1), bent by a
    // noise field that scrolls so the edge boils.
    let half_w = 0.5 * aspect + 0.15;
    let front = half_w - clamp(params.amount, 0.0, 1.0) * (2.0 * half_w + 0.3);
    let n = fbm4(p * 3.0 + vec2f(t * 0.6, -t * 0.9)) - 0.5;
    let n2 = fbm4(p * 9.0 + vec2f(-t * 1.3, t * 0.4)) - 0.5;
    let e = p.x - front + n * 0.45 + n2 * 0.08; // > 0 is burnt away
    let gw = max(params.glow, 0.0) * 0.25 + 0.01;
    let char_w = 0.012 + gw * 0.15;
    // Bands, outside in: charred rim, then the glow, then the lamp.
    let alpha = smoothstep(-char_w, 0.0, e);
    let hot = smoothstep(0.0, gw * 0.6, e);
    let lamp = smoothstep(gw * 0.4, gw, e);
    let char = vec4f(0.08, 0.03, 0.01, 1.0);
    // Flicker in the glow, driven by the boil so it does not strobe flat.
    let flicker = 0.85 + 0.3 * n2;
    var c = mix(char, params.color * flicker, hot);
    c = mix(c, vec4f(1.0, 0.97, 0.9, 1.0), lamp);
    return c * alpha;
}
