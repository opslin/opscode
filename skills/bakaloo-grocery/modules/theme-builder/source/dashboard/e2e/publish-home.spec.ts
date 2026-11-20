import { test, expect, type Page } from "@playwright/test"
import { resolve } from "node:path"

const api = process.env.THEME_BUILDER_API_URL ?? "http://127.0.0.1:4500"
const mobileUrl = process.env.THEME_BUILDER_APP_URL ?? "http://127.0.0.1:4502"
const manifestUrl = `${api}/api/v1/theme/tabs/all/sections?store_key=zepto`

async function publish(editor: Page) {
  await editor.getByTestId("push-live").click()
  const response = editor.waitForResponse(result =>
    result.url().endsWith("/publish") && result.request().method() === "POST"
  )
  await editor.getByTestId("confirm-push").click()
  const published = await response
  expect(published.ok(), await published.text()).toBe(true)
  await expect(editor.getByText("Homepage published", { exact: true }).last()).toBeVisible()
}

test("publishes a saved homepage draft to the running Flutter app", async ({ page, browser, request }, testInfo) => {
  const initial = await request.get(manifestUrl)
  expect(initial.ok()).toBe(true)
  const original = (await initial.json()).data
  expect(original.revision).toBeGreaterThan(0)
  const originalHeader = original.sections.find((section: { section_type: string }) =>
    section.section_type === "text_header"
  )
  expect(originalHeader).toBeDefined()

  const denied = await request.post(`${api}/api/v1/admin/sections/${originalHeader.tab_id}/publish`, {
    data: { audience: "B2C" },
  })
  expect(denied.status()).toBe(401)

  const mobile = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 })
  await mobile.goto(mobileUrl)
  await mobile.locator("flt-semantics-placeholder").dispatchEvent("click")
  await expect(mobile.getByText(originalHeader.config.text)).toBeVisible()

  await page.goto("/themes/builder")
  await page.getByRole("button", { name: /Text Header\. Position 1/ }).click()
  const newTitle = `FreshBasket picks ${Date.now().toString().slice(-6)}`
  await page.getByLabel("Text", { exact: true }).fill(newTitle)
  const savedDraft = page.waitForResponse(result => result.request().method() === "PUT"
    && /\/admin\/sections\/[0-9a-f-]+$/.test(result.url()))
  await page.getByTestId("save-draft").click()
  expect((await savedDraft).ok()).toBe(true)
  await expect(page.getByTestId("save-draft")).toBeEnabled()
  expect((await (await request.get(manifestUrl)).json()).data).toEqual(original)
  await expect(mobile.getByText(newTitle)).toHaveCount(0)

  await publish(page)
  const updated = (await (await request.get(manifestUrl)).json()).data
  expect(updated.revision).toBe(original.revision + 1)
  expect(updated.sections[0].config.text).toBe(newTitle)
  // This is the open Flutter page's live semantics tree. No page reload.
  await expect(mobile.getByText(newTitle)).toBeVisible()
  await expect(mobile.getByText(originalHeader.config.text)).toHaveCount(0)

  await page.getByRole("button", { name: "Back to library" }).click()
  await page.getByTestId("add-section-custom_banner").click()
  const uploaded = page.waitForResponse(result =>
    result.url().includes("/uploads/image") && result.request().method() === "POST"
  )
  await page.locator('#right-panel-editor input[type="file"]').setInputFiles(
    resolve("public/preview-assets/everyday_essentials.png")
  )
  const uploadResponse = await uploaded
  expect(uploadResponse.ok()).toBe(true)
  const imageUrl = (await uploadResponse.json()).data.url
  const shown = mobile.waitForResponse(result => result.url() === api + imageUrl)
  await publish(page)
  const image = await shown
  expect(image.ok()).toBe(true)
  expect(image.headers()["content-type"]).toBe("image/png")
  await expect(mobile.getByText(newTitle)).toBeVisible()

  await page.screenshot({ path: testInfo.outputPath("dashboard-published.png") })
  await mobile.screenshot({ path: testInfo.outputPath("flutter-published.png") })
  await mobile.close()
})
