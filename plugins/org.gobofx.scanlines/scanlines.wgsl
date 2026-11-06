// Scanlines — horizontal lines over transparent, spaced in pixels so they
// sit on the output grid the way a tube's raster did. `speed` rolls them
// vertically in pixels per second.
struct Params {
    spacing: f32,   // float — line pitch in pixels
    thickness: f32, // float — line height as a fraction of the pitch
    opacity: f32,   // float — 0..1
    softness: f32,  // float — blur of the line edge, as a fraction of the line
    speed: f32,     // float — roll in pixels per second
    color: vec4f,   // color — premultiplied
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let spacing = max(params.spacing, 2.0);
    let y = uv.y * gobofx_globals.resolution.y + gobofx_globals.time * params.speed;
    let t = fract(y / spacing);
    let thick = clamp(params.thickness, 0.05, 0.95);
    // Edge width in pitch units: the softness setting, but at least ~1 px.
    let w = max(clamp(params.softness, 0.0, 1.0) * 0.5, 1.0 / spacing);
    // Centre the line on the half pitch so the first line is not clipped
    // at the top edge.
    let lo = 0.5 - thick * 0.5;
    let hi = 0.5 + thick * 0.5;
    let on = smoothstep(lo - w, lo + w, t) * (1.0 - smoothstep(hi - w, hi + w, t));
    return params.color * (on * clamp(params.opacity, 0.0, 1.0));
}
