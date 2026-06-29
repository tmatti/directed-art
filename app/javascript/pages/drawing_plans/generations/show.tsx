import { Head, router } from "@inertiajs/react"
import { Palette, Sparkles, TriangleAlert } from "lucide-react"
import { useEffect } from "react"

import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Spinner } from "@/components/ui/spinner"
import AppLayout from "@/layouts/app-layout"
import directedDrawings from "@/routes/DirectedDrawingsController"
import drawingPlansGenerations from "@/routes/DrawingPlans/GenerationsController"
import type { BreadcrumbItem } from "@/types"

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
}

// How often the wait screen asks the status endpoint whether the drawing is
// ready (ADR-0009). A one-shot generation, so simple polling beats websockets.
const POLL_INTERVAL_MS = 1500

const breadcrumbs: BreadcrumbItem[] = [{ title: "New drawing", href: "" }]

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

  // The moment the drawing is ready, hand the child straight to its Walkthrough.
  useEffect(() => {
    if (generation.status === "ready" && generation.directed_drawing_id) {
      router.visit(directedDrawings.show(generation.directed_drawing_id).url)
    }
  }, [generation.status, generation.directed_drawing_id])

  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title="Drawing your picture…" />

      <div className="mx-auto flex h-full w-full max-w-2xl flex-1 flex-col items-center justify-center gap-6 p-4">
        {generation.status === "failed" ? (
          <Failed planId={generation.id} />
        ) : (
          <Waiting />
        )}
      </div>
    </AppLayout>
  )
}

// The friendly "drawing your picture…" state shown while (and just after) the
// job runs — including the brief flash before the ready redirect fires.
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
