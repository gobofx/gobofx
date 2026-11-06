// Stripes — cut the picture into parallel stripes and slide each along its
// own length. Alternate slides every other stripe the opposite way; off, the
// stripes shear from -offset at one side of the frame to +offset at the
// other. Offset 0 is a no-op. Where a stripe slides out of the frame it
// leaves transparency behind.
struct Params {
    count: i32,     // int — number of stripes across the frame
    angle: f32,     // float — degrees; 0 runs the stripes horizontally
    offset: f32,    // float — slide in frame heights; 0 is a no-op
    alternate: u32, // bool — alternate directions, else a stepped shear
}
@group(1) @binding(0) var<uniform> params: Params;

// Transparent where a stripe slides out of the frame.
fn src_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let p = (uv - 0.5) * vec2f(aspect, 1.0);
    let a = radians(clamp(params.angle, -90.0, 90.0));
    let along = vec2f(cos(a), sin(a));  // the stripes run this way
    let across = vec2f(-sin(a), cos(a)); // and stack this way
    // The stripes span the frame's full extent across their stacking axis.
    let half = 0.5 * (abs(across.x) * aspect + abs(across.y));
    let n = f32(clamp(params.count, 2, 64));
    let idx = clamp(floor((dot(p, across) + half) / (2.0 * half) * n), 0.0, n - 1.0);
    let parity = idx - 2.0 * floor(idx * 0.5);
    let off = clamp(params.offset, -0.5, 0.5);
    let shear = off * (2.0 * idx / (n - 1.0) - 1.0);
    let flip = off * (1.0 - 2.0 * parity);
    let slide = select(shear, flip, params.alternate == 1u);
    return src_at(uv - along * slide / vec2f(aspect, 1.0));
}
