// Stripes — parallel bands at any angle, optionally scrolling.
struct Params {
    color_a: vec4f, // color
    color_b: vec4f, // color
    count: f32,     // float — stripe pairs across the frame height
    angle: f32,     // float — degrees
    duty: f32,      // float — width of A within a pair, 0..1
    softness: f32,  // float — blur of the stripe edge, in pairs
    speed: f32,     // float — pairs per second scrolled
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let a = radians(params.angle);
    let d = (uv - 0.5) * vec2f(aspect, 1.0);
    let x = d.x * cos(a) + d.y * sin(a);
    let count = max(params.count, 0.5);
    let t = fract(x * count + gobofx_globals.time * params.speed);
    let duty = clamp(params.duty, 0.05, 0.95);
    // Edge width: at least ~1.5 px, plus the softness setting.
    let w = max(1.5 * gobofx_globals.texel.y * count, params.softness * 0.5);
    let on = smoothstep(0.0, w, t) * (1.0 - smoothstep(duty - w, duty, t));
    return mix(params.color_b, params.color_a, on);
}
