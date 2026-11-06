// Stroke — an outline of one colour along the alpha shape's edge, outside
// it, inside it or straddling it. The edge is found by a Euclidean distance
// transform in two separable passes: the first finds, per row, the distance
// to the nearest covered pixel and to the nearest uncovered one; the second
// combines the rows into true 2D distances. The third pass draws the band.
// Coverage of a partial pixel shifts its distance, so a soft edge gives a
// smooth outline. Width 0 passes through.
const MAX_WIDTH: f32 = 64.0;
// Beyond the reach of any stroke; a row with nothing in range stores this.
const FAR: f32 = 1024.0;

struct Params {
    width: f32,    // float — stroke width in pixels
    color: vec4f,  // color — the stroke, premultiplied
    position: u32, // choice — 0 outside, 1 centre, 2 inside
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}
fn reach() -> i32 {
    return i32(ceil(clamp(params.width, 0.0, MAX_WIDTH))) + 1;
}

// Distance from the pixel to the edge of a tap of coverage `a`, `offset`
// pixels away: a half-covered tap has the edge through its centre, a full
// one has it at least half a pixel past.
fn edge_dist(offset: f32, a: f32) -> f32 {
    return select(FAR, max(offset + 0.5 - a, 0.0), a > 0.002);
}

// Pass 1: along the row, distance to the nearest covered pixel (r) and to
// the nearest uncovered one (g).
@fragment
fn fs_rows(@location(0) uv: vec2f) -> @location(0) vec4f {
    let n = reach();
    let dx = vec2f(gobofx_globals.texel.x, 0.0);
    var to_shape = FAR;
    var to_clear = FAR;
    for (var i = -n; i <= n; i++) {
        let p = uv + dx * f32(i);
        // Outside the frame there is no shape.
        let inside = step(0.0, p.x) * step(p.x, 1.0);
        let a = clamp(src_at(p).a, 0.0, 1.0) * inside;
        let o = abs(f32(i));
        to_shape = min(to_shape, edge_dist(o, a));
        to_clear = min(to_clear, edge_dist(o, 1.0 - a));
    }
    return vec4f(to_shape, to_clear, 0.0, 1.0);
}

// Pass 2: down the column, the row distances become 2D distances.
@fragment
fn fs_distance(@location(0) uv: vec2f) -> @location(0) vec4f {
    let n = reach();
    let dy = vec2f(0.0, gobofx_globals.texel.y);
    var to_shape = FAR;
    var to_clear = FAR;
    for (var i = -n; i <= n; i++) {
        let p = uv + dy * f32(i);
        let inside = step(0.0, p.y) * step(p.y, 1.0);
        let row = textureSampleLevel(gobofx_input0, gobofx_sampler, p, 0.0).rg;
        let y = f32(i);
        // Off the frame the row reads as all clear: the shape is far, the
        // clear is right there.
        let rs = select(FAR, row.r, inside > 0.5);
        let rc = select(0.0, row.g, inside > 0.5);
        to_shape = min(to_shape, select(FAR, sqrt(y * y + rs * rs), rs < FAR));
        to_clear = min(to_clear, select(FAR, sqrt(y * y + rc * rc), rc < FAR));
    }
    return vec4f(to_shape, to_clear, 0.0, 1.0);
}

// Coverage of a band whose edge sits at distance `e`, antialiased over one
// pixel: 1 on the near side, 0 on the far side.
fn within(d: f32, e: f32) -> f32 {
    return 1.0 - smoothstep(e - 0.5, e + 0.5, d);
}

// Pass 3: the band. The outer part is laid under the source so the shape's
// own soft edge sits on it; the inner part is laid over the shape.
@fragment
fn fs_draw(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let w = clamp(params.width, 0.0, MAX_WIDTH);
    if (w < 0.5) {
        return src;
    }
    let d = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0).rg;
    // Signed distance: positive outside the shape, negative inside.
    let s = d.r - d.g;
    var out_w = w;
    var in_w = 0.0;
    if (params.position == 1u) {
        out_w = w * 0.5;
        in_w = w * 0.5;
    } else if (params.position == 2u) {
        out_w = 0.0;
        in_w = w;
    }
    // Under: fills the shape and out_w beyond it. Over: the in_w band
    // inside, limited to the shape's coverage.
    let under = select(0.0, within(s, out_w), out_w > 0.0);
    let over = select(0.0, (1.0 - within(s, -in_w)) * src.a, in_w > 0.0);
    let col = params.color;
    let base = src + col * under * (1.0 - src.a);
    return col * over + base * (1.0 - col.a * over);
}
