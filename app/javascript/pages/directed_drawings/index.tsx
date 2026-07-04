import { Form, Head, Link } from "@inertiajs/react"
import { Camera, Palette, Plus } from "lucide-react"

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

function statusLabel(drawing: GalleryEntry): string {
  const lastStep = drawing.steps.length
  if (drawing.current_step === 0) return "Start drawing"
  if (drawing.current_step > lastStep) return "Draw again"
  return `Resume — Step ${drawing.current_step} of ${lastStep}`
}

export default function Index({ drawings }: { drawings: GalleryEntry[] }) {
  return (
    <AppLayout>
      <Head title="Drawings" />

      <div className="flex h-full flex-1 flex-col gap-6 p-4">
        <div className="flex items-center justify-between gap-4">
          <Heading
            title="Your drawings"
            description="Look back at your drawings or draw them again."
          />
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
                    <CardDescription>{statusLabel(drawing)}</CardDescription>
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
