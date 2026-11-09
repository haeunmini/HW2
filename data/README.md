# Benchmark data

The 100 benchmark images are deliberately not committed. Prepare exactly 30
images under `data/benchmark/tune/` and 70 under `data/benchmark/eval/`, with
one of these six directory names: `plastic`, `can`, `glass`, `paper`, `vinyl`,
or `general`. Run `python benchmark.py` to produce the before/after report.

Recommended public source: [TrashNet](https://github.com/garythung/trashnet),
MIT licensed. Its classes map as follows: `plastic` → `plastic`, `metal` →
`can`, `glass` → `glass`, `cardboard` and `paper` → `paper`, and `trash` →
`general`. TrashNet has no vinyl class, so vinyl must be sourced from a second
publicly licensed dataset and documented in the manifest; do not silently
label another class as vinyl. Use a deterministic seed when selecting 100
images and record source/license/sha256 in the excluded manifest.
