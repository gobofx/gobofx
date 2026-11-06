// Kaleidoscope Tile — a wedge of the picture mirrored into a tiled plane.
// The frame is cut into square tiles of `size` (mirror-repeated, so the
// seams meet their own reflection); inside each tile the angle around the
// tile centre is folded into `segments` mirrored wedges, and that wedge is
// read from the source around its centre, reaching to the frame's top and
// bottom whatever the tile size, rotated by `angle`.
const PI: f32 = 3.14159265359;

struct Params {
    segments: i32, // int — mirrored wedges per tile
    size: f32,     // float — tile size as a fraction of the frame height
    angle: f32,    // float — rotation of the source wedge, degrees
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}
// Mirror-repeat into 0..1: s on 0..1 maps to itself, 1..2 to its reflection.
fn mirror(s: vec2f) -> vec2f {
    return 1.0 - abs(fract(s * 0.5) * 2.0 - 1.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let size = clamp(params.size, 0.1, 1.0);
    // Plane in tile units, with a tile centred on the frame centre.
    let p = (uv - 0.5) * vec2f(aspect, 1.0) / size + 0.5;
    // Mirror-repeat: adjacent tiles are reflections, so the seams are continuous.
    let local = abs(fract(p * 0.5) * 2.0 - 1.0) - 0.5;
    let r = length(local);
    var ang = atan2(local.y, local.x);
    let n = f32(clamp(params.segments, 1, 16));
    let wedge = 2.0 * PI / n;
    ang = ang - wedge * floor(ang / wedge); // 0..wedge
    ang = abs(ang - wedge * 0.5);           // mirrored, 0..wedge/2
    // The folded wedge is centred on the up-left diagonal, then turned by `angle`.
    let a = ang - wedge * 0.25 + PI * 0.75 + radians(params.angle);
    // Read around the source centre; a tile's corner reaches half the frame height.
    let s = vec2f(0.5) + vec2f(cos(a), sin(a)) * (r / 0.70710678) * 0.5 / vec2f(aspect, 1.0);
    return src_at(mirror(s));
}
