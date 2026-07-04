import { Head, Link } from "@inertiajs/react"

import AppLogoIcon from "@/components/app-logo-icon"
import { Button } from "@/components/ui/button"
import { sessions, users } from "@/routes"

export default function Welcome() {
  return (
    <>
      <Head title="Welcome" />

      <div className="flex min-h-svh flex-col items-center justify-center gap-8 bg-neutral-50 p-6 dark:bg-neutral-950">
        <div className="flex w-full max-w-sm flex-col items-center gap-8">
          <div className="bg-sidebar-primary text-sidebar-primary-foreground flex size-16 items-center justify-center rounded-2xl">
            <AppLogoIcon className="size-10 fill-current text-white" />
          </div>

          <div className="flex flex-col items-center gap-2 text-center">
            <h1 className="text-2xl font-semibold tracking-tight">
              {import.meta.env.VITE_APP_NAME ?? "Directed Art"}
            </h1>
            <p className="text-muted-foreground max-w-xs text-sm">
              Step-by-step guided drawings for kids. Pick a subject, follow
              along, and draw your own picture.
            </p>
          </div>

          <div className="flex w-full flex-col gap-3">
            <Button asChild size="lg">
              <Link href={users.new()}>Get started</Link>
            </Button>
            <Button asChild size="lg" variant="outline">
              <Link href={sessions.new()}>Log in</Link>
            </Button>
          </div>
        </div>
      </div>
    </>
  )
}
