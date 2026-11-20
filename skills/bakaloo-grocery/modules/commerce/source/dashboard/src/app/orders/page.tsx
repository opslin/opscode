"use client"

import Link from "next/link"
import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { PageHeader } from "@/components/shared/PageHeader"
import { BillSummary } from "@/components/orders/BillSummary"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import api from "@/lib/api"
import { formatDateTime, formatINR } from "@/lib/utils"
import type { OrderBill } from "@/types/order.types"

type Order = {
  id: string; orderNumber: string; customer: string; status: string; subtotal: number; totalAmount: number;
  deliveryFee: number; createdAt: string;
  items: { productId: string; name: string; quantity: number; total: number }[];
}

export default function OrdersPage() {
  const [selected, setSelected] = useState<Order | null>(null)
  const orders = useQuery({
    queryKey: ["bundle-orders"],
    queryFn: async () => (await api.get<{ data: Order[] }>("/admin/commerce/orders")).data.data,
    refetchInterval: 2000,
  })
  const bill: OrderBill | null = selected && {
    lines: [
      { code: "ITEMS", label: "Items subtotal", amount: selected.subtotal, kind: "items" },
      { code: "DELIVERY", label: "Delivery fee", amount: selected.deliveryFee, kind: "charge" },
    ],
    itemCount: selected.items.reduce((sum, item) => sum + item.quantity, 0),
    grandTotal: selected.totalAmount,
    savings: { total: 0, parts: [] },
    cashback: [],
    buyerGstin: null,
    reconciled: true,
    payment: {
      method: "COD", methodLabel: "Cash on delivery", status: "PENDING",
      walletUsed: 0, gatewayAmount: 0, refundAmount: 0,
      parts: [{ code: "COD", label: "Cash", amount: selected.totalAmount, state: "DUE" }],
      collectOnDelivery: selected.totalAmount,
    },
  }

  return (
    <main className="mx-auto max-w-6xl space-y-6 px-5 py-7">
      <PageHeader title="Orders" subtitle="Demo orders placed from the connected Flutter storefront.">
        <Button variant="outline" asChild><Link href="/catalog">View catalog</Link></Button>
      </PageHeader>
      <div className="rounded-xl border bg-card">
        <Table>
          <TableHeader><TableRow>
            <TableHead>Order ID</TableHead><TableHead>Customer</TableHead><TableHead>Items</TableHead>
            <TableHead className="text-right">Amount</TableHead><TableHead>Payment</TableHead><TableHead>Status</TableHead><TableHead>Date</TableHead>
          </TableRow></TableHeader>
          <TableBody>
            {orders.isPending && <TableRow><TableCell colSpan={7}>Loading orders…</TableCell></TableRow>}
            {orders.error && <TableRow><TableCell colSpan={7}>{orders.error.message}</TableCell></TableRow>}
            {orders.data?.length === 0 && <TableRow><TableCell colSpan={7}>No demo orders yet.</TableCell></TableRow>}
            {orders.data?.map(order => (
              <TableRow key={order.id}>
                <TableCell><Button variant="link" className="h-auto p-0 font-semibold" onClick={() => setSelected(order)}>{order.orderNumber}</Button></TableCell>
                <TableCell>{order.customer}</TableCell>
                <TableCell>{order.items.map(item => `${item.name} × ${item.quantity}`).join(", ")}</TableCell>
                <TableCell className="text-right font-semibold">{formatINR(order.totalAmount)}</TableCell>
                <TableCell>Cash on delivery</TableCell><TableCell><Badge variant="secondary">{order.status}</Badge></TableCell>
                <TableCell>{formatDateTime(order.createdAt)}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
      <Dialog open={!!selected} onOpenChange={open => !open && setSelected(null)}>
        {selected && bill && <DialogContent>
          <DialogHeader><DialogTitle>{selected.orderNumber}</DialogTitle><DialogDescription>{selected.customer}</DialogDescription></DialogHeader>
          <ul className="divide-y rounded-md border px-3">
            {selected.items.map(item => <li className="flex justify-between py-2 text-sm" key={item.productId}>
              <span>{item.name} × {item.quantity}</span><span>{formatINR(item.total)}</span>
            </li>)}
          </ul>
          <BillSummary bill={bill} />
        </DialogContent>}
      </Dialog>
    </main>
  )
}
