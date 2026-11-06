// Starfield — scattered stars over a transparent (or chosen) background.
// The frame is cut into cells; each cell may hold one star, placed, sized
// and phased by a hash of the cell index, so the field is identical on
// every frame and only the twinkle moves.
struct Params {
    density: f32,     // float — fraction of cells that hold a star, 0..1
    size: f32,        // float — star radius in pixels
    speed: f32,       // float — twinkle rate, cycles per second
    color: vec4f,     // color — premultiplied
    background: vec4f,// color — premultiplied
}
@group(1) @binding(0) var<uniform> params: Params;

const PI: f32 = 3.14159265359;
// Cells across the frame height; fixed so the field does not reshuffle
// when the density changes.
const CELLS: f32 = 36.0;

fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let p = uv * vec2f(aspect, 1.0) * CELLS;
    let cell_px = gobofx_globals.resolution.y / CELLS;
    let i = floor(p);
    let f = fract(p);
    let density = clamp(params.density, 0.0, 1.0);
    let radius = max(params.size, 0.5) / cell_px; // in cells
    var light = 0.0;
    // A star can be larger than its cell, so look at the neighbours too.
    for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
            let o = vec2f(f32(x), f32(y));
            let c = i + o;
            let h = hash21(c);
            if (h >= density) { continue; }
            let pos = o + vec2f(hash21(c + vec2f(7.3, 1.1)), hash21(c + vec2f(3.7, 9.2)));
            let dist = length(pos - f);
            // Every star has its own size (a third to full) and brightness.
            let s = radius * mix(0.35, 1.0, hash21(c + vec2f(5.5, 2.4)));
            let phase = hash21(c + vec2f(1.9, 6.6)) * 2.0 * PI;
            let rate = mix(0.5, 1.5, hash21(c + vec2f(8.1, 4.4)));
            let tw = 0.65 + 0.35 * sin(gobofx_globals.time * params.speed * rate * 2.0 * PI + phase);
            // Soft disc with a brighter core; antialiased at least 1 px.
            let aa = max(s * 0.6, 1.0 / cell_px);
            let disc = 1.0 - smoothstep(s - aa, s + aa * 0.5, dist);
            light = max(light, disc * tw);
        }
    }
    light = clamp(light, 0.0, 1.0);
    return mix(params.background, params.color, light);
}
