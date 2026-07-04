import { Link } from "@inertiajs/react"
import { LayoutGrid, Palette, Users } from "lucide-react"

import { NavMain } from "@/components/nav-main"
import { NavUser } from "@/components/nav-user"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import { activeProfile } from "@/routes"
import directedDrawings from "@/routes/DirectedDrawingsController"
import profiles from "@/routes/ProfilesController"
import type { NavItem } from "@/types"

import AppLogo from "./app-logo"

const mainNavItems: NavItem[] = [
  {
    title: "Drawings",
    href: directedDrawings.index().url,
    icon: LayoutGrid,
  },
  {
    title: "Profiles",
    href: profiles.index().url,
    icon: Users,
  },
  {
    title: "Who's drawing?",
    href: activeProfile().url,
    icon: Palette,
  },
]

export function AppSidebar() {
  return (
    <Sidebar collapsible="icon" variant="inset">
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" asChild>
              <Link href={directedDrawings.index()} prefetch>
                <AppLogo />
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>

      <SidebarContent>
        <NavMain items={mainNavItems} />
      </SidebarContent>

      <SidebarFooter>
        <NavUser />
      </SidebarFooter>
    </Sidebar>
  )
}
