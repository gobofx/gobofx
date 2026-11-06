// Triangle Tile — the plane tiled with equilateral triangles of side
// `size` that are all mirror images of one another (the p3m1
// kaleidoscope). A triangle of the source, most of the frame height,
// is read from around the frame centre; every tile shows it reflected
// across its edges, so the pattern is seamless and three-fold. The fold is exact: the point is reduced by the lattice's
// translations, then reflected across the triangle's three edges until it
// lands inside.
const H: f32 = 0.86602540378; // sqrt(3) / 2, the triangle's height

struct Params {
    size: f32,  // float — triangle side as a fraction of the frame height
    angle: f32, // float — rotation of the pattern, degrees
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}
// Mirror-repeat into 0..1: s on 0..1 maps to itself, 1..2 to its reflection.
fn mirror(s: vec2f) -> vec2f {
    return 1.0 - abs(fract(s * 0.5) * 2.0 - 1.0);
}

// Fold p into the triangle A(0,0) B(1,0) C(0.5,H).
fn fold(p0: vec2f) -> vec2f {
    // Translation lattice of the reflection group: t1 = (1.5, H), t2 = (0, 2H).
    let m = floor(p0.x / 1.5);
    let n = floor((p0.y - (p0.x / 1.5) * H) / (2.0 * H));
    var p = p0 - m * vec2f(1.5, H) - n * vec2f(0.0, 2.0 * H);
    let n_ac = vec2f(-H, 0.5); // outward normal of edge AC
    let n_bc = vec2f(H, 0.5);  // outward normal of edge BC
    let b = vec2f(1.0, 0.0);
    // Within one lattice cell at most a handful of reflections remain.
    for (var i = 0; i < 10; i++) {
        if (p.y < 0.0) {
            p.y = -p.y;
        }
        let d_ac = dot(p, n_ac);
        if (d_ac > 0.0) {
            p -= 2.0 * d_ac * n_ac;
        }
        let d_bc = dot(p - b, n_bc);
        if (d_bc > 0.0) {
            p -= 2.0 * d_bc * n_bc;
        }
    }
    return p;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let size = clamp(params.size, 0.08, 0.6);
    let a = radians(params.angle);
    let rot = mat2x2f(cos(a), sin(a), -sin(a), cos(a));
    let p = rot * ((uv - 0.5) * vec2f(aspect, 1.0)) / size;
    let f = fold(p);
    // Back to the source: the triangle's centroid sits on the frame centre
    // and its side spans 0.8 of the frame height, whatever the tile size.
    let centroid = vec2f(0.5, H / 3.0);
    let s = vec2f(0.5) + (transpose(rot) * (f - centroid)) * 0.8 / vec2f(aspect, 1.0);
    return src_at(mirror(s));
}
