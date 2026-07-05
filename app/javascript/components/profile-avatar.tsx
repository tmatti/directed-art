import { cn } from "@/lib/utils"
import type { Profile } from "@/types"

// Friendly crayon hues, each dark enough that the white initial stays
// readable. A Profile's id picks its hue, so the color is stable everywhere
// the avatar appears and siblings created back-to-back get different colors.
const AVATAR_COLORS = [
  "bg-[oklch(0.65_0.15_35)]", // coral
  "bg-[oklch(0.58_0.11_200)]", // teal
  "bg-[oklch(0.6_0.13_145)]", // leaf green
  "bg-[oklch(0.58_0.13_255)]", // blueberry
  "bg-[oklch(0.6_0.14_300)]", // grape
  "bg-[oklch(0.63_0.15_0)]", // bubblegum
]

const SIZES = {
  sm: "size-7 text-sm",
  lg: "size-20 text-4xl",
}

export default function ProfileAvatar({
  profile,
  size = "lg",
  className,
}: {
  profile: Pick<Profile, "id" | "name">
  size?: keyof typeof SIZES
  className?: string
}) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        "font-display flex shrink-0 items-center justify-center rounded-full font-semibold text-white",
        AVATAR_COLORS[profile.id % AVATAR_COLORS.length],
        SIZES[size],
        className,
      )}
    >
      {profile.name.trim().charAt(0).toUpperCase()}
    </span>
  )
}
