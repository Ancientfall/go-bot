/**
 * Invoice Processor — Output Formatters
 *
 * Telegram markdown summary (sent to user immediately)
 * Claude context block (attached to prompt for deeper analysis)
 */

import type { InvoiceVerification, RateMatch, Verdict } from "./types";

// ---------------------------------------------------------------------------
// Telegram Summary (concise, sent before Claude processes)
// ---------------------------------------------------------------------------

const VERDICT_EMOJI: Record<Verdict, string> = {
  GOOD_TO_PAY: "\u2705",      // green check
  REVIEW_REQUIRED: "\u26A0\uFE0F", // warning
  ISSUES_FOUND: "\u274C",      // red X
};

/**
 * Format a concise Telegram-friendly summary.
 * Uses Telegram MarkdownV2-safe formatting (no special chars).
 */
export function formatTelegramSummary(result: InvoiceVerification): string {
  const emoji = VERDICT_EMOJI[result.verdict];
  const lines: string[] = [];

  lines.push(`${emoji} *Invoice Pre-Check: ${result.verdict.replace(/_/g, " ")}*`);
  lines.push("");

  // Vendor & metadata
  lines.push(`Vendor: ${result.vendorDisplay}`);
  if (result.invoiceNumber) lines.push(`Invoice: ${result.invoiceNumber}`);
  if (result.poNumber) lines.push(`PO: ${result.poNumber}`);
  if (result.invoiceDate) lines.push(`Date: ${result.invoiceDate}`);
  if (result.invoiceTotal != null) {
    lines.push(`Total: $${result.invoiceTotal.toFixed(2)}`);
  }
  lines.push("");

  // Line item summary
  const matched = result.rateMatches.filter((m) => m.tier !== "none").length;
  const total = result.lineItems.length;
  const mathErrors = result.mathChecks.filter((c) => !c.ok).length;
  const rateIssues = result.rateMatches.filter(
    (m) => m.contractRate && !m.rateOk
  ).length;

  lines.push(`Line items: ${total} parsed, ${matched} matched to contract`);
  if (mathErrors > 0) lines.push(`Math errors: ${mathErrors}`);
  if (rateIssues > 0) lines.push(`Rate variances: ${rateIssues}`);

  // Top issues (max 5)
  if (result.issues.length > 0) {
    lines.push("");
    lines.push("*Issues:*");
    const shown = result.issues.slice(0, 5);
    for (const issue of shown) {
      lines.push(`- ${issue}`);
    }
    if (result.issues.length > 5) {
      lines.push(`  ...and ${result.issues.length - 5} more`);
    }
  }

  lines.push("");
  lines.push("_Full analysis from Claude follows..._");

  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Claude Context Block (attached to prompt)
// ---------------------------------------------------------------------------

/**
 * Format structured invoice data for Claude's prompt.
 * This gives the agent pre-parsed data so it can focus on analysis
 * rather than re-extracting from raw text.
 */
export function formatClaudeContext(result: InvoiceVerification): string {
  const sections: string[] = [];

  sections.push("## PRE-PROCESSED INVOICE DATA");
  sections.push("");
  sections.push("The following invoice data was automatically extracted and verified.");
  sections.push("Use this structured data for your analysis. Flag any additional issues you spot.");
  sections.push("");

  // Metadata
  sections.push("### Invoice Metadata");
  sections.push(`- Vendor: ${result.vendorDisplay}`);
  if (result.invoiceNumber) sections.push(`- Invoice #: ${result.invoiceNumber}`);
  if (result.poNumber) sections.push(`- PO #: ${result.poNumber}`);
  if (result.invoiceDate) sections.push(`- Date: ${result.invoiceDate}`);
  if (result.invoiceTotal != null) {
    sections.push(`- Invoice Total: $${result.invoiceTotal.toFixed(2)}`);
  }
  sections.push(`- Verdict: ${result.verdict}`);
  sections.push("");

  // Line items with rate matches
  if (result.rateMatches.length > 0) {
    sections.push("### Line Items & Rate Verification");
    sections.push("");

    for (const match of result.rateMatches) {
      const item = match.lineItem;
      const rateInfo = formatRateMatch(match);
      sections.push(
        `${item.lineNumber}. ${item.description}` +
        (item.catalogNumber ? ` [${item.catalogNumber}]` : "") +
        ` — Qty: ${item.quantity}, Rate: $${item.unitRate.toFixed(2)}, ` +
        `Ext: $${item.extended.toFixed(2)} ${rateInfo}`
      );
    }
    sections.push("");
  }

  // Math checks
  const mathErrors = result.mathChecks.filter((c) => !c.ok);
  if (mathErrors.length > 0) {
    sections.push("### Math Errors");
    for (const err of mathErrors) {
      sections.push(
        `- Line ${err.lineNumber}: qty*rate = $${err.expected.toFixed(2)}, ` +
        `invoiced $${err.actual.toFixed(2)} (diff: $${err.difference.toFixed(2)})`
      );
    }
    sections.push("");
  }

  // All issues
  if (result.issues.length > 0) {
    sections.push("### Flagged Issues");
    for (const issue of result.issues) {
      sections.push(`- ${issue}`);
    }
    sections.push("");
  }

  return sections.join("\n");
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatRateMatch(match: RateMatch): string {
  if (!match.contractRate) {
    return "(no contract rate match)";
  }

  const pct = (match.rateVariance * 100).toFixed(1);
  const status = match.rateOk ? "OK" : `VARIANCE ${pct}%`;
  return `[${match.tier} match, contract: $${match.contractRate.rate.toFixed(2)}, ${status}]`;
}
