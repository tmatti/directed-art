import { Head, router } from "@inertiajs/react"
import {
  Camera,
  ChevronLeft,
  ChevronRight,
  Repeat,
  Volume2,
} from "lucide-react"
import { useCallback, useEffect, useRef, useState } from "react"

import DrawingCanvas from "@/components/drawing-canvas"
import { Button } from "@/components/ui/button"
import AppLayout from "@/layouts/app-layout"
import {
  directedDrawingArtworks,
  directedDrawingCurrentStep,
  directedDrawingRepeat,
} from "@/routes"
import directedDrawings from "@/routes/DirectedDrawingsController"
import type { Artwork, BreadcrumbItem, DirectedDrawing, Profile } from "@/types"

interface ShowProps {
  drawing: DirectedDrawing
  profile: Pick<Profile, "id" | "name">
  artworks: Artwork[]
}

export default function Show({ drawing, profile, artworks }: ShowProps) {
  const lastPage = drawing.steps.length + 1
  const [page, setPage] = useState(() =>
    Math.min(Math.max(drawing.current_step, 0), lastPage),
  )
  const fileInput = useRef<HTMLInputElement>(null)

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

  // Upload the photographed real drawing as an Artwork on R2 (ADR-0009). The
  // upload is optional; submitting reloads the show props with the new artwork.
  const uploadArtwork = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const file = fileInput.current?.files?.[0]
    if (!file) return
    const data = new FormData()
    data.append("photo", file)
    router.post(directedDrawingArtworks(drawing.id).url, data, {
      preserveScroll: true,
    })
    if (fileInput.current) fileInput.current.value = ""
  }

  // Repeat the Directed Drawing (ADR-0008): reset the Walkthrough to the cover
  // so the child re-walks the Steps from the start and can upload another
  // Artwork at the finish. The server is the source of truth for current_step,
  // so the local page follows it back to 0 once the repeat is confirmed.
  const repeatDrawing = () => {
    router.post(
      directedDrawingRepeat(drawing.id).url,
      {},
      {
        preserveScroll: true,
        onSuccess: () => setPage(0),
      },
    )
  }

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

        {isFinish && (
          <div className="flex w-full max-w-[560px] flex-col gap-4">
            <form onSubmit={uploadArtwork} className="flex flex-col gap-2">
              <label
                htmlFor="artwork-photo"
                className="text-muted-foreground text-sm font-medium"
              >
                Snap a photo of your drawing (optional)
              </label>
              <div className="flex items-center gap-2">
                <input
                  id="artwork-photo"
                  ref={fileInput}
                  type="file"
                  accept="image/*"
                  capture="environment"
                  className="text-sm"
                />
                <Button type="submit" size="sm">
                  <Camera /> Save photo
                </Button>
              </div>
            </form>

            {artworks.length > 0 && (
              <div className="flex flex-col gap-2">
                <p className="text-muted-foreground text-sm font-medium">
                  Your drawings
                </p>
                <div className="grid grid-cols-3 gap-2 sm:grid-cols-4">
                  {artworks.map((artwork) => (
                    <a
                      key={artwork.id}
                      href={artwork.photo_url}
                      target="_blank"
                      rel="noreferrer"
                    >
                      <img
                        src={artwork.photo_url}
                        alt="Your drawing"
                        className="aspect-square w-full rounded-lg border bg-white object-cover"
                      />
                    </a>
                  ))}
                </div>
              </div>
            )}

            <Button onClick={repeatDrawing} size="lg" className="w-full">
              <Repeat /> Draw again
            </Button>
          </div>
        )}

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
