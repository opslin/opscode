import type { ReactNode } from "react"
import ThemeBuilderProviders from "./providers"
import "./globals.css"

export const metadata = { title: "Bakaloo Homepage Builder" }

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body><ThemeBuilderProviders>{children}</ThemeBuilderProviders></body>
    </html>
  )
}
