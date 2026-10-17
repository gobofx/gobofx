// Dots — a lattice of discs, square or staggered (hexagonal).
struct Params {
    dot_color: vec4f, // color — premultiplied
    background: vec4f,// color — premultiplied, transparent by default
    columns: i32,     // int — dots across the width
    radius: f32,      // float — disc radius as a fraction of the cell
    stagger: u32,     // bool — offset every other row by half a cell
    softness: f32,    // float — 0 hard edge, 1 fully soft
    center: vec2f,    // point — a dot sits here
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let cols = f32(clamp(params.columns, 1, 64));
    let cell = aspect / cols;
    var g = (uv - params.center) * vec2f(aspect, 1.0) / cell;
    if (params.stagger == 1u) {
        let row = floor(g.y);
        g.x += 0.5 * f32(i32(row) & 1);
    }
    let f = fract(g) - 0.5;
    let dist = length(f); // in cells
    let r = clamp(params.radius, 0.02, 0.7);
    let aa = 1.5 * gobofx_globals.texel.y / cell;
    let soft = max(aa, params.softness * r);
    let on = 1.0 - smoothstep(r - soft, r + aa, dist);
    return mix(params.background, params.dot_color, on);
}
