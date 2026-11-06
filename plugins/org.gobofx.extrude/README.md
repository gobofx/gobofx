# Extrude

A layer's alpha shape pulled out into a solid block: its silhouette is
stamped behind it along one direction, in a side colour that darkens
towards the far end so the block reads as lit. Needs transparency to work
with; a full-frame clip has no edge to extrude. **Depth** 0 returns the
source untouched.

- **Depth** — length of the block in pixels; 8–16 px for a title, 40+ for a chunky logo.
- **Angle** — the direction the block recedes in, in degrees; 45° is down-right, the conventional view from above-left.
- **Color** — the side colour; a darker shade of the face colour reads as the same material, grey as a cast block.
- **Shading** — how much darker the far end is than the near end; 0 is a flat side, 1 fades to black.

## Use it when

- A title, a lower third or a logo wants the chunky 3D-text feel without a 3D scene; pair it with a Drop Shadow underneath.
- A flat cut-out graphic (an arrow, a badge, a speech bubble) should look like a physical object on the frame.
- A retro, poster or sports-package look where fat extruded letters are the point.

## Avoid when

- The layer has no transparency: nothing is extruded and the effect is a no-op.
- The design is flat or editorial; extruded type reads as a template from the moment it appears.
- The block must be long or the light must move: a 2D stamp cannot show perspective or a turning face.
