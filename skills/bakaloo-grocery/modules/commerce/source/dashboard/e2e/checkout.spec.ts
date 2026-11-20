import { expect, test } from "@playwright/test"
import { resolve } from "node:path"

const api = process.env.THEME_BUILDER_API_URL ?? "http://127.0.0.1:4500"
const mobileUrl = process.env.THEME_BUILDER_APP_URL ?? "http://127.0.0.1:4502"

test("adds a catalog product and places a demo order in Flutter", async ({ page, browser, request }, testInfo) => {
  const name = `Market Tomatoes ${Date.now().toString().slice(-6)}`
  await page.goto("/catalog")
  await page.getByLabel("Product name", { exact: true }).fill(name)
  await page.getByLabel("Price (₹)", { exact: true }).fill("80")
  await page.getByLabel("Stock", { exact: true }).fill("3")
  await page.getByLabel("Unit", { exact: true }).fill("500 g")
  await page.getByLabel("Product photo", { exact: true }).setInputFiles(
    resolve("../flutter-app/assets/commerce/tomato.webp")
  )
  const saved = page.waitForResponse(result => result.url().endsWith("/admin/commerce/products") && result.request().method() === "POST")
  await page.getByRole("button", { name: "Add product" }).click()
  const added = await saved
  expect(added.ok(), await added.text()).toBe(true)
  const productId = (await added.json()).data.id
  await expect(page.getByRole("row").filter({ hasText: name })).toBeVisible()

  const mobile = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 })
  await mobile.goto(mobileUrl)
  await mobile.locator("flt-semantics-placeholder").dispatchEvent("click")
  await expect(mobile.getByText("Fresh Basket", { exact: true })).toBeVisible()
  await expect(mobile.getByRole("group", { name: /Vine Tomatoes/ })).toBeVisible()
  await mobile.screenshot({ path: testInfo.outputPath("fresh-basket-home.png") })
  await mobile.getByRole("button", { name: "Open cart", exact: true }).click()
  await expect(mobile.getByText("Your cart is empty", { exact: true })).toBeVisible()
  await mobile.getByRole("button", { name: "Start shopping", exact: true }).click()
  await mobile.getByRole("button", { name: "Browse", exact: true }).click()
  await expect(mobile.getByRole("button", { name: "Open cart", exact: true })).toBeInViewport({ ratio: 1 })
  const categoriesTitle = mobile.getByText("Categories", { exact: true })
  await expect(categoriesTitle).toBeVisible()
  await expect.poll(async () => (await categoriesTitle.boundingBox())?.x ?? 390).toBeLessThan(20)
  const product = mobile.getByRole("group", { name: new RegExp(name) })
  await expect(product).toBeVisible()
  await mobile.screenshot({ path: testInfo.outputPath("fresh-basket-categories.png") })
  await product.getByRole("button", { name: `Add ${name}`, exact: true }).click()
  const quote = mobile.waitForResponse(response => response.url().endsWith("/api/v1/checkout/quote")
    && response.request().method() === "POST")
  await mobile.getByRole("button", { name: "Open cart (1)", exact: true }).click()
  await expect(mobile.getByText("My Cart (1)", { exact: true })).toBeVisible()
  expect((await (await quote).json()).data.bill.totalPayable).toBe(105)
  const cashOnDelivery = mobile.getByRole("button", { name: "Cash on Delivery", exact: true })
  await expect(cashOnDelivery).toBeEnabled()
  await mobile.screenshot({ path: testInfo.outputPath("fresh-basket-cart.png") })
  await cashOnDelivery.click()
  await expect(mobile.getByText("Checkout", { exact: true })).toBeVisible()
  await expect(mobile.getByText(/₹105/).first()).toBeVisible()
  const placed = mobile.waitForResponse(result => result.url().endsWith("/api/v1/checkout/orders") && result.request().method() === "POST")
  await mobile.getByRole("button", { name: "Place demo order" }).click()
  const result = await placed
  expect(result.ok(), await result.text()).toBe(true)
  const { data: order } = await result.json()
  await expect(mobile.getByText("Demo order placed", { exact: true })).toBeVisible()
  await expect(mobile.getByText(order.orderNumber, { exact: true })).toBeVisible()
  await mobile.screenshot({ path: testInfo.outputPath("demo-order-confirmation.png") })

  // A retried request must return the same order and decrement stock only once.
  const replay = await request.post(`${api}/api/v1/checkout/orders`, { data: result.request().postDataJSON() })
  expect(replay.status()).toBe(200)
  expect((await replay.json()).data.id).toBe(order.id)
  const after = (await (await request.get(`${api}/api/v1/catalog`)).json()).data
  expect(after.find((product: { id: string }) => product.id === productId).stockQuantity).toBe(2)

  await page.goto("/orders")
  const row = page.getByRole("row").filter({ hasText: order.orderNumber })
  await expect(row).toHaveCount(1)
  await expect(row).toContainText(name)
  await expect(row).toContainText("₹105")
  await row.getByRole("button", { name: order.orderNumber }).click()
  await expect(page.getByText("Grand total", { exact: true })).toBeVisible()
  await page.screenshot({ path: testInfo.outputPath("dashboard-order.png") })
  await mobile.close()
})
