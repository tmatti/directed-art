import { Form, Head, Link } from "@inertiajs/react"
import { Camera, Palette, Play, Plus, Repeat } from "lucide-react"

import DrawingCanvas from "@/components/drawing-canvas"
import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import AppLayout from "@/layouts/app-layout"
import directedDrawings from "@/routes/DirectedDrawingsController"
import drawingPlans from "@/routes/DrawingPlansController"
import type { Artwork, DirectedDrawing } from "@/types"

function NewDrawingButton() {
  return (
    <Form action={drawingPlans.create()}>
      <Button type="submit" size="xl">
        <Plus /> New drawing
      </Button>
    </Form>
  )
}

// A gallery entry is a Directed Drawing plus its photographed Artwork(s): the
// finished AI reference (rendered as the cover) and the child's real drawings.
interface GalleryEntry extends DirectedDrawing {
  artworks: Artwork[]
}

// A glanceable status for pre-readers: an icon plus a short word, with a tiny
// progress bar (instead of a "Step X of Y" sentence) when partway through.
function DrawingStatus({ drawing }: { drawing: GalleryEntry }) {
  const lastStep = drawing.steps.length

  if (drawing.current_step === 0) {
    return (
      <span className="text-primary inline-flex items-center gap-1.5 font-semibold">
        <Play className="size-4" /> Start
      </span>
    )
  }

  if (drawing.current_step > lastStep) {
    return (
      <span className="inline-flex items-center gap-1.5 font-semibold">
        <Repeat className="size-4" /> Draw again
      </span>
    )
  }

  return (
    <span className="inline-flex items-center gap-2 font-semibold">
      Keep going
      <span
        role="img"
        aria-label={`Step ${drawing.current_step} of ${lastStep}`}
        className="bg-muted h-1.5 w-16 overflow-hidden rounded-full"
      >
        <span
          className="bg-primary block h-full rounded-full"
          style={{
            width: `${Math.round((drawing.current_step / lastStep) * 100)}%`,
          }}
        />
      </span>
    </span>
  )
}

export default function Index({ drawings }: { drawings: GalleryEntry[] }) {
  return (
    <AppLayout>
      <Head title="Drawings" />

      <div className="flex h-full flex-1 flex-col gap-6 p-4">
        <div className="flex items-center justify-between gap-4">
          <Heading title="Your drawings" />
          <NewDrawingButton />
        </div>

        {drawings.length === 0 ? (
          <Card className="items-center text-center">
            <CardHeader className="w-full">
              <CardTitle>No drawings yet</CardTitle>
              <CardDescription>
                Start your first drawing and it&apos;ll show up here.
              </CardDescription>
              <div className="pt-2">
                <NewDrawingButton />
              </div>
            </CardHeader>
          </Card>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {drawings.map((drawing) => (
              <Link key={drawing.id} href={directedDrawings.show(drawing.id)}>
                <Card className="hover:border-primary h-full cursor-pointer transition-colors">
                  <div className="px-6">
                    <DrawingCanvas
                      steps={drawing.steps}
                      canvas={drawing.canvas}
                      page={0}
                      className="aspect-square w-full rounded-lg border bg-white"
                    />
                  </div>
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                      <Palette className="size-4" /> {drawing.title}
                    </CardTitle>
                    <CardDescription>
                      <DrawingStatus drawing={drawing} />
                    </CardDescription>
                  </CardHeader>
                  {drawing.artworks.length > 0 && (
                    <CardContent>
                      <p className="text-muted-foreground mb-2 flex items-center gap-1.5 text-xs font-medium">
                        <Camera className="size-3.5" /> Your drawings
                      </p>
                      <div className="flex flex-wrap gap-1.5">
                        {drawing.artworks.map((artwork) => (
                          <img
                            key={artwork.id}
                            src={artwork.photo_url}
                            alt="Your drawing"
                            className="size-12 rounded-md border bg-white object-cover"
                          />
                        ))}
                      </div>
                    </CardContent>
                  )}
                </Card>
              </Link>
            ))}
          </div>
        )}
      </div>
    </AppLayout>
  )
}
