/**
 * Invoice Processor — Public API
 *
 * Usage:
 *   import { processInvoice, formatTelegramSummary, formatClaudeContext } from "./lib/invoice";
 */

export { processInvoice, formatTelegramSummary, formatClaudeContext } from "./processor";
export { extractText } from "./extract";
export { detectVendor, loadRates, clearRateCache } from "./vendors";
export { parseLineItems, parseInvoiceMetadata } from "./parse";
export { matchRates } from "./match";
export { verifyMath, collectIssues, determineVerdict, validateAgainstPO } from "./verify";
export type {
  VendorId,
  ContractRate,
  InvoiceLineItem,
  RateMatch,
  MathCheck,
  InvoiceVerification,
  Verdict,
  MatchTier,
} from "./types";
export { VENDOR_DISPLAY } from "./types";
