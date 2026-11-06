// Plasma — the classic sum of sines, cycling through a hue palette.
struct Params {
    scale: f32,      // float — waves across the frame height
    speed: f32,      // float — cycles per second
    hue: f32,        // float — palette rotation, degrees
    saturation: f32, // float — 0 grey, 1 full colour
    complexity: f32, // float — how many sine terms matter
}
@group(1) @binding(0) var<uniform> params: Params;

fn hsv(h: f32, s: f32, v: f32) -> vec3f {
    let k = fract(vec3f(h, h + 2.0 / 3.0, h + 1.0 / 3.0)) * 6.0;
    let rgb = clamp(abs(k - 3.0) - 1.0, vec3f(0.0), vec3f(1.0));
    return v * mix(vec3f(1.0), rgb, s);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let p = (uv - 0.5) * vec2f(aspect, 1.0) * max(params.scale, 0.5);
    let t = gobofx_globals.time * params.speed;
    let c = params.complexity;
    var v = sin(p.x + t);
    v += sin((p.y + t) * 0.7 * c);
    v += sin((p.x + p.y + t * 0.5) * 0.9 * c);
    let q = p + vec2f(sin(t * 0.3), cos(t * 0.4)) * 2.0;
    v += sin(length(q) * 1.3 * c - t);
    v = v * 0.25; // -1..1
    let hue = fract(v * 0.5 + 0.5 + params.hue / 360.0);
    let rgb = hsv(hue, params.saturation, 0.5 + 0.5 * cos(v * 3.14159));
    return vec4f(rgb, 1.0);
}
