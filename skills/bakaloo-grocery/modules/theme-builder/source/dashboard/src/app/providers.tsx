"use client"

import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { useState, type ReactNode } from "react"
import { Toaster } from "sonner"
import { StoreProvider } from "@/contexts/StoreContext"

export default function ThemeBuilderProviders({ children }: { children: ReactNode }) {
  const [client] = useState(() => new QueryClient({
    defaultOptions: { queries: { refetchOnWindowFocus: false, retry: false } },
  }))
  return (
    <QueryClientProvider client={client}>
      <StoreProvider>{children}</StoreProvider>
      <Toaster richColors />
    </QueryClientProvider>
  )
}
