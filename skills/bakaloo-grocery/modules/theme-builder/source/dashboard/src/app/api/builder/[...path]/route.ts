import { NextRequest, NextResponse } from "next/server"
import { backendUrl } from "@/lib/theme-bundle-api"

export const dynamic = "force-dynamic"

const editable = /^admin\/(sections|theme-tabs)(\/[-\w]+)*$/
const available = new Set(["admin/themes/tabs", "categories/admin", "products", "uploads/image"])
const maxBody = 6 * 1024 * 1024

async function proxy(request: NextRequest, context: { params: { path: string[] } }) {
  const host = request.headers.get("host") ?? ""
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
    return NextResponse.json({ message: "Use the local dashboard address" }, { status: 403 })
  }
  const path = context.params.path.join("/")
  if (!available.has(path) && !editable.test(path)) {
    return NextResponse.json({ message: "This action is outside the local theme editor" }, { status: 404 })
  }
  const method = request.method
  const writing = method !== "GET"
  if (writing) {
    const origin = request.headers.get("origin")
    const fetchSite = request.headers.get("sec-fetch-site")
    if (origin !== `http://${host}` || (fetchSite && fetchSite !== "same-origin")) {
      return NextResponse.json({ message: "Open the editor to change a layout" }, { status: 403 })
    }
  }

  const token = process.env.THEME_BUILDER_ADMIN_TOKEN
  if (!token) return NextResponse.json({ message: "Set the local editor token" }, { status: 503 })
  const url = backendUrl(`/api/v1/${path}`)
  url.search = request.nextUrl.search
  const headers = new Headers({ authorization: `Bearer ${token}` })
  const type = request.headers.get("content-type")
  if (type) headers.set("content-type", type)
  if (Number(request.headers.get("content-length")) > maxBody) {
    return NextResponse.json({ message: "Upload is too large" }, { status: 413 })
  }
  const body = writing ? await request.arrayBuffer() : undefined
  if (body && body.byteLength > maxBody) {
    return NextResponse.json({ message: "Upload is too large" }, { status: 413 })
  }
  try {
    const upstream = await fetch(url, {
      method, headers, body: body?.byteLength ? body : undefined, cache: "no-store",
      signal: AbortSignal.timeout(10_000),
    })
    return new Response(upstream.body, {
      status: upstream.status,
      headers: { "content-type": upstream.headers.get("content-type") ?? "application/json" },
    })
  } catch {
    return NextResponse.json({ message: "The local theme API is unavailable" }, { status: 502 })
  }
}

export { proxy as GET, proxy as POST, proxy as PUT, proxy as PATCH, proxy as DELETE }
