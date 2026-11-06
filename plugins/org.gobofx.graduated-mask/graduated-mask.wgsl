// Graduated Mask — a straight split with a soft edge, like a graduated
// filter on the lens. At angle 0 the picture is kept below the line and
// fades to transparent above it; the angle turns the line clockwise.
// Position slides the line across the frame along the split direction,
// 0..1 spanning the frame whatever the angle. Feather is measured in
// frame heights.
struct Params {
    angle: f32,    // float — degrees, clockwise; 0 is a horizontal line
    position: f32, // float — where the line sits along the split, 0..1 across the frame
    feather: f32,  // float — edge width in frame heights
    invert: u32,   // bool — keep the other side
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let a = radians(params.angle);
    // Split direction, pointing towards the kept side; (0,1) is down.
    let dir = vec2f(sin(a), cos(a));
    let p = (uv - vec2f(0.5)) * vec2f(aspect, 1.0);
    // Half the frame's extent along the split direction, so position 0..1
    // walks the line from one edge of the frame to the other.
    let half_extent = 0.5 * (aspect * abs(dir.x) + abs(dir.y));
    let offset = (clamp(params.position, 0.0, 1.0) - 0.5) * 2.0 * half_extent;
    let s = dot(p, dir) - offset;
    let f = max(params.feather, 1.5 * gobofx_globals.texel.y);
    var m = smoothstep(-f * 0.5, f * 0.5, s);
    if (params.invert == 1u) { m = 1.0 - m; }
    return src * m;
}
