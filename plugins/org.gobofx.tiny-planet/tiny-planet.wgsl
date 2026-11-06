// Tiny Planet — the stereographic "little planet": the picture is treated
// as a panorama, its bottom edge gathered into the centre and its top edge
// thrown out to the frame's corners, the left and right edges meeting on a
// seam. Zoom is the radius of the horizon (the picture's middle row). Amount
// mixes the planet over the source; 0 is a no-op. The panorama repeats
// around the planet, so nothing is pulled from outside the frame.
const TAU: f32 = 6.28318530718;
const PI: f32 = 3.14159265359;

struct Params {
    center: vec2f, // point — the planet's centre
    zoom: f32,     // float — horizon radius in frame heights
    rotation: f32, // float — degrees, turns the planet around its centre
    amount: f32,   // float — 0 is a no-op, 1 the full planet
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let r = length(d);
    // Stereographic: the angle down from the zenith grows with the distance
    // from the centre; the horizon (half way) sits at r == zoom.
    let zoom = max(params.zoom, 0.05);
    let polar = 2.0 * atan(r / zoom);
    let v = 1.0 - polar / PI;
    // Longitude wraps the panorama around the planet; the seam is where the
    // picture's left and right edges meet.
    let theta = atan2(d.y, d.x) + radians(params.rotation);
    let u = fract(theta / TAU + 0.25);
    let planet = src_at(vec2f(u, clamp(v, 0.0, 1.0)));
    let a = clamp(params.amount, 0.0, 1.0);
    return mix(src_at(uv), planet, a);
}
