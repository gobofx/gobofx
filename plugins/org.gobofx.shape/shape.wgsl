// Shape — rectangle, ellipse, regular polygon or star, filled and stroked,
// over a transparent background. Signed-distance based, so edges are crisp
// at any size and `roundness` rounds every corner.
struct Params {
    shape: u32,         // choice — 0 rectangle, 1 ellipse, 2 polygon, 3 star
    fill: vec4f,        // color — premultiplied
    stroke: vec4f,      // color — premultiplied
    stroke_width: f32,  // float — pixels, 0 for none
    background: vec4f,  // color — premultiplied
    center: vec2f,      // point
    size: f32,          // float — radius / half-height in frame heights
    aspect: f32,        // float — width / height
    rotation: f32,      // float — degrees
    sides: i32,         // int — polygon and star points
    inner: f32,         // float — star inner radius as a fraction of size
    roundness: f32,     // float — corner rounding as a fraction of size
}
@group(1) @binding(0) var<uniform> params: Params;

const PI: f32 = 3.14159265359;

fn sd_box(p: vec2f, b: vec2f) -> f32 {
    let d = abs(p) - b;
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0);
}
fn sd_ellipse_approx(p: vec2f, r: vec2f) -> f32 {
    // Scaled-distance approximation: exact on the axes, close elsewhere.
    let k0 = length(p / r);
    let k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / max(k1, 1e-5);
}
fn sd_ngon(p: vec2f, r: f32, n: f32) -> f32 {
    // Regular n-gon of circumradius r. Fold the angle into the wedge around
    // one edge normal (+x); there the boundary is the vertical edge at the
    // apothem, so the distance is to that segment.
    let an = PI / n;
    let ang = atan2(p.y, p.x);
    let f = ang - 2.0 * an * floor((ang + an) / (2.0 * an));
    let q = length(p) * vec2f(cos(f), abs(sin(f)));
    let dx = q.x - r * cos(an);
    let dy = max(q.y - r * sin(an), 0.0);
    return select(length(vec2f(dx, dy)), dx, dx <= 0.0);
}
fn seg_dist(p: vec2f, a: vec2f, b: vec2f) -> f32 {
    let ab = b - a;
    let t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-8), 0.0, 1.0);
    return length(p - (a + ab * t));
}
fn sd_starn(p: vec2f, r: f32, n: f32, inner: f32) -> f32 {
    // Star with n points: outer radius r, inner radius r*inner. Fold into
    // the half-point wedge [0, an]; the star there is the region between the
    // origin and the segment from the outer vertex A to the inner vertex B,
    // so "inside" is the origin's side of A→B. The distance also looks at
    // the two neighbouring segments (B→C and A→B'), which can be nearer
    // for points just outside a vertex.
    let an = PI / n;
    let ang = atan2(p.y, p.x);
    let f = abs(ang - 2.0 * an * round(ang / (2.0 * an)));
    let q = length(p) * vec2f(cos(f), sin(f));
    let a = vec2f(r, 0.0);
    let b = r * inner * vec2f(cos(an), sin(an));
    let c = r * vec2f(cos(2.0 * an), sin(2.0 * an));
    let b2 = vec2f(b.x, -b.y);
    let d = min(seg_dist(q, a, b), min(seg_dist(q, b, c), seg_dist(q, a, b2)));
    let side = (b.x - a.x) * (q.y - a.y) - (b.y - a.y) * (q.x - a.x);
    let origin_side = (b.x - a.x) * (0.0 - a.y) - (b.y - a.y) * (0.0 - a.x);
    return select(d, -d, side * origin_side > 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let a = radians(params.rotation);
    var d = (uv - params.center) * vec2f(aspect, 1.0);
    d = vec2f(d.x * cos(a) + d.y * sin(a), -d.x * sin(a) + d.y * cos(a));
    let size = max(params.size, 0.02);
    let ar = clamp(params.aspect, 0.1, 4.0);
    let round = clamp(params.roundness, 0.0, 1.0) * size * 0.5;
    var dist: f32;
    switch params.shape {
        case 0u: { dist = sd_box(d, vec2f(size * ar, size) - round) - round; }
        case 1u: { dist = sd_ellipse_approx(d, vec2f(size * ar, size)); }
        case 2u: {
            let n = f32(clamp(params.sides, 3, 12));
            dist = sd_ngon(d / vec2f(ar, 1.0), size - round, n) - round;
        }
        default: {
            let n = f32(clamp(params.sides, 3, 12));
            dist = sd_starn(d / vec2f(ar, 1.0), size - round, n, clamp(params.inner, 0.1, 0.95)) - round;
        }
    }
    let px = gobofx_globals.texel.y;
    let aa = 1.5 * px;
    let fill = 1.0 - smoothstep(-aa, aa, dist);
    let sw = params.stroke_width * px;
    let stroke = (1.0 - smoothstep(-aa, aa, abs(dist) - 0.5 * sw)) * step(0.01 * px, sw);
    var c = mix(params.background, params.fill, fill);
    c = mix(c, params.stroke, stroke);
    return c;
}
