/**
 * Ops Briefing Data Source
 *
 * Fetches invoice summary (7d), contract alerts, and PO status
 * from Supabase. Subsections with no data are omitted.
 *
 * Required env vars: SUPABASE_URL, SUPABASE_ANON_KEY
 */

import { register } from "../registry";
import type { DataSource, DataSourceResult } from "../types";

interface InvoiceRow {
  vendor_display: string;
  invoice_number: string;
  invoice_total: number;
  verdict: string;
  issues: string[];
}

interface ContractRow {
  vendor: string;
  contract_number: string;
  contract_type: string;
  end_date: string;
  status: string;
}

interface PORow {
  vendor: string;
  po_number: string;
  total_amount: number;
  spent_amount: number;
  expiry_date: string;
  created_at: string;
}

function supabaseGet(url: string, key: string, path: string): Promise<Response> {
  return fetch(`${url}/rest/v1/${path}`, {
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
    },
  });
}

const opsBriefingSource: DataSource = {
  id: "ops-briefing",
  name: "Ops Brief",
  emoji: "\u{1F3D7}\uFE0F", // 🏗️

  isAvailable(): boolean {
    return !!(process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY);
  },

  async fetch(): Promise<DataSourceResult> {
    const url = process.env.SUPABASE_URL!;
    const key = process.env.SUPABASE_ANON_KEY!;
    const lines: string[] = [];

    // 7 days ago in ISO
    const sevenDaysAgo = new Date(Date.now() - 7 * 86400000).toISOString();
    const now = new Date();
    const today = now.toISOString().split("T")[0];
    const in30 = new Date(Date.now() + 30 * 86400000).toISOString().split("T")[0];
    const in60 = new Date(Date.now() + 60 * 86400000).toISOString().split("T")[0];
    const in90 = new Date(Date.now() + 90 * 86400000).toISOString().split("T")[0];
    const weekAgo = new Date(Date.now() - 7 * 86400000).toISOString().split("T")[0];

    // Parallel fetches
    const [invoiceRes, contractRes, poRes] = await Promise.all([
      supabaseGet(url, key, `invoice_verifications?created_at=gte.${sevenDaysAgo}&select=vendor_display,invoice_number,invoice_total,verdict,issues&order=created_at.desc`),
      supabaseGet(url, key, `contracts?status=in.(active,expired,pending_renewal)&select=vendor,contract_number,contract_type,end_date,status&order=end_date.asc`),
      supabaseGet(url, key, `purchase_orders?status=eq.open&select=vendor,po_number,total_amount,spent_amount,expiry_date,created_at&order=expiry_date.asc`),
    ]);

    // --- Invoice Summary (7d) ---
    if (invoiceRes.ok) {
      const invoices: InvoiceRow[] = await invoiceRes.json();
      if (invoices.length > 0) {
        const total = invoices.reduce((sum, i) => sum + (Number(i.invoice_total) || 0), 0);
        const byVerdict: Record<string, number> = {};
        for (const inv of invoices) {
          byVerdict[inv.verdict] = (byVerdict[inv.verdict] || 0) + 1;
        }

        const verdictParts: string[] = [];
        if (byVerdict.GOOD_TO_PAY) verdictParts.push(`${byVerdict.GOOD_TO_PAY} Good to Pay`);
        if (byVerdict.REVIEW_REQUIRED) verdictParts.push(`${byVerdict.REVIEW_REQUIRED} Review`);
        if (byVerdict.ISSUES_FOUND) verdictParts.push(`${byVerdict.ISSUES_FOUND} Issues`);

        lines.push(`Invoices (7d): ${invoices.length} processed ($${total.toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 0 })})`);
        if (verdictParts.length > 0) {
          lines.push(`\u2022 ${verdictParts.join(" | ")}`);
        }

        // Flag issues
        const flagged = invoices.filter(
          (i) => i.verdict === "ISSUES_FOUND" || i.verdict === "REVIEW_REQUIRED"
        );
        for (const inv of flagged) {
          const topIssue = inv.issues?.[0] || (inv.verdict === "REVIEW_REQUIRED" ? "review required" : "issues found");
          lines.push(`\u2022 \u26A0\uFE0F ${inv.vendor_display || "Unknown"} #${inv.invoice_number || "?"} \u2014 ${topIssue}`);
        }
      }
    }

    // --- Contract Alerts ---
    if (contractRes.ok) {
      const contracts: ContractRow[] = await contractRes.json();
      const contractLines: string[] = [];

      for (const c of contracts) {
        if (!c.end_date) continue;
        const label = `${c.vendor} ${c.contract_type}-${c.contract_number || "?"}`;

        if (c.status === "expired" || c.end_date < today) {
          contractLines.push(`\u2022 \u{1F534} EXPIRED: ${label} (ended ${c.end_date})`);
        } else if (c.end_date <= in30) {
          contractLines.push(`\u2022 \u{1F7E1} 30d: ${label} expires ${c.end_date}`);
        } else if (c.end_date <= in60) {
          contractLines.push(`\u2022 \u{1F7E0} 60d: ${label} expires ${c.end_date}`);
        } else if (c.end_date <= in90) {
          contractLines.push(`\u2022 \u{1F535} 90d: ${label} expires ${c.end_date}`);
        }
      }

      if (contractLines.length > 0) {
        if (lines.length > 0) lines.push(""); // spacer
        lines.push("Contract Alerts:");
        lines.push(...contractLines);
      }
    }

    // --- PO Status ---
    if (poRes.ok) {
      const pos: PORow[] = await poRes.json();
      const poLines: string[] = [];

      for (const po of pos) {
        const pct = po.total_amount > 0 ? (po.spent_amount / po.total_amount) * 100 : 0;
        const fmtTotal = Number(po.total_amount).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 0 });
        const fmtSpent = Number(po.spent_amount).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 0 });

        if (pct >= 80) {
          poLines.push(`\u2022 \u26A0\uFE0F ${po.po_number} (${po.vendor}) ${Math.round(pct)}% spent ($${fmtSpent}/$${fmtTotal})`);
        }

        if (po.expiry_date && po.expiry_date <= in30 && po.expiry_date >= today) {
          poLines.push(`\u2022 \u23F3 ${po.po_number} (${po.vendor}) expires ${po.expiry_date}`);
        }
      }

      // New POs this week
      const newThisWeek = pos.filter((po) => po.created_at >= weekAgo);
      for (const po of newThisWeek) {
        const fmtTotal = Number(po.total_amount).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 0 });
        poLines.push(`\u2022 \u{1F195} ${po.po_number} (${po.vendor}) opened this week ($${fmtTotal})`);
      }

      if (poLines.length > 0) {
        if (lines.length > 0) lines.push(""); // spacer
        lines.push("PO Status:");
        lines.push(...poLines);
      }
    }

    return {
      lines,
      meta: { source: "supabase" },
    };
  },
};

register(opsBriefingSource);
