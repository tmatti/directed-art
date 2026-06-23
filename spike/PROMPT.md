# Directed Art — DSL spike prompt

Paste everything below the line into Claude Desktop. Change only the **SUBJECT** and **AGE BAND** lines.
Copy the JSON it returns into `viewer.html` → Load. Step through with ← / →.

If the drawings look like a recognizable, *appealing* version of the subject → the DSL works.
If they're crude/abstract → note what's missing (smoother curves? more primitive types?) and we enrich the DSL before building.

---

You generate **directed drawings** for children ages 4–10 to copy onto paper, step by step. You output the drawing as **structured JSON only** — never SVG, never prose. A fixed renderer turns your JSON into the picture, so the quality depends entirely on how well you compose the allowed primitives.

## The drawing

SUBJECT: **a happy cat**
AGE BAND: **7-10**   (4-6 → 5–7 simple steps; 7-10 → 10–14 finer steps)

## Canvas

- A 600 × 600 square. Origin (0,0) is the **top-left**; x increases right, y increases **down**.
- So the sky/top is low y, the ground/bottom is high y. Center is (300, 300).
- Keep the whole drawing inside generous margins (roughly 60–540).

## Primitives (the only shapes you may use)

Every primitive is an object with a `type` and an optional `color` (hex string = the suggested color for that mark, used only on the color cover).

| type | fields | use for |
|------|--------|---------|
| `circle` | `cx, cy, r` | heads, eyes, wheels, round things |
| `ellipse` | `cx, cy, rx, ry, rotate?` (rotate in degrees) | bodies, ears, ovals at an angle |
| `line` | `x1, y1, x2, y2` | straight edges, whiskers, ground |
| `polyline` | `points: [[x,y], …]` | open zig-zags, simple open paths |
| `polygon` | `points: [[x,y], …]` | triangles, angular closed shapes (auto-closes) |
| `arc` | `cx, cy, r, start, end` | smiles, partial circles. Angles in degrees: 0 = right, 90 = down, 180 = left, 270 = up; drawn clockwise from start to end |
| `curve` | `points: [[x,y], …], closed?` | **organic, rounded outlines** — animal bodies, blobs, soft shapes. Renders as a smooth spline through the points. Set `closed: true` for a closed, fillable outline |

Notes:
- `circle`, `ellipse`, `polygon`, and a `closed` `curve` are **fillable** (filled with `color` on the cover). All others are strokes.
- Favor `curve` for anything soft and lifelike — it's the key to appealing, non-blocky drawings.

## How to compose a good directed drawing

1. **Draw the whole thing in your head first**, then break it into teaching steps. Big anchoring shapes first (body, head), then features, then small details last.
2. **Draw a complete, anatomically whole subject.** Include every body part the subject naturally has — a cat has four legs/paws and a tail; a person has two arms and two legs. Don't omit limbs or appendages.
3. **Tapering or flowing parts** (tails, trunks, necks, flower stems, snakes) must be drawn as a **`closed: true` curve tracing the part's filled silhouette** — outline both sides so it tapers — NOT a single open stroke. Every stroke in this system is uniform width, so an open line cannot taper and will look limp.
4. Each **step adds only the NEW primitives** for that step — never repeat earlier ones. The renderer accumulates them.
5. Each step is a **meaningful chunk** a child can do ("draw the head", "add two ears"), not a single line.
6. Give every step a short kid-facing `instruction` and a warm spoken `narration` (a friendly sentence read aloud).
7. Assign sensible `color`s for the cover (a child still colors their own paper).

## Output format — return ONLY this JSON

```json
{
  "subject": "…",
  "title": "Let's draw …!",
  "ageBand": "7-10",
  "canvas": { "width": 600, "height": 600 },
  "steps": [
    {
      "instruction": "short kid-facing text",
      "narration": "warm sentence read aloud",
      "primitives": [ { "type": "…", "…": 0, "color": "#rrggbb" } ]
    }
  ]
}
```

Return the JSON in a single fenced code block. Nothing else.
