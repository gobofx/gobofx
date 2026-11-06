// Grid — lines over a (transparent by default) background.
struct Params {
    line_color: vec4f, // color — premultiplied
    background: vec4f, // color — premultiplied, transparent by default
    columns: i32,      // int — cells across the width
    rows: i32,         // int — cells down the height; 0 = square cells
    line_width: f32,   // float — pixels
    center: vec2f,     // point — a grid line crosses here
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let res = gobofx_globals.resolution;
    let aspect = res.x / res.y;
    let cols = f32(clamp(params.columns, 1, 64));
    let cell_w = aspect / cols;
    let cell_h = select(1.0 / f32(clamp(params.rows, 1, 64)), cell_w, params.rows <= 0);
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let g = d / vec2f(cell_w, cell_h);
    // Distance to the nearest line in height units, per axis.
    let dx = abs(fract(g.x) - 0.5) * cell_w;
    let dy = abs(fract(g.y) - 0.5) * cell_h;
    let dist = min(0.5 * cell_w - dx, 0.5 * cell_h - dy); // 0 on a line
    let px = gobofx_globals.texel.y;
    let half = 0.5 * max(params.line_width, 0.5) * px;
    let on = 1.0 - smoothstep(half - px, half + px, dist);
    return mix(params.background, params.line_color, on);
}
