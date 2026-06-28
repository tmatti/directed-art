import type { JSX } from "react"

import { arcPath, isFillable, pointsAttr, splinePath } from "@/lib/drawing"
import type { Canvas, DrawingStep, Primitive } from "@/types"

// How a Primitive is painted. The cover is full-color; Step pages render
// line-art with prior marks calm and the current Step Highlighted (ADR-0008).
type Mode = "cover" | "prior" | "current"

const PRIOR = "#9aa0a6"
const HIGHLIGHT = "#e23b3b"
const COVER_STROKE = "#222222"
const COVER_FILL = "#dfe6ee"

// Presentation attributes common to every SVG shape, so one paint result can be
// spread onto any element regardless of its specific type.
interface PaintProps {
  fill: string
  stroke: string
  strokeWidth: number
  strokeLinecap: "round"
  strokeLinejoin: "round"
}

function paint(primitive: Primitive, mode: Mode): PaintProps {
  const base = { strokeLinecap: "round", strokeLinejoin: "round" } as const

  if (mode === "cover") {
    return isFillable(primitive)
      ? {
          ...base,
          fill: primitive.color ?? COVER_FILL,
          stroke: COVER_STROKE,
          strokeWidth: 3,
        }
      : {
          ...base,
          fill: "none",
          stroke: primitive.color ?? COVER_STROKE,
          strokeWidth: 4,
        }
  }

  if (mode === "prior") {
    return { ...base, fill: "none", stroke: PRIOR, strokeWidth: 3 }
  }

  return { ...base, fill: "none", stroke: HIGHLIGHT, strokeWidth: 5 }
}

function shape(
  primitive: Primitive,
  props: PaintProps,
  key: string,
): JSX.Element | null {
  switch (primitive.type) {
    case "circle":
      return (
        <circle
          key={key}
          cx={primitive.cx}
          cy={primitive.cy}
          r={primitive.r}
          {...props}
        />
      )
    case "ellipse":
      return (
        <ellipse
          key={key}
          cx={primitive.cx}
          cy={primitive.cy}
          rx={primitive.rx}
          ry={primitive.ry}
          transform={
            primitive.rotate
              ? `rotate(${primitive.rotate} ${primitive.cx} ${primitive.cy})`
              : undefined
          }
          {...props}
        />
      )
    case "line":
      return (
        <line
          key={key}
          x1={primitive.x1}
          y1={primitive.y1}
          x2={primitive.x2}
          y2={primitive.y2}
          {...props}
        />
      )
    case "polyline":
      return (
        <polyline key={key} points={pointsAttr(primitive.points)} {...props} />
      )
    case "polygon":
      return (
        <polygon key={key} points={pointsAttr(primitive.points)} {...props} />
      )
    case "arc":
      return (
        <path
          key={key}
          d={arcPath(
            primitive.cx,
            primitive.cy,
            primitive.r,
            primitive.start,
            primitive.end,
          )}
          {...props}
        />
      )
    case "curve":
      return (
        <path
          key={key}
          d={splinePath(primitive.points, Boolean(primitive.closed))}
          {...props}
        />
      )
    default:
      return null
  }
}

function renderPrimitives(
  primitives: Primitive[],
  mode: Mode,
  keyPrefix: string,
) {
  return primitives.map((primitive, i) =>
    shape(primitive, paint(primitive, mode), `${keyPrefix}-${i}`),
  )
}

interface DrawingCanvasProps {
  steps: DrawingStep[]
  canvas: Canvas
  // 0 = cover, 1..N = Step pages, N+1 = finish (rendered full-color, like the cover).
  page: number
  className?: string
}

export default function DrawingCanvas({
  steps,
  canvas,
  page,
  className,
}: DrawingCanvasProps) {
  const showFullColor = page <= 0 || page > steps.length

  return (
    <svg
      viewBox={`0 0 ${canvas.width} ${canvas.height}`}
      className={className}
      role="img"
      xmlns="http://www.w3.org/2000/svg"
    >
      <rect
        x={0}
        y={0}
        width={canvas.width}
        height={canvas.height}
        fill="#ffffff"
      />

      {showFullColor
        ? steps.flatMap((step, i) =>
            renderPrimitives(step.primitives, "cover", `s${i}`),
          )
        : steps
            .slice(0, page)
            .flatMap((step, i) =>
              renderPrimitives(
                step.primitives,
                i === page - 1 ? "current" : "prior",
                `s${i}`,
              ),
            )}
    </svg>
  )
}
