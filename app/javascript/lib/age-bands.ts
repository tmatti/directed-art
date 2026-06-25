import type { AgeBand } from "@/types"

// Mirrors Profile::AGE_BANDS on the server. The label is what an adult sees;
// the value is the enum key Rails expects.
export const AGE_BANDS: { value: AgeBand; label: string }[] = [
  { value: "ages_4_6", label: "Ages 4–6" },
  { value: "ages_7_10", label: "Ages 7–10" },
]

export function ageBandLabel(value: AgeBand): string {
  return AGE_BANDS.find((band) => band.value === value)?.label ?? value
}
