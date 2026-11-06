// Light Leak — the warm fog that creeps in from the edge of a frame when a
// film camera's gate lets light past. Three soft blobs of orange, red and
// yellow, shaped by low-frequency noise, biased towards one edge and
// drifting slowly. Over transparent; stack it on a clip.
struct Params {
    intensity: f32, // float — 0 off, 1 full
    hue: f32,       // float — degrees of hue rotation around the warm default
    scale: f32,     // float — blob size, 1 is a frame-sized leak
    speed: f32,     // float — drift rate; 0 freezes it
    angle: f32,     // float — which edge the leak comes from, degrees
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
fn fbm3(p_in: vec2f) -> f32 {
    var p = p_in;
    var sum = 0.0;
    var amp = 0.5;
    for (var i = 0; i < 3; i++) {
        sum += amp * value_noise(p);
        amp *= 0.5;
        p = p * 2.1 + vec2f(5.2, 1.3);
    }
    return sum / 0.875;
}
// Hue rotation around the grey axis (YIQ), a cheap and exact-enough twist.
fn hue_rotate(c: vec3f, deg: f32) -> vec3f {
    let a = radians(deg);
    let k = vec3f(0.57735);
    let cs = cos(a);
    return c * cs + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cs);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let a = radians(params.angle);
    // Frame coordinates turned so the leak's edge is always the +x side.
    var p = (uv - 0.5) * vec2f(aspect, 1.0);
    p = vec2f(p.x * cos(a) + p.y * sin(a), -p.x * sin(a) + p.y * cos(a));
    let t = gobofx_globals.time * params.speed;
    let s = 1.0 / max(params.scale, 0.25);
    // The leak lives past the edge at x > 0.5 and spills inwards; an edge
    // bias keeps the far side of the frame clean.
    let edge = smoothstep(-0.9 * params.scale, 0.6, p.x);
    // Three blobs: each a lump of noise around its own moving anchor.
    var acc = vec3f(0.0);
    let q = p * s;
    let n1 = fbm3(q * 1.1 + vec2f(t * 0.25, t * 0.11));
    let n2 = fbm3(q * 1.7 + vec2f(3.7 - t * 0.17, 8.1 + t * 0.21));
    let n3 = fbm3(q * 0.8 + vec2f(-t * 0.13, 2.2 + t * 0.3));
    let c1 = vec2f(0.55, -0.15 + 0.2 * sin(t * 0.7));  // orange, upper right
    let c2 = vec2f(0.45, 0.25 + 0.2 * cos(t * 0.5));   // red, lower right
    let c3 = vec2f(0.75, 0.05 + 0.15 * sin(t * 0.4 + 1.0)); // yellow, at the edge
    let b1 = exp(-dot(q - c1 * s, q - c1 * s) * 2.2) * smoothstep(0.2, 0.75, n1);
    let b2 = exp(-dot(q - c2 * s, q - c2 * s) * 3.0) * smoothstep(0.25, 0.8, n2);
    let b3 = exp(-dot(q - c3 * s, q - c3 * s) * 1.2) * smoothstep(0.15, 0.7, n3);
    acc += vec3f(1.0, 0.45, 0.08) * b1 * 1.4;
    acc += vec3f(1.0, 0.12, 0.18) * b2 * 1.1;
    acc += vec3f(1.0, 0.85, 0.35) * b3 * 1.2;
    acc = max(hue_rotate(acc, params.hue), vec3f(0.0)) * edge * max(params.intensity, 0.0);
    // Fold the additive glow into premultiplied alpha: alpha is the
    // brightest channel (clamped), colour scaled so it never exceeds it.
    let m = max(acc.r, max(acc.g, acc.b));
    let al = clamp(m, 0.0, 1.0);
    return vec4f(acc * (al / max(m, 1e-5)), al);
}
