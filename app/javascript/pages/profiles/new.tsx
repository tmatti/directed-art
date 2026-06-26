import { Head } from "@inertiajs/react"

import Heading from "@/components/heading"
import ProfileForm from "@/components/profile-form"
import AppLayout from "@/layouts/app-layout"
import profiles from "@/routes/ProfilesController"
import type { BreadcrumbItem } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  { title: "Profiles", href: profiles.index().url },
  { title: "New profile", href: profiles.new().url },
]

export default function New() {
  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title="New profile" />

      <div className="flex h-full flex-1 flex-col gap-6 p-4 md:max-w-lg">
        <Heading
          title="New profile"
          description="Add a child and pick their age band."
        />
        <ProfileForm action={profiles.create()} submitLabel="Create profile" />
      </div>
    </AppLayout>
  )
}
