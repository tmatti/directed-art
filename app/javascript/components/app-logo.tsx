import AppLogoIcon from "./app-logo-icon"

export default function AppLogo() {
  return (
    <>
      <div className="bg-primary text-primary-foreground flex aspect-square size-8 items-center justify-center rounded-lg">
        <AppLogoIcon className="size-5 fill-current text-white" />
      </div>
      <div className="ml-1 grid flex-1 text-left text-sm">
        <span className="font-display mb-0.5 truncate leading-tight font-semibold">
          {import.meta.env.VITE_APP_NAME ?? "Directed Art"}
        </span>
      </div>
    </>
  )
}
