import { Head, router } from "@inertiajs/react"
import { ChevronLeft, ChevronRight, Volume2 } from "lucide-react"
import { useCallback, useEffect, useState } from "react"

import DrawingCanvas from "@/components/drawing-canvas"
import { Button } from "@/components/ui/button"
import AppLayout from "@/layouts/app-layout"
import { directedDrawingCurrentStep } from "@/routes"
import directedDrawings from "@/routes/DirectedDrawingsController"
import type { BreadcrumbItem, DirectedDrawing, Profile } from "@/types"

interface ShowProps {
  drawing: DirectedDrawing
  profile: Pick<Profile, "id" | "name">
}

export default function Show({ drawing, profile }: ShowProps) {
  const lastPage = drawing.steps.length + 1
  const [page, setPage] = useState(() =>
    Math.min(Math.max(drawing.current_step, 0), lastPage),
  )

  const breadcrumbs: BreadcrumbItem[] = [
    { title: "Drawings", href: directedDrawings.index().url },
    { title: drawing.title, href: directedDrawings.show(drawing.id).url },
  ]

  // Persist the resumable position so the child returns to where they left off.
  const persist = useCallback(
    (next: number) => {
      router.patch(
        directedDrawingCurrentStep(drawing.id).url,
        { current_step: next },
        { preserveState: true, preserveScroll: true, replace: true },
      )
    },
    [drawing.id],
  )

  const go = useCallback(
    (next: number) => {
      const clamped = Math.min(Math.max(next, 0), lastPage)
      if (clamped === page) return
      setPage(clamped)
      persist(clamped)
    },
    [page, lastPage, persist],
  )

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "ArrowRight") go(page + 1)
      if (event.key === "ArrowLeft") go(page - 1)
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [go, page])

  const isCover = page === 0
  const isFinish = page > drawing.steps.length
  const step = !isCover && !isFinish ? drawing.steps[page - 1] : null

  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title={drawing.title} />

      <div className="mx-auto flex h-full w-full max-w-2xl flex-1 flex-col items-center gap-5 p-4 pt-8">
        <div className="min-h-20 text-center">
          <p className="text-muted-foreground text-xs font-medium tracking-widest uppercase">
            {isCover
              ? "Cover"
              : isFinish
                ? "All done!"
                : `Step ${page} of ${drawing.steps.length}`}
          </p>

          {isCover && (
            <>
              <h1 className="mt-1 text-2xl font-bold">{drawing.title}</h1>
              <p className="mt-1 text-lg">Here&apos;s what we&apos;ll draw!</p>
            </>
          )}

          {isFinish && (
            <>
              <h1 className="mt-1 text-2xl font-bold">You did it! 🎉</h1>
              <p className="mt-1 text-lg">
                Great drawing, {profile.name}! Color it in however you like.
              </p>
            </>
          )}

          {step && (
            <>
              <p className="mt-1 text-lg">{step.instruction}</p>
              {step.narration && (
                <p className="text-muted-foreground mt-1 flex items-center justify-center gap-1.5 text-sm italic">
                  <Volume2 className="size-4 shrink-0" /> {step.narration}
                </p>
              )}
            </>
          )}
        </div>

        <DrawingCanvas
          steps={drawing.steps}
          canvas={drawing.canvas}
          page={page}
          className="w-full max-w-[560px] rounded-xl border bg-white shadow-sm"
        />

        <div className="flex items-center gap-3">
          <Button
            variant="outline"
            onClick={() => go(page - 1)}
            disabled={page <= 0}
          >
            <ChevronLeft /> Prev
          </Button>
          <Button onClick={() => go(page + 1)} disabled={page >= lastPage}>
            Next <ChevronRight />
          </Button>
        </div>
      </div>
    </AppLayout>
  )
}
