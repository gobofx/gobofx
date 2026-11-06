// Caustics — the bright web of light on a pool floor, over transparent.
// Two layers of cellular noise with sites that circle in time; the light
// is the cell boundary (second minus first distance), sharpened so it
// reads as thin, bright ridges that stretch and merge as the sites move.
struct Params {
    scale: f32,     // float — cells across the frame height
    speed: f32,     // float — ripple rate, cycles per second
    intensity: f32, // float — 0 off, 1 full, above widens the bright web
    sharpness: f32, // float — 0 soft wide bands, 1 thin wires
    color: vec4f,   // color — premultiplied light colour
}
@group(1) @binding(0) var<uniform> params: Params;

const PI: f32 = 3.14159265359;

fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
fn hash22(p: vec2f) -> vec2f {
    return vec2f(hash21(p), hash21(p + vec2f(17.1, 31.7)));
}

// Edge distance of a cellular field whose sites orbit their cell centre:
// F2 - F1, 0 on a boundary, growing towards the cell centre.
fn cell_edge(p: vec2f, t: f32) -> f32 {
    let i = floor(p);
    let f = fract(p);
    var f1 = 8.0;
    var f2 = 8.0;
    for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
            let o = vec2f(f32(x), f32(y));
            let h = hash22(i + o);
            let ph = h * 2.0 * PI;
            let site = o + 0.5 + 0.4 * vec2f(sin(t + ph.x), cos(t + ph.y));
            let d = dot(site - f, site - f);
            if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
        }
    }
    return sqrt(f2) - sqrt(f1);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let p = uv * vec2f(aspect, 1.0) * max(params.scale, 0.5);
    let t = gobofx_globals.time * params.speed * 2.0 * PI * 0.25;
    // Two layers at different scales and rates; the second drifts so the
    // overlap does not sit still.
    let e1 = cell_edge(p, t);
    let e2 = cell_edge(p * 1.7 + vec2f(3.1, 1.7) + vec2f(0.13, 0.07) * t, t * 1.3 + 1.0);
    // Ridge brightness: 1 on a boundary, falling off into the cell. The
    // sharpness setting narrows the band.
    let k = mix(2.0, 9.0, clamp(params.sharpness, 0.0, 1.0));
    let r1 = exp(-k * e1);
    let r2 = exp(-k * e2);
    // The web: the thinner layer rides on the wider one, and their overlap
    // makes the bright knots a real pool shows.
    let web = r1 * 0.7 + r2 * 0.5 + r1 * r2 * 0.8;
    let light = clamp(web * max(params.intensity, 0.0), 0.0, 1.0);
    return params.color * light;
}
