/**
 * Invoice Processor — Type Definitions
 *
 * Core interfaces for the invoice verification pipeline:
 * extract → detect vendor → parse → match rates → verify → result
 */

// ---------------------------------------------------------------------------
// Vendor
// ---------------------------------------------------------------------------

export type VendorId = "pmi" | "arcwood" | "rcs" | "c-logistics" | "danos";

export const VENDOR_DISPLAY: Record<VendorId, string> = {
  pmi: "PMI",
  arcwood: "Arcwood",
  rcs: "RCS",
  "c-logistics": "C-Logistics",
  danos: "Danos",
};

// ---------------------------------------------------------------------------
// Contract Rates (loaded from CSV)
// ---------------------------------------------------------------------------

export interface ContractRate {
  vendor: VendorId;
  description: string;
  catalogNumber?: string;
  unit: string;
  rate: number;
  category?: string;
}

// ---------------------------------------------------------------------------
// Parsed Invoice Line Items
// ---------------------------------------------------------------------------

export interface InvoiceLineItem {
  lineNumber: number;
  description: string;
  catalogNumber?: string;
  quantity: number;
  unit?: string;
  unitRate: number;
  extended: number;
  raw: string; // original text line for audit
}

// ---------------------------------------------------------------------------
// Rate Matching
// ---------------------------------------------------------------------------

export type MatchTier = "exact" | "catalog" | "token" | "partial" | "none";

export interface RateMatch {
  lineItem: InvoiceLineItem;
  contractRate: ContractRate | null;
  tier: MatchTier;
  similarity: number; // 0-1, 1.0 = exact
  rateVariance: number; // percent difference (invoiced vs contract)
  rateOk: boolean; // within ±5%
}

// ---------------------------------------------------------------------------
// Math Verification
// ---------------------------------------------------------------------------

export interface MathCheck {
  lineNumber: number;
  expected: number; // qty × rate
  actual: number; // extended on invoice
  difference: number;
  ok: boolean; // within $0.02 tolerance
}

// ---------------------------------------------------------------------------
// Overall Verification Result
// ---------------------------------------------------------------------------

export type Verdict = "GOOD_TO_PAY" | "REVIEW_REQUIRED" | "ISSUES_FOUND";

export interface InvoiceVerification {
  vendor: VendorId | null;
  vendorDisplay: string;
  invoiceNumber?: string;
  poNumber?: string;
  invoiceDate?: string;
  invoiceTotal?: number;
  lineItems: InvoiceLineItem[];
  rateMatches: RateMatch[];
  mathChecks: MathCheck[];
  issues: string[];
  verdict: Verdict;
  summary: string;
  extractedText: string;
  processedAt: string;
}
