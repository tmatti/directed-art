import { Form, Head, Link, usePage } from "@inertiajs/react"
import { Plus } from "lucide-react"

import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import { Card, CardDescription, CardTitle } from "@/components/ui/card"
import AppLayout from "@/layouts/app-layout"
import { ageBandLabel } from "@/lib/age-bands"
import { cn } from "@/lib/utils"
import { newProfile } from "@/routes"
import activeProfile from "@/routes/ActiveProfilesController"
import type { Profile } from "@/types"

export default function Show({ profiles: list }: { profiles: Profile[] }) {
  const { auth } = usePage().props

  return (
    <AppLayout>
      <Head title="Who's drawing today?" />

      <div className="flex h-full flex-1 flex-col items-center gap-8 p-4 pt-10">
        <Heading title="Who's drawing today?" />

        {list.length === 0 ? (
          <Button asChild>
            <Link href={newProfile()}>
              <Plus /> Add a profile
            </Link>
          </Button>
        ) : (
          <div className="grid w-full max-w-3xl gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {list.map((child) => (
              <Form key={child.id} action={activeProfile.update()}>
                <input type="hidden" name="profile_id" value={child.id} />
                <button type="submit" className="w-full text-left">
                  <Card
                    className={cn(
                      "hover:border-primary cursor-pointer items-center p-6 text-center transition-colors",
                      auth.active_profile?.id === child.id && "border-primary",
                    )}
                  >
                    <CardTitle className="text-lg">{child.name}</CardTitle>
                    <CardDescription>
                      {ageBandLabel(child.age_band)}
                    </CardDescription>
                  </Card>
                </button>
              </Form>
            ))}
          </div>
        )}
      </div>
    </AppLayout>
  )
}
