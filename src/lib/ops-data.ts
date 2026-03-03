/**
 * Ops Data — CRUD helpers for contracts and purchase orders.
 *
 * Used by bot.ts chat commands for quick data entry via Telegram.
 * All calls go through Supabase REST API (same pattern as memory.ts).
 */

const supabaseUrl = () => process.env.SUPABASE_URL || "";
const supabaseKey = () => process.env.SUPABASE_ANON_KEY || "";

function headers() {
  const key = supabaseKey();
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json",
    Prefer: "return=representation",
  };
}

// ── Contracts ──────────────────────────────────────────────

export async function addContract(
  vendor: string,
  type: string,
  description: string,
  endDate: string
): Promise<{ success: boolean; contractNumber?: string }> {
  const contractType = normalizeContractType(type);
  const contractNumber = generateContractNumber(vendor, contractType);

  const res = await fetch(`${supabaseUrl()}/rest/v1/contracts`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      vendor,
      contract_number: contractNumber,
      contract_type: contractType,
      description,
      end_date: endDate,
      start_date: new Date().toISOString().split("T")[0],
      status: "active",
    }),
  });

  if (!res.ok) return { success: false };
  return { success: true, contractNumber };
}

export async function listContracts(vendor?: string): Promise<string> {
  let path = `contracts?status=in.(active,pending_renewal)&select=vendor,contract_number,contract_type,description,end_date,status&order=end_date.asc`;
  if (vendor) {
    path += `&vendor=ilike.*${encodeURIComponent(vendor)}*`;
  }

  const res = await fetch(`${supabaseUrl()}/rest/v1/${path}`, {
    headers: {
      apikey: supabaseKey(),
      Authorization: `Bearer ${supabaseKey()}`,
    },
  });

  if (!res.ok) return "Failed to fetch contracts.";
  const rows: any[] = await res.json();
  if (rows.length === 0) return vendor ? `No active contracts for "${vendor}".` : "No active contracts.";

  return rows
    .map((c) => {
      const type = c.contract_type?.toUpperCase() || "?";
      const num = c.contract_number || "?";
      const desc = c.description ? ` — ${c.description}` : "";
      const expires = c.end_date ? ` (exp ${c.end_date})` : "";
      return `\u2022 ${c.vendor} ${type}-${num}${desc}${expires}`;
    })
    .join("\n");
}

// ── Purchase Orders ────────────────────────────────────────

export async function addPurchaseOrder(
  vendor: string,
  poNumber: string,
  totalAmount: number,
  expiryDate: string
): Promise<boolean> {
  const res = await fetch(`${supabaseUrl()}/rest/v1/purchase_orders`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      vendor,
      po_number: poNumber,
      total_amount: totalAmount,
      expiry_date: expiryDate,
      status: "open",
    }),
  });

  return res.ok;
}

export async function updatePOSpend(
  poNumber: string,
  additionalSpend: number
): Promise<{ success: boolean; newSpent?: number; total?: number }> {
  // Fetch current PO
  const getRes = await fetch(
    `${supabaseUrl()}/rest/v1/purchase_orders?po_number=eq.${encodeURIComponent(poNumber)}&status=eq.open&select=id,spent_amount,total_amount&limit=1`,
    {
      headers: {
        apikey: supabaseKey(),
        Authorization: `Bearer ${supabaseKey()}`,
      },
    }
  );

  if (!getRes.ok) return { success: false };
  const rows: any[] = await getRes.json();
  if (rows.length === 0) return { success: false };

  const po = rows[0];
  const newSpent = Number(po.spent_amount || 0) + additionalSpend;
  const newStatus = newSpent >= Number(po.total_amount) ? "exhausted" : "open";

  const updateRes = await fetch(
    `${supabaseUrl()}/rest/v1/purchase_orders?id=eq.${po.id}`,
    {
      method: "PATCH",
      headers: headers(),
      body: JSON.stringify({
        spent_amount: newSpent,
        status: newStatus,
        updated_at: new Date().toISOString(),
      }),
    }
  );

  if (!updateRes.ok) return { success: false };
  return { success: true, newSpent, total: Number(po.total_amount) };
}

export async function listPurchaseOrders(vendor?: string): Promise<string> {
  let path = `purchase_orders?status=eq.open&select=vendor,po_number,description,total_amount,spent_amount,expiry_date&order=expiry_date.asc`;
  if (vendor) {
    path += `&vendor=ilike.*${encodeURIComponent(vendor)}*`;
  }

  const res = await fetch(`${supabaseUrl()}/rest/v1/${path}`, {
    headers: {
      apikey: supabaseKey(),
      Authorization: `Bearer ${supabaseKey()}`,
    },
  });

  if (!res.ok) return "Failed to fetch POs.";
  const rows: any[] = await res.json();
  if (rows.length === 0) return vendor ? `No open POs for "${vendor}".` : "No open POs.";

  return rows
    .map((po) => {
      const total = Number(po.total_amount).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 0 });
      const spent = Number(po.spent_amount || 0).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 0 });
      const pct = po.total_amount > 0 ? Math.round((po.spent_amount / po.total_amount) * 100) : 0;
      const desc = po.description ? ` — ${po.description}` : "";
      const expires = po.expiry_date ? ` (exp ${po.expiry_date})` : "";
      return `\u2022 ${po.po_number} (${po.vendor}) $${spent}/$${total} (${pct}%)${desc}${expires}`;
    })
    .join("\n");
}

// ── Vendor Master ──────────────────────────────────────────

export async function addVendor(
  name: string,
  displayName: string,
  opts?: { vendorCode?: string; contactEmail?: string; contactPhone?: string; paymentTerms?: number }
): Promise<boolean> {
  const res = await fetch(`${supabaseUrl()}/rest/v1/vendor_master`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      name: name.toLowerCase(),
      display_name: displayName,
      vendor_code: opts?.vendorCode,
      contact_email: opts?.contactEmail,
      contact_phone: opts?.contactPhone,
      payment_terms_days: opts?.paymentTerms || 30,
      status: "active",
    }),
  });
  return res.ok;
}

export async function getVendorSummary(vendorSearch: string): Promise<string> {
  const url = supabaseUrl();
  const key = supabaseKey();
  const authHeaders = { apikey: key, Authorization: `Bearer ${key}` };
  const encoded = encodeURIComponent(vendorSearch);

  // Parallel: contracts, POs, recent invoices (30d)
  const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString();

  const [contractRes, poRes, invoiceRes] = await Promise.all([
    fetch(`${url}/rest/v1/contracts?vendor=ilike.*${encoded}*&status=in.(active,pending_renewal)&select=contract_number,contract_type,end_date,status&order=end_date.asc`, { headers: authHeaders }),
    fetch(`${url}/rest/v1/purchase_orders?vendor=ilike.*${encoded}*&status=eq.open&select=po_number,total_amount,spent_amount,expiry_date&order=expiry_date.asc`, { headers: authHeaders }),
    fetch(`${url}/rest/v1/invoice_verifications?vendor=ilike.*${encoded}*&created_at=gte.${thirtyDaysAgo}&select=invoice_number,invoice_total,verdict,created_at&order=created_at.desc&limit=10`, { headers: authHeaders }),
  ]);

  const lines: string[] = [];

  // Contracts
  if (contractRes.ok) {
    const contracts: any[] = await contractRes.json();
    if (contracts.length > 0) {
      lines.push(`**Contracts (${contracts.length} active):**`);
      for (const c of contracts) {
        const exp = c.end_date ? ` exp ${c.end_date}` : "";
        lines.push(`  \u2022 ${c.contract_type}-${c.contract_number || "?"}${exp}`);
      }
    } else {
      lines.push("**Contracts:** None active");
    }
  }

  // POs
  if (poRes.ok) {
    const pos: any[] = await poRes.json();
    if (pos.length > 0) {
      const totalPO = pos.reduce((s, p) => s + Number(p.total_amount), 0);
      const totalSpent = pos.reduce((s, p) => s + Number(p.spent_amount || 0), 0);
      const fmtPO = totalPO.toLocaleString("en-US", { maximumFractionDigits: 0 });
      const fmtSpent = totalSpent.toLocaleString("en-US", { maximumFractionDigits: 0 });
      const pct = totalPO > 0 ? Math.round((totalSpent / totalPO) * 100) : 0;
      lines.push(`**POs (${pos.length} open):** $${fmtSpent}/$${fmtPO} (${pct}% utilized)`);
      for (const po of pos) {
        const spent = Number(po.spent_amount || 0);
        const total = Number(po.total_amount);
        const p = total > 0 ? Math.round((spent / total) * 100) : 0;
        lines.push(`  \u2022 ${po.po_number} ${p}% ($${spent.toLocaleString("en-US", { maximumFractionDigits: 0 })}/$${total.toLocaleString("en-US", { maximumFractionDigits: 0 })})`);
      }
    } else {
      lines.push("**POs:** None open");
    }
  }

  // Invoices (30d)
  if (invoiceRes.ok) {
    const invoices: any[] = await invoiceRes.json();
    if (invoices.length > 0) {
      const totalInv = invoices.reduce((s, i) => s + (Number(i.invoice_total) || 0), 0);
      const byVerdict: Record<string, number> = {};
      for (const inv of invoices) {
        byVerdict[inv.verdict] = (byVerdict[inv.verdict] || 0) + 1;
      }
      const verdictStr = Object.entries(byVerdict).map(([k, v]) => `${v} ${k.replace(/_/g, " ").toLowerCase()}`).join(", ");
      lines.push(`**Invoices (30d):** ${invoices.length} totaling $${totalInv.toLocaleString("en-US", { maximumFractionDigits: 0 })} (${verdictStr})`);
      const flagged = invoices.filter(i => i.verdict !== "GOOD_TO_PAY");
      for (const inv of flagged) {
        lines.push(`  \u26A0\uFE0F #${inv.invoice_number || "?"} $${Number(inv.invoice_total || 0).toLocaleString("en-US", { maximumFractionDigits: 0 })} — ${inv.verdict.replace(/_/g, " ").toLowerCase()}`);
      }
    } else {
      lines.push("**Invoices (30d):** None");
    }
  }

  if (lines.length === 0) return `No data found for "${vendorSearch}".`;
  return lines.join("\n");
}

export async function listVendors(): Promise<string> {
  const res = await fetch(
    `${supabaseUrl()}/rest/v1/vendor_master?status=eq.active&select=display_name,vendor_code,payment_terms_days&order=display_name.asc`,
    { headers: { apikey: supabaseKey(), Authorization: `Bearer ${supabaseKey()}` } }
  );

  if (!res.ok) return "Failed to fetch vendors.";
  const rows: any[] = await res.json();
  if (rows.length === 0) return "No vendors registered. Use `vendor: Name | Display Name` to add one.";

  return rows
    .map((v) => {
      const code = v.vendor_code ? ` (${v.vendor_code})` : "";
      const terms = v.payment_terms_days ? ` — Net ${v.payment_terms_days}` : "";
      return `\u2022 ${v.display_name}${code}${terms}`;
    })
    .join("\n");
}

// ── Helpers ────────────────────────────────────────────────

function normalizeContractType(input: string): string {
  const lower = input.toLowerCase().trim();
  if (lower === "msa" || lower === "master") return "MSA";
  if (lower === "sow" || lower === "scope") return "SOW";
  if (lower === "amendment" || lower === "amend") return "amendment";
  if (lower.includes("service")) return "service_agreement";
  return "other";
}

function generateContractNumber(vendor: string, type: string): string {
  const prefix = vendor.substring(0, 3).toUpperCase();
  const year = new Date().getFullYear();
  const seq = String(Math.floor(Math.random() * 900) + 100);
  return `${type.toUpperCase()}-${year}-${prefix}-${seq}`;
}
