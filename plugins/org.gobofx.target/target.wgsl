// Target — cut the picture into concentric rings around a point and turn
// each ring by its own angle. Alternate turns every other ring the opposite
// way; off, each ring turns one step further than the one inside it.
// Rotation 0 is a no-op. The rings span from the centre to the farthest
// frame corner; where a turned ring runs out of picture it is transparent.
struct Params {
    center: vec2f,  // point
    count: i32,     // int — number of rings between the centre and the corner
    rotation: f32,  // float — degrees per ring; 0 is a no-op
    alternate: u32, // bool — alternate directions, else cumulative
}
@group(1) @binding(0) var<uniform> params: Params;

// Transparent where a ring runs out of picture.
fn src_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    // The outermost ring ends at the frame corner farthest from the centre.
    let c = params.center * vec2f(aspect, 1.0);
    let reach = length(vec2f(max(c.x, aspect - c.x), max(c.y, 1.0 - c.y)));
    let n = f32(clamp(params.count, 2, 24));
    let idx = min(floor(length(d) / reach * n), n - 1.0);
    let parity = idx - 2.0 * floor(idx * 0.5);
    let step = radians(clamp(params.rotation, -90.0, 90.0));
    let turn = select(step * idx, step * (1.0 - 2.0 * parity), params.alternate == 1u);
    let rot = vec2f(d.x * cos(turn) - d.y * sin(turn), d.x * sin(turn) + d.y * cos(turn));
    return src_at(params.center + rot / vec2f(aspect, 1.0));
}
