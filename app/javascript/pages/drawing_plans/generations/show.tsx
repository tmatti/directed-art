import { Head, router } from "@inertiajs/react"
import {
  Heart,
  Palette,
  RefreshCw,
  Sparkles,
  TriangleAlert,
} from "lucide-react"
import { useEffect } from "react"

import DrawingCanvas from "@/components/drawing-canvas"
import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Spinner } from "@/components/ui/spinner"
import AppLayout from "@/layouts/app-layout"
import { directedDrawingConfirmation } from "@/routes"
import directedDrawings from "@/routes/DirectedDrawingsController"
import drawingPlansGenerations from "@/routes/DrawingPlans/GenerationsController"
import type { DirectedDrawing } from "@/types"

type GenerationStatus =
  | "building"
  | "completed"
  | "generating"
  | "ready"
  | "failed"

interface Generation {
  id: number
  status: GenerationStatus
  directed_drawing_id: number | null
  // The candidate's cover payload, present only once ready and awaiting the
  // child's confirmation (ADR-0002).
  drawing: DirectedDrawing | null
}

// How often the wait screen asks the status endpoint whether the drawing is
// ready (ADR-0009). A one-shot generation, so simple polling beats websockets.
const POLL_INTERVAL_MS = 1500

export default function Show({ generation }: { generation: Generation }) {
  const pending =
    generation.status === "generating" ||
    generation.status === "completed" ||
    generation.status === "building"

  // While the job runs, re-fetch this page's status prop on an interval. Once
  // it's no longer pending the effect re-runs and stops polling.
  useEffect(() => {
    if (!pending) return

    const timer = setInterval(() => {
      router.reload({ only: ["generation"] })
    }, POLL_INTERVAL_MS)

    return () => clearInterval(timer)
  }, [pending])

  // A ready generation with no preview means the candidate has already been
  // confirmed (e.g. the child reloaded this URL after accepting). There is
  // nothing left to gate, so send them straight to the Walkthrough.
  useEffect(() => {
    if (
      generation.status === "ready" &&
      !generation.drawing &&
      generation.directed_drawing_id
    ) {
      router.visit(directedDrawings.show(generation.directed_drawing_id).url)
    }
  }, [generation.status, generation.drawing, generation.directed_drawing_id])

  return (
    <AppLayout>
      <Head title="Drawing your picture…" />

      <div className="mx-auto flex h-full w-full max-w-2xl flex-1 flex-col items-center justify-center gap-6 p-4">
        {generation.status === "failed" ? (
          <Failed planId={generation.id} />
        ) : generation.status === "ready" && generation.drawing ? (
          <Confirm drawing={generation.drawing} planId={generation.id} />
        ) : (
          <Waiting />
        )}
      </div>
    </AppLayout>
  )
}

// The friendly "drawing your picture…" state shown while the job runs.
function Waiting() {
  return (
    <Card className="border-primary/30 w-full">
      <CardContent className="flex flex-col items-center gap-4 py-8 text-center">
        <div className="bg-primary/10 text-primary flex size-16 items-center justify-center rounded-full">
          <Sparkles className="size-8 animate-pulse" />
        </div>
        <Heading
          title="Drawing your picture…"
          description="Our drawing helper is sketching every step just for you. This only takes a moment!"
        />
        <Spinner className="text-primary size-6" />
      </CardContent>
    </Card>
  )
}

// The confirmation gate (ADR-0002): the finished picture, full-color, for the
// child to accept before any stepping. "I love it!" confirms and enters the
// Walkthrough; "Try again" regenerates, replacing this candidate.
function Confirm({
  drawing,
  planId,
}: {
  drawing: DirectedDrawing
  planId: number
}) {
  return (
    <Card className="border-primary/30 w-full">
      <CardContent className="flex flex-col items-center gap-5 py-8 text-center">
        <Heading
          title="Here's your picture!"
          description="Do you love it? If not, we can draw a brand-new one."
        />

        <DrawingCanvas
          steps={drawing.steps}
          canvas={drawing.canvas}
          page={0}
          className="w-full max-w-[420px] rounded-xl border bg-white shadow-sm"
        />

        <div className="flex flex-wrap items-center justify-center gap-3">
          <Button
            size="lg"
            onClick={() =>
              router.post(directedDrawingConfirmation(drawing.id).url)
            }
          >
            <Heart /> I love it!
          </Button>
          <Button
            size="lg"
            variant="outline"
            onClick={() =>
              router.post(drawingPlansGenerations.create(planId).url)
            }
          >
            <RefreshCw /> Try again
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

// Generation gave up after retrying. Offer a one-tap retry that re-enqueues.
function Failed({ planId }: { planId: number }) {
  return (
    <Card className="border-destructive/40 w-full">
      <CardContent className="flex flex-col items-center gap-4 py-8 text-center">
        <div className="bg-destructive/10 text-destructive flex size-16 items-center justify-center rounded-full">
          <TriangleAlert className="size-8" />
        </div>
        <Heading
          title="That drawing got away from us"
          description="Something went wrong while drawing your picture. Let's give it another try!"
        />
        <Button
          size="lg"
          onClick={() =>
            router.post(drawingPlansGenerations.create(planId).url)
          }
        >
          <Palette /> Try again
        </Button>
      </CardContent>
    </Card>
  )
}
