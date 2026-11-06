// Sunburst — rays radiating from a centre, alternating two colours and
// turning with time. The gap colour defaults to transparent so the rays
// stack over a clip; make it opaque for a classic poster burst.
struct Params {
    color_a: vec4f, // color — the rays
    color_b: vec4f, // color — the gaps
    center: vec2f,  // point
    count: i32,     // int — number of rays, 2..64
    angle: f32,     // float — degrees of rotation
    speed: f32,     // float — turns per second
    softness: f32,  // float — blur of the ray edge, as a fraction of a ray
    falloff: f32,   // float — how fast the rays fade with distance, 0 none
}
@group(1) @binding(0) var<uniform> params: Params;

const PI: f32 = 3.14159265359;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let n = f32(clamp(params.count, 2, 64));
    let turn = radians(params.angle) + gobofx_globals.time * params.speed * 2.0 * PI;
    let ang = atan2(d.y, d.x) - turn;
    // Position within one ray + gap period, 0..1; the ray is the first half.
    let t = fract(ang * n / (2.0 * PI));
    let r = length(d);
    // Edge width in period units: the softness setting, but at least ~1.5 px
    // of arc at this radius so the rays antialias (and so the centre, where
    // every ray meets, dissolves into a blend instead of a moiré).
    let arc_px = 1.5 * gobofx_globals.texel.y * n / (2.0 * PI * max(r, 1e-4));
    let w = clamp(max(params.softness * 0.5, arc_px), 0.0, 0.5);
    let on = smoothstep(0.0, w, t) * (1.0 - smoothstep(0.5 - w, 0.5, t));
    // Radial falloff in frame heights: 0 keeps the rays to the frame edge.
    let fade = 1.0 - clamp(params.falloff, 0.0, 1.0) * smoothstep(0.0, 1.0, r);
    return mix(params.color_b, params.color_a, on * fade);
}
