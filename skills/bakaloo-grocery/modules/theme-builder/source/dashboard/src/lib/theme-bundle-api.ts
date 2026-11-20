export function backendUrl(path: string) {
  const base = new URL(process.env.THEME_BUILDER_API_URL ?? "http://127.0.0.1:4500")
  if (base.protocol !== "http:" || base.hostname !== "127.0.0.1") {
    throw new Error("THEME_BUILDER_API_URL must use loopback HTTP")
  }
  return new URL(path, base)
}
