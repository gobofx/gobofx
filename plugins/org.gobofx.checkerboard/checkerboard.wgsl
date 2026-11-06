// Checkerboard — a rotatable grid of two colours. Rows 0 = square cells.
struct Params {
    color_a: vec4f, // color
    color_b: vec4f, // color
    columns: i32,   // int — cells across the frame width
    rows: i32,      // int — cells down; 0 derives square cells from columns
    rotation: f32,  // float — degrees
    center: vec2f,  // point — pivot and cell origin
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let res = gobofx_globals.resolution;
    let aspect = res.x / res.y;
    let cols = f32(clamp(params.columns, 1, 64));
    let cell_w = aspect / cols;
    // Rows 0: square cells, i.e. as many rows as fit at the column width.
    let rows = select(f32(clamp(params.rows, 1, 64)), 1.0 / cell_w, params.rows <= 0);
    let cell = vec2f(cell_w, 1.0 / rows);
    let a = radians(params.rotation);
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let r = vec2f(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a));
    // Anti-alias the cell edges with a 1.5 px band using the cell-space derivative.
    let g = r / cell;
    let w = 1.5 * gobofx_globals.texel.y / cell;
    let fx = abs(fract(g.x) - 0.5) * 2.0; // 1 at cell edges
    let fy = abs(fract(g.y) - 0.5) * 2.0;
    let ix = floor(g.x);
    let iy = floor(g.y);
    var k = f32((i32(ix) + i32(iy)) & 1);
    // Blend across edges: where a cell border lies within w, mix towards 0.5.
    let ex = smoothstep(1.0 - w.x * 2.0, 1.0, fx);
    let ey = smoothstep(1.0 - w.y * 2.0, 1.0, fy);
    let edge = max(ex, ey);
    k = mix(k, 0.5, edge);
    return mix(params.color_a, params.color_b, k);
}
