// Polar — rectangular-to-polar warp, and its inverse. Rectangular to polar:
// the frame's left-to-right becomes the angle around the centre, clockwise
// from twelve o'clock where the two side edges meet; top-to-bottom becomes
// the radius, the top row at the centre and the bottom row on a rim half a
// frame height out. Polar to rectangular undoes that. Outside the frame is
// transparent, so the corners beyond the rim are empty. Amount blends from
// the flat frame (0, a no-op) to the full warp (1).
const TAU: f32 = 6.28318530718;

struct Params {
    center: vec2f,  // point — the pole
    amount: f32,    // float — 0 is a no-op, 1 the full warp
    direction: u32, // choice — 0 rectangular to polar, 1 polar to rectangular
}
@group(1) @binding(0) var<uniform> params: Params;

// Transparent outside the frame.
fn src_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let size = vec2f(aspect, 1.0);
    let a = clamp(params.amount, 0.0, 1.0);
    var puv: vec2f;
    if (params.direction == 0u) {
        // Which (angle, radius) does this output pixel sit at? Read the source
        // there as (x, y).
        let d = (uv - params.center) * size;
        let ang = atan2(d.x, -d.y); // 0 at twelve o'clock, clockwise
        puv = vec2f(ang / TAU + 0.5, length(d) / 0.5);
    } else {
        // Which (x, y) is this output pixel? Read the source at that angle
        // and radius around the pole.
        let ang = (uv.x - 0.5) * TAU;
        let dir = vec2f(sin(ang), -cos(ang));
        puv = params.center + dir * uv.y * 0.5 / size;
    }
    return src_at(mix(uv, puv, a));
}
