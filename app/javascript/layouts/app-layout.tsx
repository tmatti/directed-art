import { Link, router, usePage } from "@inertiajs/react"
import { LogOut, Settings, Smile, Users } from "lucide-react"
import type { ReactNode } from "react"

import AppLogo from "@/components/app-logo"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { activeProfile, sessions, settingsProfiles } from "@/routes"
import directedDrawings from "@/routes/DirectedDrawingsController"
import profiles from "@/routes/ProfilesController"

interface AppLayoutProps {
  children: ReactNode
}

// Radix locks body pointer-events while a menu is open; navigating away via
// Inertia can leave that lock behind, so clear it whenever a menu item fires.
const unlockBody = () => {
  document.body.style.removeProperty("pointer-events")
}

export default function AppLayout({ children }: AppLayoutProps) {
  const { auth } = usePage().props

  const handleLogout = () => {
    unlockBody()
    router.flushAll()
  }

  return (
    <div className="flex min-h-svh flex-col">
      <header className="flex h-14 shrink-0 items-center gap-2 border-b px-4">
        <Link
          href={directedDrawings.index()}
          prefetch
          className="flex items-center"
        >
          <AppLogo />
        </Link>

        <div className="ml-auto flex items-center gap-1">
          <Button asChild variant="secondary" className="rounded-full">
            <Link href={activeProfile()} prefetch>
              <Smile />
              {auth.active_profile?.name ?? "Who's drawing?"}
            </Link>
          </Button>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant="ghost"
                size="sm"
                className="text-muted-foreground"
              >
                Grown-ups
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent className="w-48" align="end">
              <DropdownMenuItem asChild>
                <Link
                  className="block w-full"
                  href={profiles.index()}
                  prefetch
                  onClick={unlockBody}
                >
                  <Users className="mr-2" />
                  Profiles
                </Link>
              </DropdownMenuItem>
              <DropdownMenuItem asChild>
                <Link
                  className="block w-full"
                  href={settingsProfiles.show()}
                  as="button"
                  prefetch
                  onClick={unlockBody}
                >
                  <Settings className="mr-2" />
                  Settings
                </Link>
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem asChild>
                <Link
                  className="block w-full"
                  href={sessions.destroy(auth.session.id)}
                  as="button"
                  onClick={handleLogout}
                >
                  <LogOut className="mr-2" />
                  Log out
                </Link>
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </header>

      <main className="flex flex-1 flex-col">{children}</main>
    </div>
  )
}
