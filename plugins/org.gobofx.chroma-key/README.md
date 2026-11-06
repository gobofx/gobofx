# Chroma Keyer

Key out a green or blue screen. Pixels whose chroma is within **Tolerance**
of the key colour become transparent, with a **Softness** band for edges and
hair; **Spill Suppression** pulls the screen's tint out of what remains.

- **Key Color** — pick the screen colour. The default is a typical green.
- **Show Matte** — view the alpha as a grey image while tuning.

## Use it when

- Green or blue screen, lit evenly. Pick **Key Color** from the screen, not
  the default, and tune with **Show Matte** on.
- Replacing a sky or a wall painted a key colour on the day.
- Roughing a composite for a cut review before the finish.

## Avoid when

- The subject wears the key colour, or has jewellery and glasses reflecting
  it. No slider fixes that; the costume does.
- The screen is unevenly lit or wrinkled. Keying is a lighting problem
  first; pushing **Tolerance** eats hair and edges.
- You are keying on brightness, not colour (a bright sky behind a dark
  subject). Use Luma Keyer. For a fixed region, use Shape Mask.
