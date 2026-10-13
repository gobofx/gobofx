# Test clips

Synthetic, generated with ffmpeg, no rights attached (CC0). Used by the play page.

- `a.mp4` — 1280×720, 8 s, 30 fps, moving test pattern. Audio: a kick-drum
  pattern every 0.5 s (55 Hz, decaying) with a soft 220 Hz off-beat, so a
  signal fed from an audio follower on the bass band has something to follow.
- `b.mp4` — 1280×720, 8 s, 30 fps, zooming Mandelbrot set. Audio: quiet 110 Hz sine.

Regenerate:

```sh
ffmpeg -y -f lavfi -i "testsrc2=size=1280x720:rate=30,format=yuv420p" \
  -f lavfi -i "aevalsrc='0.9*sin(2*PI*55*t)*exp(-mod(t,0.5)*9) + 0.15*sin(2*PI*220*t)*exp(-mod(t+0.25,0.5)*20)':s=48000" \
  -t 8 -c:v libx264 -profile:v main -preset slow -crf 26 -g 30 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 96k a.mp4
ffmpeg -y -f lavfi -i "mandelbrot=size=1280x720:rate=30:maxiter=200:end_scale=0.1:start_scale=3,format=yuv420p" \
  -f lavfi -i "sine=frequency=110:sample_rate=48000" \
  -t 8 -c:v libx264 -profile:v main -preset slow -crf 26 -g 30 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 64k -af "volume=0.2" b.mp4
```
