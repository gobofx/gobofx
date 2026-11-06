// Black Hole — the picture is drawn into a point: inside the radius the
// pixels slide towards the centre, swirling as they go, and a dark core opens
// where they vanish. Pixels pulled from outside the frame repeat the edge.
// Amount 0 is a no-op.
struct Params {
    center: vec2f, // point — where the picture falls in
    radius: f32,   // float — in frame heights
    amount: f32,   // float — 0 is a no-op, 1 a full collapse
}
@group(1) @binding(0) var<uniform> params: Params;

// Clamp-to-edge: a pixel pulled from outside the frame repeats the edge.
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let r = length(d);
    let rad = max(params.radius, 0.05);
    let n = r / rad;
    let a = clamp(params.amount, 0.0, 1.0);
    if (n >= 1.0 || a <= 0.0) {
        return src_at(uv);
    }
    // Pull: the output at n shows the source from farther out, so the picture
    // slides inward. n^(1/(1+5a)) is 1 at the rim, so there is no seam.
    let ns = pow(n, 1.0 / (1.0 + 5.0 * a));
    // Swirl on the way in, strongest at the centre, zero at the rim.
    let fall = 1.0 - n;
    let ang = 2.5 * a * fall * fall;
    let dir = d / max(r, 1e-6);
    let rot = vec2f(dir.x * cos(ang) - dir.y * sin(ang), dir.x * sin(ang) + dir.y * cos(ang));
    let col = src_at(params.center + rot * ns * rad / vec2f(aspect, 1.0));
    // The event horizon: black inside a core that grows with amount, and a
    // fall-off towards it. Never above 1, so premultiplied colour stays in alpha.
    let core = 0.3 * a;
    let shade = smoothstep(core, core + 0.35 * a + 1e-4, n);
    return vec4f(col.rgb * shade, col.a);
}
