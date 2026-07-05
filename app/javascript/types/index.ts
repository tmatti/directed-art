import type { LucideIcon } from "lucide-react"

export interface Auth {
  user: User
  session: Pick<Session, "id">
  active_profile: Profile | null
}

export interface NavItem {
  title: string
  href: string
  icon?: LucideIcon | null
  isActive?: boolean
}

export interface FlashData {
  alert?: string
  notice?: string
}

export interface SharedProps {
  auth: Auth
}

export interface User {
  id: number
  name: string
  email: string
  avatar?: string
  verified: boolean
  created_at: string
  updated_at: string
  [key: string]: unknown // This allows for additional properties...
}

export interface Session {
  id: string
  user_agent: string
  ip_address: string
  created_at: string
}

export type AgeBand = "ages_4_6" | "ages_7_10"

export interface Profile {
  id: number
  name: string
  age_band: AgeBand
}

// --- Directed Drawing / Walkthrough (ADR-0001) ---

// A point is an [x, y] pair on the canvas (origin top-left, y-down).
export type Point = [number, number]

// The constrained Primitive vocabulary the renderer draws to SVG. `color` is
// suggested for the cover; Step pages deliberately ignore it (ADR-0008).
export type Primitive =
  | { type: "circle"; cx: number; cy: number; r: number; color?: string }
  | {
      type: "ellipse"
      cx: number
      cy: number
      rx: number
      ry: number
      rotate?: number
      color?: string
    }
  | {
      type: "line"
      x1: number
      y1: number
      x2: number
      y2: number
      color?: string
    }
  | { type: "polyline"; points: Point[]; color?: string }
  | { type: "polygon"; points: Point[]; color?: string }
  | {
      type: "arc"
      cx: number
      cy: number
      r: number
      start: number
      end: number
      color?: string
    }
  | { type: "curve"; points: Point[]; closed?: boolean; color?: string }

export interface DrawingStep {
  id: number
  position: number
  instruction: string
  narration: string | null
  primitives: Primitive[]
}

export interface Canvas {
  width: number
  height: number
}

export interface DirectedDrawing {
  id: number
  subject: string
  title: string
  current_step: number
  canvas: Canvas
  steps: DrawingStep[]
}

// A photo of the child's real paper drawing, captured at the finish page and
// served via Active Storage (R2 in production). A drawing can collect many
// because a child may repeat the steps (ADR-0009).
export interface Artwork {
  id: number
  photo_url: string
}
