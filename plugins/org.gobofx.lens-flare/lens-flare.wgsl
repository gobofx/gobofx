// Lens Flare — a light source with its glow, an anamorphic streak and a
// chain of ghosts reflected through the frame centre, over transparent.
// The parts add up in linear light; the result is folded back into valid
// premultiplied alpha, so the host's over composite reads as a screen.
struct Params {
    center: vec2f,  // point — where the light is
    intensity: f32, // float — 0 off, 1 full
    ghosts: i32,    // int — number of reflections along the axis, 0..12
    color: vec4f,   // color — premultiplied tint of the source
    streak: f32,    // float — horizontal streak length in frame heights
    size: f32,      // float — glow radius in frame heights
}
@group(1) @binding(0) var<uniform> params: Params;

fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}

// A soft ring: bright at radius r with a hollow middle, as a lens element
// reflects a disc of light.
fn ring(d: f32, r: f32, w: f32) -> f32 {
    let edge = 1.0 - smoothstep(r - w, r, d);
    let hole = smoothstep(r * 0.35, r, d);
    return edge * mix(0.35, 1.0, hole);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let light = (params.center - 0.5) * vec2f(aspect, 1.0);
    let p = (uv - 0.5) * vec2f(aspect, 1.0);
    let size = max(params.size, 0.02);
    let tint = params.color.rgb / max(params.color.a, 1e-4);
    var acc = vec3f(0.0);

    // The source: a sharp core inside a wide soft glow.
    let d = length(p - light);
    let core = exp(-d * d / (size * size * 0.08));
    let glow = exp(-d / size) * 0.35 + exp(-d * d / (size * size * 0.6)) * 0.4;
    acc += tint * (core + glow);

    // Anamorphic streak: a horizontal line through the source, thin in y
    // and fading along x over `streak` frame heights.
    let st = max(params.streak, 0.0);
    if (st > 0.0) {
        let dy = abs(p.y - light.y);
        let dx = abs(p.x - light.x);
        let line = exp(-dy * dy / (size * size * 0.02)) * exp(-dx / (st * 0.5)) * (1.0 - smoothstep(st * 0.8, st * 1.2, dx));
        acc += mix(tint, vec3f(0.6, 0.8, 1.0), 0.5) * line * 0.9;
    }

    // Ghosts: discs and rings on the line from the source through the
    // frame centre, at fixed fractions of the way so they move with the
    // source the way reflections do. Each has its own size and hue.
    let n = clamp(params.ghosts, 0, 12);
    for (var i = 0; i < 12; i++) {
        if (i >= n) { break; }
        let fi = f32(i);
        let k = mix(-0.35, 1.9, (fi + 0.5) / 12.0) ;  // -0.35 is just past the source
        let pos = light + (-light) * (1.0 + k);        // through the centre and beyond
        let r = size * mix(0.3, 1.1, hash21(vec2f(fi, 1.3)));
        let gd = length(p - pos);
        let hue = hash21(vec2f(fi, 7.7));
        let gcol = mix(vec3f(1.0, 0.5, 0.3), mix(vec3f(0.4, 1.0, 0.6), vec3f(0.4, 0.6, 1.0), hue), hue);
        let shape = select(ring(gd, r, r * 0.3), 1.0 - smoothstep(r * 0.5, r, gd), (i % 3) == 1);
        acc += gcol * shape * mix(0.18, 0.4, hash21(vec2f(fi, 3.3)));
    }

    acc *= max(params.intensity, 0.0);
    // Fold the additive sum into premultiplied alpha: the alpha is the
    // brightest channel (clamped), and the colour is scaled so it never
    // exceeds it.
    let m = max(acc.r, max(acc.g, acc.b));
    let a = clamp(m, 0.0, 1.0);
    let rgb = acc * (a / max(m, 1e-5));
    return vec4f(rgb, a);
}
