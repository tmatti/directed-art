import { Head } from "@inertiajs/react"

import Heading from "@/components/heading"
import ProfileForm from "@/components/profile-form"
import AppLayout from "@/layouts/app-layout"
import profiles from "@/routes/ProfilesController"
import type { BreadcrumbItem, Profile } from "@/types"

export default function Edit({ profile }: { profile: Profile }) {
  const breadcrumbs: BreadcrumbItem[] = [
    { title: "Profiles", href: profiles.index().url },
    { title: profile.name, href: profiles.edit(profile.id).url },
  ]

  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title={`Edit ${profile.name}`} />

      <div className="flex h-full flex-1 flex-col gap-6 p-4 md:max-w-lg">
        <Heading
          title={`Edit ${profile.name}`}
          description="Update this child's name or age band."
        />
        <ProfileForm
          action={profiles.update(profile.id)}
          profile={profile}
          submitLabel="Save changes"
        />
      </div>
    </AppLayout>
  )
}
