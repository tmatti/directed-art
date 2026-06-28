import { Form, Head, Link } from "@inertiajs/react"
import { Palette, Plus } from "lucide-react"

import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import AppLayout from "@/layouts/app-layout"
import directedDrawings from "@/routes/DirectedDrawingsController"
import drawingPlans from "@/routes/DrawingPlansController"
import type { BreadcrumbItem } from "@/types"

function NewDrawingButton() {
  return (
    <Form action={drawingPlans.create()}>
      <Button type="submit">
        <Plus /> New drawing
      </Button>
    </Form>
  )
}

interface DrawingSummary {
  id: number
  subject: string
  title: string
  current_step: number
}

const breadcrumbs: BreadcrumbItem[] = [
  { title: "Drawings", href: directedDrawings.index().url },
]

export default function Index({ drawings }: { drawings: DrawingSummary[] }) {
  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title="Drawings" />

      <div className="flex h-full flex-1 flex-col gap-6 p-4">
        <div className="flex items-center justify-between gap-4">
          <Heading
            title="Drawings"
            description="Pick a drawing to walk through, step by step."
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
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                      <Palette className="size-4" /> {drawing.title}
                    </CardTitle>
                    <CardDescription>
                      {drawing.current_step > 0
                        ? "Resume where you left off"
                        : "Start drawing"}
                    </CardDescription>
                  </CardHeader>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </div>
    </AppLayout>
  )
}
