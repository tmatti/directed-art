import type { SVGAttributes } from "react"

export default function AppLogoIcon(props: SVGAttributes<SVGElement>) {
  return (
    <svg
      height="24"
      viewBox="0 0 24 24"
      width="24"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <path
        fill="currentColor"
        d="M12 20 L8.5 14 L8.5 7 Q8.5 6 9.5 6 L14.5 6 Q15.5 6 15.5 7 L15.5 14 Z"
      />
    </svg>
  )
}
