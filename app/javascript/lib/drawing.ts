import type { Point, Primitive } from "@/types"

// Pure geometry for the constrained Primitive DSL (ADR-0001), ported from the
// spike viewer. These turn Primitives into the path data <DrawingCanvas> renders.

// A point on a circle of radius r at `deg` degrees (0 = right, clockwise, y-down).
export function polar(
  cx: number,
  cy: number,
  r: number,
  deg: number,
): { x: number; y: number } {
  const a = (deg * Math.PI) / 180
  return { x: cx + r * Math.cos(a), y: cy + r * Math.sin(a) }
}

// SVG path for a circular arc swept clockwise from `start` to `end` degrees.
export function arcPath(
  cx: number,
  cy: number,
  r: number,
  start: number,
  end: number,
): string {
  const s = polar(cx, cy, r, start)
  const e = polar(cx, cy, r, end)
  const large = Math.abs(end - start) > 180 ? 1 : 0
  return `M ${s.x} ${s.y} A ${r} ${r} 0 ${large} 1 ${e.x} ${e.y}`
}

// SVG path for a smooth Catmull-Rom spline through `points`, optionally closed.
export function splinePath(points: Point[], closed: boolean): string {
  if (!points || points.length < 2) return ""
  const p = points.map(([x, y]) => ({ x, y }))
  const pts = closed
    ? [p[p.length - 1], ...p, p[0], p[1]]
    : [p[0], ...p, p[p.length - 1]]

  let d = `M ${pts[1].x} ${pts[1].y}`
  for (let i = 1; i < pts.length - 2; i++) {
    const p0 = pts[i - 1]
    const p1 = pts[i]
    const p2 = pts[i + 1]
    const p3 = pts[i + 2]
    const c1x = p1.x + (p2.x - p0.x) / 6
    const c1y = p1.y + (p2.y - p0.y) / 6
    const c2x = p2.x - (p3.x - p1.x) / 6
    const c2y = p2.y - (p3.y - p1.y) / 6
    d += ` C ${c1x} ${c1y}, ${c2x} ${c2y}, ${p2.x} ${p2.y}`
  }
  if (closed) d += " Z"
  return d
}

// Primitives whose interior can be filled (used only on the full-color cover).
export function isFillable(primitive: Primitive): boolean {
  switch (primitive.type) {
    case "circle":
    case "ellipse":
    case "polygon":
      return true
    case "curve":
      return Boolean(primitive.closed)
    default:
      return false
  }
}

// Serializes a [[x, y], ...] list into the SVG `points` attribute format.
export function pointsAttr(points: Point[]): string {
  return points.map((pt) => pt.join(",")).join(" ")
}
