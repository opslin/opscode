import { expect, test } from "@playwright/test"
import { readFile } from "node:fs/promises"

const api = process.env.THEME_BUILDER_API_URL ?? "http://127.0.0.1:4500"
const mobileUrl = process.env.THEME_BUILDER_APP_URL ?? "http://127.0.0.1:4502"
const manifestUrl = `${api}/api/v1/theme/tabs/all/sections?store_key=zepto`

test("publishes Bakaloo merchandising sections with a live catalog binding", async ({ page, browser, request }) => {
  const initial = (await (await request.get(manifestUrl)).json()).data
  const tab = initial.sections[0].tab_id
  const created: string[] = []
  const milkId = "22222222-2222-4222-8222-222222222222"
  const title = "Hand-picked dairy"
  await page.goto("/themes/builder")
  await expect(page.getByTestId("add-section-category_product_grid")).toBeVisible()
  const origin = new URL(page.url()).origin
  const headers = { origin }
  const routes = "/api/builder/admin/sections"
  const mobile = await browser.newPage({ viewport: { width: 390, height: 844 } })
  const renderingErrors: string[] = []
  mobile.on("console", message => {
    const text = message.text()
    if (/RenderFlex overflowed|EXCEPTION CAUGHT BY (RENDERING|WIDGETS) LIBRARY/i.test(text)) renderingErrors.push(text)
  })
  mobile.on("pageerror", error => renderingErrors.push(error.message))

  try {
    await mobile.goto(mobileUrl)
    await mobile.locator("flt-semantics-placeholder").dispatchEvent("click")
    await expect(mobile.getByText("Fresh Basket", { exact: true })).toBeVisible()
    const media = await page.request.post("/api/builder/uploads/image", {
      headers,
      multipart: {
        image: {
          name: "market-banner.webp",
          mimeType: "image/webp",
          buffer: await readFile("../flutter-app/assets/commerce/market-hero.webp"),
        },
      },
    })
    expect(media.ok(), await media.text()).toBe(true)
    const imageUrl = (await media.json()).data.url
    let promoShown = false
    mobile.on("response", response => {
      if (response.url() === api + imageUrl && response.ok()) promoShown = true
    })
    const sections = [
      { section_type: "category_product_grid", config: { title, columns: 2 } },
      { section_type: "round_category_icons", config: { icon_size: 48 } },
      { section_type: "arched_product_showcase", config: { title: "Top picks", product_layout: "grid_2col" } },
      { section_type: "seasonal_mosaic", config: { layout_variant: "hero_plus_four" } },
      { section_type: "product_carousel", config: { title: "Market carousel" } },
      { section_type: "trending_products", config: { title: "Trending now" } },
      { section_type: "promo_carousel", config: { banner_source: "custom", images: [imageUrl], auto_scroll: false, aspect_ratio: "16:9" } },
      { section_type: "animated_banner", config: { lottie_url: "assets/commerce/bakaloo-motion.json", height: 100 } },
      { section_type: "bank_offers", config: { visible: false } },
    ]
    for (const section of sections) {
      const result = await page.request.post(`${routes}/${tab}`, {
        headers,
        data: {
          ...section,
          audience: "B2C",
          ...(section.section_type === "category_product_grid" && {
            merch_binding: { source: "manual", product_ids: [milkId], limit: 1 },
          }),
        },
      })
      expect(result.ok(), await result.text()).toBe(true)
      created.push((await result.json()).data.id)
    }
    const featured = mobile.getByRole("group", { name: /Hand-picked dairy.*Fresh Whole Milk/ })
    await expect(featured).toHaveCount(0)
    await page.reload()
    await page.getByTestId("push-live").click()
    const published = page.waitForResponse(response => response.url().endsWith("/publish") && response.request().method() === "POST")
    await page.getByTestId("confirm-push").click()
    expect((await published).ok()).toBe(true)

    await expect(featured).toBeVisible()
    await featured.getByRole("button", { name: "ADD", exact: true }).click()
    await expect(mobile.getByRole("button", { name: "Cart (1)", exact: true })).toBeVisible()

    const manifest = (await (await request.get(manifestUrl)).json()).data
    expect(manifest.sections.map((section: { section_type: string }) => section.section_type)).toEqual(
      expect.arrayContaining(sections.map(section => section.section_type))
    )
    expect(manifest.sections.find((section: { id: string }) => section.id === created[0]).merch_binding.product_ids).toEqual([milkId])

    await mobile.mouse.move(260, 650)
    await expect(async () => {
      await mobile.mouse.wheel(0, 300)
      expect(await mobile.locator("body").ariaSnapshot()).toContain("Trending now")
    }).toPass({ timeout: 8000, intervals: [250, 250, 300, 350, 400] })
    await expect(async () => {
      if (!promoShown) await mobile.mouse.wheel(0, 250)
      expect(promoShown).toBe(true)
    }).toPass({ timeout: 8000, intervals: [200, 250, 300, 350] })
    await mobile.mouse.wheel(0, 2200)
    await expect(async () => {
      expect(await mobile.locator("body").ariaSnapshot()).toContain("Everyday essentials")
    }).toPass({ timeout: 5000 })
    expect(renderingErrors).toEqual([])
  } finally {
    for (const id of created) {
      const result = await page.request.delete(`${routes}/${id}?audience=B2C`, { headers })
      expect(result.ok(), await result.text()).toBe(true)
    }
    if (created.length) {
      const result = await page.request.post(`${routes}/${tab}/publish`, { headers, data: { audience: "B2C" } })
      expect(result.ok(), await result.text()).toBe(true)
    }
    await mobile.close()
  }
})
