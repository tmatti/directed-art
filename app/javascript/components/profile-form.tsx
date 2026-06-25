import { Form } from "@inertiajs/react"
import type { ComponentProps } from "react"

import { Button } from "@/components/ui/button"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Spinner } from "@/components/ui/spinner"
import { AGE_BANDS } from "@/lib/age-bands"
import type { Profile } from "@/types"

interface ProfileFormProps {
  action: ComponentProps<typeof Form>["action"]
  profile?: Profile
  submitLabel: string
}

export default function ProfileForm({
  action,
  profile,
  submitLabel,
}: ProfileFormProps) {
  return (
    <Form
      action={action}
      disableWhileProcessing
      className="flex flex-col gap-6"
    >
      {({ processing, errors }) => (
        <FieldGroup>
          <Field>
            <FieldLabel htmlFor="name">Name</FieldLabel>
            <Input
              id="name"
              name="name"
              type="text"
              required
              autoFocus
              defaultValue={profile?.name}
              placeholder="What's their name?"
            />
            <FieldError errors={errors.name?.map((message) => ({ message }))} />
          </Field>

          <Field>
            <FieldLabel htmlFor="age_band">Age band</FieldLabel>
            <Select name="age_band" defaultValue={profile?.age_band} required>
              <SelectTrigger id="age_band" className="w-full">
                <SelectValue placeholder="Choose an age band" />
              </SelectTrigger>
              <SelectContent>
                {AGE_BANDS.map((band) => (
                  <SelectItem key={band.value} value={band.value}>
                    {band.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <FieldError
              errors={errors.age_band?.map((message) => ({ message }))}
            />
          </Field>

          <Button type="submit" disabled={processing}>
            {processing && <Spinner />}
            {submitLabel}
          </Button>
        </FieldGroup>
      )}
    </Form>
  )
}
