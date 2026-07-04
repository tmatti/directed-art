import { Form, Head, Link, usePage } from "@inertiajs/react"
import { Pencil, Plus, Trash2 } from "lucide-react"

import Heading from "@/components/heading"
import ProfileAvatar from "@/components/profile-avatar"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import AppLayout from "@/layouts/app-layout"
import { ageBandLabel } from "@/lib/age-bands"
import { activeProfile, editProfile, newProfile } from "@/routes"
import profiles from "@/routes/ProfilesController"
import type { Profile } from "@/types"

export default function Index({ profiles: list }: { profiles: Profile[] }) {
  const { auth } = usePage().props

  return (
    <AppLayout>
      <Head title="Profiles" />

      <div className="flex h-full flex-1 flex-col gap-6 p-4">
        <div className="flex items-start justify-between gap-4">
          <Heading
            title="Profiles"
            description="A profile for each child. Pick who's drawing, then start a Directed Drawing."
          />
          <Button asChild>
            <Link href={newProfile()}>
              <Plus /> New profile
            </Link>
          </Button>
        </div>

        {list.length === 0 ? (
          <Card className="items-center text-center">
            <CardHeader className="w-full">
              <CardTitle>No profiles yet</CardTitle>
              <CardDescription>
                Add a profile for each child so their drawings stay their own.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Button asChild>
                <Link href={newProfile()}>
                  <Plus /> Add your first profile
                </Link>
              </Button>
            </CardContent>
          </Card>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {list.map((child) => (
              <Card key={child.id}>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <ProfileAvatar profile={child} size="sm" /> {child.name}
                    {auth.active_profile?.id === child.id && (
                      <span className="text-primary text-xs font-medium">
                        Drawing now
                      </span>
                    )}
                  </CardTitle>
                  <CardDescription>
                    {ageBandLabel(child.age_band)}
                  </CardDescription>
                  <CardAction className="flex gap-1">
                    <Button variant="ghost" size="icon" asChild>
                      <Link
                        href={editProfile(child.id)}
                        aria-label={`Edit ${child.name}`}
                      >
                        <Pencil />
                      </Link>
                    </Button>
                    <Form
                      action={profiles.destroy(child.id)}
                      options={{ preserveScroll: true }}
                      onBefore={() =>
                        confirm(`Delete ${child.name}'s profile?`)
                      }
                    >
                      <Button
                        type="submit"
                        variant="ghost"
                        size="icon"
                        aria-label={`Delete ${child.name}`}
                      >
                        <Trash2 />
                      </Button>
                    </Form>
                  </CardAction>
                </CardHeader>
              </Card>
            ))}
          </div>
        )}

        <div>
          <Button variant="outline" asChild>
            <Link href={activeProfile()}>Who&apos;s drawing today?</Link>
          </Button>
        </div>
      </div>
    </AppLayout>
  )
}
