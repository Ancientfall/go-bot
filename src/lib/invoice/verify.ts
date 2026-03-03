/**
 * Invoice Processor — Verification Logic
 *
 * Math checks (qty × rate = extended, $0.02 tolerance),
 * rate variance flagging (>5%), asset/PO classification,
 * and overall verdict determination.
 */

import type {
  InvoiceLineItem,
  RateMatch,
  MathCheck,
  Verdict,
} from "./types";

const MATH_TOLERANCE = 0.02; // $0.02
const RATE_VARIANCE_THRESHOLD = 0.05; // 5%

// ---------------------------------------------------------------------------
// Math Verification
// ---------------------------------------------------------------------------

/**
 * Verify qty × unitRate = extended for each line item.
 * Tolerance: $0.02 to account for rounding.
 */
export function verifyMath(lineItems: InvoiceLineItem[]): MathCheck[] {
  return lineItems.map((item) => {
    const expected = roundTo2(item.quantity * item.unitRate);
    const actual = item.extended;
    const difference = roundTo2(actual - expected);

    return {
      lineNumber: item.lineNumber,
      expected,
      actual,
      difference,
      ok: Math.abs(difference) <= MATH_TOLERANCE,
    };
  });
}

// ---------------------------------------------------------------------------
// Issue Collection
// ---------------------------------------------------------------------------

/**
 * Collect all issues found during verification.
 */
export function collectIssues(
  rateMatches: RateMatch[],
  mathChecks: MathCheck[],
  invoiceTotal?: number,
  lineItems?: InvoiceLineItem[]
): string[] {
  const issues: string[] = [];

  // Math errors
  for (const check of mathChecks) {
    if (!check.ok) {
      issues.push(
        `Line ${check.lineNumber}: math error — expected $${check.expected.toFixed(2)}, ` +
        `invoiced $${check.actual.toFixed(2)} (diff: $${check.difference.toFixed(2)})`
      );
    }
  }

  // Rate variances
  for (const match of rateMatches) {
    if (match.contractRate && !match.rateOk) {
      const pct = (match.rateVariance * 100).toFixed(1);
      const dir = match.rateVariance > 0 ? "above" : "below";
      issues.push(
        `Line ${match.lineItem.lineNumber}: rate ${dir} contract by ${Math.abs(parseFloat(pct))}% — ` +
        `invoiced $${match.lineItem.unitRate.toFixed(2)} vs contract $${match.contractRate.rate.toFixed(2)} ` +
        `("${match.lineItem.description.substring(0, 40)}")`
      );
    }
  }

  // Unmatched line items (no contract rate found)
  const unmatched = rateMatches.filter((m) => m.tier === "none");
  if (unmatched.length > 0) {
    issues.push(
      `${unmatched.length} line item(s) could not be matched to contract rates: ` +
      unmatched
        .map((m) => `"${m.lineItem.description.substring(0, 30)}"`)
        .join(", ")
    );
  }

  // Total verification: sum of extended vs invoice total
  if (invoiceTotal != null && lineItems && lineItems.length > 0) {
    const sumExtended = roundTo2(
      lineItems.reduce((sum, item) => sum + item.extended, 0)
    );
    const totalDiff = roundTo2(invoiceTotal - sumExtended);
    if (Math.abs(totalDiff) > MATH_TOLERANCE) {
      issues.push(
        `Invoice total ($${invoiceTotal.toFixed(2)}) does not match sum of line items ` +
        `($${sumExtended.toFixed(2)}) — difference: $${totalDiff.toFixed(2)}`
      );
    }
  }

  return issues;
}

// ---------------------------------------------------------------------------
// PO Validation (cross-reference invoice against purchase_orders table)
// ---------------------------------------------------------------------------

export interface POValidationResult {
  found: boolean;
  issues: string[];
  remainingBalance?: number;
}

/**
 * Validate an invoice against its linked PO in Supabase.
 * Checks: PO exists, PO is open, invoice doesn't exceed remaining balance,
 * invoice date falls within PO validity window.
 */
export async function validateAgainstPO(
  poNumber: string | undefined,
  vendor: string | null,
  invoiceTotal: number | undefined,
  invoiceDate: string | undefined
): Promise<POValidationResult> {
  if (!poNumber) return { found: false, issues: [] };

  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_ANON_KEY;
  if (!supabaseUrl || !supabaseKey) return { found: false, issues: [] };

  try {
    const res = await fetch(
      `${supabaseUrl}/rest/v1/purchase_orders?po_number=eq.${encodeURIComponent(poNumber)}&select=vendor,po_number,total_amount,spent_amount,expiry_date,issued_date,status&limit=1`,
      {
        headers: {
          apikey: supabaseKey,
          Authorization: `Bearer ${supabaseKey}`,
        },
      }
    );

    if (!res.ok) return { found: false, issues: [] };
    const rows: any[] = await res.json();
    if (rows.length === 0) return { found: false, issues: [`PO ${poNumber} not found in system`] };

    const po = rows[0];
    const issues: string[] = [];
    const totalAmount = Number(po.total_amount);
    const spentAmount = Number(po.spent_amount || 0);
    const remaining = roundTo2(totalAmount - spentAmount);

    // PO status check
    if (po.status !== "open") {
      issues.push(`PO ${poNumber} is ${po.status} — cannot accept new invoices`);
    }

    // Balance check
    if (invoiceTotal != null && invoiceTotal > remaining) {
      issues.push(
        `Invoice $${invoiceTotal.toFixed(2)} exceeds PO remaining balance $${remaining.toFixed(2)} ` +
        `(PO total: $${totalAmount.toFixed(2)}, already spent: $${spentAmount.toFixed(2)})`
      );
    }

    // Expiry check
    if (po.expiry_date) {
      const today = new Date().toISOString().split("T")[0];
      if (po.expiry_date < today) {
        issues.push(`PO ${poNumber} expired on ${po.expiry_date}`);
      }
    }

    // Vendor mismatch check
    if (vendor && po.vendor) {
      const poVendor = po.vendor.toLowerCase();
      const invVendor = vendor.toLowerCase();
      if (!poVendor.includes(invVendor) && !invVendor.includes(poVendor)) {
        issues.push(`Vendor mismatch: invoice vendor "${vendor}" vs PO vendor "${po.vendor}"`);
      }
    }

    return { found: true, issues, remainingBalance: remaining };
  } catch {
    return { found: false, issues: [] };
  }
}

// ---------------------------------------------------------------------------
// Verdict
// ---------------------------------------------------------------------------

/**
 * Determine overall invoice verdict.
 *
 * GOOD_TO_PAY — no math errors, all rates within tolerance, all items matched
 * REVIEW_REQUIRED — minor issues (unmatched items, low-confidence matches)
 * ISSUES_FOUND — math errors or rate variances exceeding threshold
 */
export function determineVerdict(
  rateMatches: RateMatch[],
  mathChecks: MathCheck[],
  issues: string[]
): Verdict {
  // Any math errors → ISSUES_FOUND
  const hasMathErrors = mathChecks.some((c) => !c.ok);
  if (hasMathErrors) return "ISSUES_FOUND";

  // Any rate variance beyond threshold → ISSUES_FOUND
  const hasRateIssues = rateMatches.some(
    (m) => m.contractRate && !m.rateOk
  );
  if (hasRateIssues) return "ISSUES_FOUND";

  // Unmatched items or total mismatch → REVIEW_REQUIRED
  const hasUnmatched = rateMatches.some((m) => m.tier === "none");
  const hasTotalMismatch = issues.some((i) => i.includes("does not match sum"));
  if (hasUnmatched || hasTotalMismatch) return "REVIEW_REQUIRED";

  // Low-confidence matches (token/partial) → REVIEW_REQUIRED
  const hasLowConfidence = rateMatches.some(
    (m) => (m.tier === "token" || m.tier === "partial") && m.similarity < 0.80
  );
  if (hasLowConfidence) return "REVIEW_REQUIRED";

  return "GOOD_TO_PAY";
}

/**
 * Generate a human-readable summary of the verification result.
 */
export function buildSummary(
  verdict: Verdict,
  lineItemCount: number,
  matchedCount: number,
  mathErrorCount: number,
  rateIssueCount: number,
  vendorDisplay: string
): string {
  const parts: string[] = [];

  parts.push(`${vendorDisplay} invoice: ${lineItemCount} line items parsed`);

  if (matchedCount > 0) {
    parts.push(`${matchedCount}/${lineItemCount} matched to contract rates`);
  }

  if (mathErrorCount > 0) {
    parts.push(`${mathErrorCount} math error(s)`);
  }

  if (rateIssueCount > 0) {
    parts.push(`${rateIssueCount} rate variance(s) exceeding 5%`);
  }

  parts.push(`Verdict: ${verdict.replace(/_/g, " ")}`);

  return parts.join(" | ");
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function roundTo2(n: number): number {
  return Math.round(n * 100) / 100;
}
