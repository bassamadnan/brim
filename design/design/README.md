# BRSM Poster Design System

## Overview

This design system supports the **Behavioural Research in Statistical Methods (BRSM)** research poster presentation for **Spring 2026 at IIIT Hyderabad**.

**Team Name:** Earphones  
**Experiment:** Mnemonic Similarity Task (MST)  
**Course:** BRSM (Behavioural Research in Statistical Methods)

### Authors
| Name | Roll Number | Email |
|---|---|---|
| Sambu Aneesh | 2023121012 | sambu.aneesh@research.iiit.ac.in |
| Renu Sree Vyshnavi | 2022101035 | renu.sree@students.iiit.ac.in |
| Pavan Harshit Chinta | 2025701057 | pavan.harshit@research.iiit.ac.in |

---

## Sources

- **Poster Template:** `uploads/poster_template.pptx` — A4 landscape PPTX template with BRSM branding
- **Research Codebase:** https://github.com/ch-pavan/brim (branch: `develop`) — Full analysis pipeline, figures, and reports
- **Phase 2 Report:** `report/main_phase2.typ` (Typst source) — Full narrative writeup
- **Phase 2 Compiled Reports:** `report/BRSM_Project_Phase_2.pdf`
- **Key Figures:** Imported to `report/figures_phase2/` and `report/figures_phase2_slides/`

---

## Research Summary

The project investigates whether **event boundaries** (transitions between task contexts) affect recognition memory performance in an MST paradigm.

**Key Finding:** A post-boundary recognition cost is confirmed in the **Item + Task Shift** condition:
- Friedman χ²(2) = 11.47, p = .003, Kendall's W = 0.117
- Post-mid contrast: dz = −0.477, Holm p = .020
- SDT d-prime confirms: dz = −0.473, Holm p = .016

**Sample:** 3 conditions (Item Shift Only n=56, Item + Task Shift n=49, Task Shift Only n=53)

---

## CONTENT FUNDAMENTALS

**Tone:** Academic/scientific. Formal, third-person, precise. Statistical values reported with exact figures (χ², p-values, effect sizes, confidence intervals). Passive voice for methods ("were analysed", "was corrected"). Active voice for conclusions ("Phase 2 confirms…").

**Casing:** Section headers in ALL CAPS (ABSTRACT, METHODOLOGY, RESULTS, CONCLUSION). Body text in sentence case. No title case except for section subheadings.

**Copy style:**
- Bullet-point results with bold key terms (*Post-boundary recognition cost confirmed:*)
- Numbers always with proper notation: F(2,96) = 6.45, p = .002
- Effect sizes always reported alongside p-values
- Brief, factual. No marketing language.
- Statistical symbols: χ², dz, p (italicised in formal output)

**Emoji/Icons:** None. Pure text and data visualisations only.

**Voice:** "We" (team) when describing contributions. Passive for methods. Third-person for interpretation.

---

## VISUAL FOUNDATIONS

**Colors:**
- Primary teal: `#33ABBF` — used for footer bar, accents
- Light blue: `#B2E8F1` — header background, section backgrounds
- Blue: `#5B9BD5` — image placeholder backgrounds, highlights
- Dark text: `#000000` / `#1a1a1a`
- Section dividers: `#D9D9D9` light gray
- Footer text: `#FFFFFF` white on teal

**Typography:**
- Primary font: Calibri (system) / Carlito (Google Fonts substitute)
- Title: Bold, ~28–36pt, all-caps or sentence case
- Section headers: ~14pt bold, all-caps, on gray bar
- Body: ~10–11pt regular
- Captions: ~8–9pt italic gray

**Poster Layout (A4 Landscape: 1190 × 841px):**
1. **Top header band** (~18% height): Light blue `#B2E8F1` — title + author info
2. **3-column content area** (~75%): White background
   - Left col (~30%): Abstract, Methodology
   - Middle col (~40%): Results (primary figures)
   - Right col (~30%): Secondary results, Conclusion, References
3. **Bottom footer bar** (~7%): Teal `#33ABBF` — author names, emails, event title

**Section headers:** Gray `#D9D9D9` bar spanning column width, ALL CAPS black text, ~10px height.

**Backgrounds:** Flat color only. No gradients, no textures. White content area.

**Image treatment:** Figures in light blue `#B2E8F1` or white containers. No border radius on images. Simple 1px gray borders on figure containers.

**Animation:** None — static poster format.

**Spacing:** Tight but readable. 8–12px internal padding in sections. 4–6px gap between columns.

**Corner radii:** 0 — all rectangular shapes. Academic poster style.

**Cards/containers:** Flat, no shadow. Bordered with `#D9D9D9` or color-filled backgrounds.

---

## ICONOGRAPHY

No icons used. The BRSM poster design uses:
- Pure text sections
- Data visualisation figures (matplotlib-generated PNGs)
- Flat color bars for section headers and footer
- No icon fonts, no SVG icons, no emoji

---

## File Index

```
README.md                          ← This file
SKILL.md                           ← Agent skill definition
colors_and_type.css               ← CSS design tokens
assets/
  image1.jpeg                     ← Background hills illustration (from template)
report/
  figures_phase2/                 ← Full-resolution analysis figures
  figures_phase2_slides/          ← Slide-optimised figures (cleaner)
slides/
  BRSM_Poster.html               ← Main research poster (A4 landscape)
preview/
  colors.html                     ← Color palette card
  typography.html                 ← Type specimen card
  poster_layout.html             ← Poster layout overview
ui_kits/
  poster/
    index.html                    ← Interactive poster preview
```
