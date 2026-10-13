# README motion direction

Request: add SVG motion graphics to the hero; let users see the problem and outcome before explanatory text. Local candidate work is authorized; public release remains gated.

Direction: editorial light, composed, clear, tangible. Use existing Claude Harness logo orange (#F67847 sampled/derived from logo tone), ink #1B1B22, white #FFFFFF, warm surface #FCFBF9 from current loop asset. System UI font is chosen to match GitHub's native typography and avoid external font downloads. One accent only. No new host claims or fake test results.

Considered: (1) circulating five-step loop, (2) scattered request cards consolidate into a readable work path, (3) an endless stream of terminal text. Select (2): it shows the burden being removed rather than requiring users to decipher commands. One persistent world, three paper objects, gathered paths, final human decision marker. No slide deck, typed command spectacle, or decorative 3D.

Timeline: 0–2s scattered plan/work/check cards with a short problem caption; 2–4s cards settle into aligned positions and connecting paths draw; 4–7s a warm pulse traverses the path; 7–10s the decision marker settles and the outcome caption holds; 10–12s return to the initial state. Default loop, no sound. Reduced-motion shows the completed path without animation. All stage labels stay readable even when paused.

Output: EN and JA self-contained SVG, static posters, GIF render from the same SVG/time model for GitHub README, and an inline T3 HTML preview. No JavaScript inside the SVG, external fonts/images, provider calls, or paid rendering. Preserve the existing logo rather than redraw it. GitHub's documentation states SVG animation is not supported in its image viewing path; use the GIF as the README display and keep SVG as editable source. Actual GitHub readback waits for authorized publication.

Owned paths: docs/images/readme/hero-motion-{en,ja}.svg, hero-motion-{en,ja}.gif, hero-motion-{en,ja}-poster.svg; docs/images/.gitignore exact asset entries; docs/research/readme-visual-asset-manifest.md; specs/2026-10-readme-motion/design.md; specs/2026-10-readme-motion/build-assets.py; README.md; README_ja.md; Plans.md; spec.md. Runtime and behavioral assertions remain unchanged. Phase148 separately allows presentation expectations and immutable historical-source references to change in three documentation tests.


## Local acceptance, 2026-10-13

Independent Claude Opus 5.5 review R3: APPROVE, Critical 0, Major 0.
The R1 moving dot/text collision and R2 overlapping heading transitions are corrected.
Both language GIFs decode to a 12,000 ms loop (EN 120 frames, JA 119 frames).
SVG heading opacity was checked at 1,201 points at 10 ms intervals: no simultaneous pain/result visibility.
The decision connector is visible only while the third card is aligned.
The ten documentation checks exited 0; the reviewed README and six asset hashes matched the tested snapshot.

Acceptance is local. GitHub image-proxy rendering and the reduced-motion picture branch have not been observed on GitHub.
At 360 px width, supporting labels scale to about 7 px. OS font substitution remains unobserved.
The timeline evidence is not a committed regression test; future motion edits need another timeline check.
