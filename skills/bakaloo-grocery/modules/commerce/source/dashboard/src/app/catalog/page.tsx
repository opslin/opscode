"use client"

import { useState, type FormEvent } from "react"
import Link from "next/link"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { PageHeader } from "@/components/shared/PageHeader"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import api from "@/lib/api"
import { formatINR } from "@/lib/utils"
import { uploadImage } from "@/services/uploads.service"

const categories = ["produce", "dairy", "pantry", "snacks"]
type Product = { id: string; name: string; unit: string; price: number; stock_quantity: number; category: string }

export default function CatalogPage() {
  const client = useQueryClient()
  const products = useQuery({
    queryKey: ["bundle-catalog"],
    queryFn: async () => (await api.get<{ data: Product[] }>("/admin/commerce/products")).data.data,
    refetchInterval: 3000,
  })
  const [notice, setNotice] = useState("")
  const create = useMutation({
    mutationFn: async (form: FormData) => {
      const image = form.get("photo")
      const uploaded = image instanceof File && image.size ? await uploadImage(image) : null
      const result = await api.post("/admin/commerce/products", {
        name: form.get("name"), price: Number(form.get("price")), unit: form.get("unit"),
        stock: Number(form.get("stock")), category: form.get("category"), image: uploaded?.url,
      })
      return result.data.data
    },
    onSuccess: async () => {
      setNotice("Product added")
      await client.invalidateQueries({ queryKey: ["bundle-catalog"] })
    },
  })

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const target = event.currentTarget
    setNotice("")
    try {
      await create.mutateAsync(new FormData(target))
      target.reset()
    } catch {
      // The mutation error is rendered beside the form.
    }
  }

  return (
    <main className="mx-auto max-w-6xl space-y-6 px-5 py-7">
      <PageHeader title="Catalog" subtitle="Products and stock for the local storefront.">
        <Button variant="outline" asChild><Link href="/orders">View orders</Link></Button>
      </PageHeader>
      <div className="grid items-start gap-6 lg:grid-cols-[20rem_1fr]">
        <form onSubmit={submit} className="space-y-4 rounded-xl border bg-card p-5">
          <h2 className="font-semibold">New product</h2>
          <div className="space-y-1.5"><Label htmlFor="name">Product name</Label><Input id="name" name="name" required maxLength={100} /></div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5"><Label htmlFor="price">Price (₹)</Label><Input id="price" name="price" inputMode="decimal" type="number" required step=".01" min=".01" max="100000" /></div>
            <div className="space-y-1.5"><Label htmlFor="stock">Stock</Label><Input id="stock" name="stock" type="number" min="0" max="100000" step="1" required /></div>
          </div>
          <div className="space-y-1.5"><Label htmlFor="unit">Unit</Label><Input id="unit" name="unit" placeholder="250 g" required maxLength={20} /></div>
          <div className="space-y-1.5"><Label htmlFor="category">Category</Label>
            <select id="category" name="category" className="h-10 w-full rounded-md border bg-background px-3 capitalize">
              {categories.map(category => <option key={category} value={category}>{category}</option>)}
            </select>
          </div>
          <div className="space-y-1.5"><Label htmlFor="photo">Product photo</Label><Input id="photo" name="photo" type="file" accept="image/png,image/jpeg,image/webp" /></div>
          <Button type="submit" disabled={create.isPending}>{create.isPending ? "Adding…" : "Add product"}</Button>
          {notice && <p role="status" className="text-sm text-brand-700">{notice}</p>}
          {create.error && <p role="alert" className="text-sm text-destructive">{create.error.message}</p>}
        </form>
        <div className="rounded-xl border bg-card">
          <Table>
            <TableHeader><TableRow><TableHead>Product</TableHead><TableHead>Category</TableHead><TableHead>Price</TableHead><TableHead>Stock</TableHead></TableRow></TableHeader>
            <TableBody>
              {products.isPending && <TableRow><TableCell colSpan={4}>Loading products…</TableCell></TableRow>}
              {products.error && <TableRow><TableCell colSpan={4}>{products.error.message}</TableCell></TableRow>}
              {products.data?.map(item => <TableRow key={item.id}>
                <TableCell className="font-medium">{item.name}<span className="ml-2 text-xs text-muted-foreground">{item.unit}</span></TableCell>
                <TableCell className="capitalize">{item.category}</TableCell>
                <TableCell>{formatINR(item.price)}</TableCell><TableCell>{item.stock_quantity}</TableCell>
              </TableRow>)}
            </TableBody>
          </Table>
        </div>
      </div>
    </main>
  )
}
