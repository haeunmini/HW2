# CLIP model update benchmark

## Data and mapping

The benchmark uses 100 images downloaded over HTTP from the public, ungated
Hugging Face dataset
[`Dhurgananth/waste-garbage-management-dataset`](https://huggingface.co/datasets/Dhurgananth/waste-garbage-management-dataset).
Its dataset card declares the MIT license. The exact source URL and SHA-256 of
each downloaded image are in the excluded `data/benchmark-manifest.json`.

The source classes were mapped to the app categories as follows:

| Source class | App category |
| --- | --- |
| Metal | can |
| Glass | glass |
| Paper, Cardboard | paper |
| Plastic | plastic |
| Trash | general |

The source has no vinyl class. Consequently this benchmark contains no vinyl
ground-truth examples; vinyl is not silently represented by plastic.

The deterministic split is 30 tuning images and 70 final evaluation images.
The final evaluation images were not used to choose prompts.

## Results

The baseline is the existing `openai/clip-vit-base-patch32` pipeline and the
existing `categories.json` labels. Two prompt-only attempts were evaluated;
neither was promoted.

| Split | Baseline | Attempt 1 | Attempt 2 |
| --- | ---: | ---: | ---: |
| Tuning (30) | 19/30 = 63.33% | 16/30 = 53.33% | 15/30 = 50.00% |
| Final evaluation (70) | 44/70 = 62.86% | 44/70 = 62.86% | 36/70 = 51.43% |

Because both permitted improvement attempts reduced or failed to improve the
held-out score, the deployed classifier intentionally remains on the original
baseline. This is an evidence-based model update decision, not a claim of
improvement where the experiment did not show one.
