import { backendUrl } from "@/lib/theme-bundle-api"

export async function GET(_: Request, { params }: { params: { id: string } }) {
  if (!/^[a-f0-9]{64}$/.test(params.id)) return new Response(null, { status: 404 })
  const media = await fetch(backendUrl(`/api/v1/theme/media/${params.id}`), { cache: "no-store" })
  return new Response(media.body, {
    status: media.status,
    headers: {
      "content-type": media.headers.get("content-type") ?? "application/octet-stream",
      "cache-control": media.headers.get("cache-control") ?? "no-cache",
      "x-content-type-options": "nosniff",
    },
  })
}
