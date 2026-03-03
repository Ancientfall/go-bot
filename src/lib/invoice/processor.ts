/**
 * Invoice Processor — Orchestrator
 *
 * Pipeline: extract → detect vendor → parse → match → verify → result
 *
 * Standalone usage:
 *   bun run src/lib/invoice/processor.ts path/to/invoice.pdf
 */

import { extractText } from "./extract";
import { detectVendor, loadRates } from "./vendors";
import { parseLineItems, parseInvoiceMetadata } from "./parse";
import { matchRates } from "./match";
import { verifyMath, collectIssues, determineVerdict, buildSummary, validateAgainstPO } from "./verify";
import { formatTelegramSummary, formatClaudeContext } from "./format";
import { VENDOR_DISPLAY } from "./types";
import type { InvoiceVerification } from "./types";
import { getSupabase } from "../supabase";

// ---------------------------------------------------------------------------
// Main Processor
// ---------------------------------------------------------------------------

/**
 * Process an invoice PDF through the full verification pipeline.
 * Non-fatal — returns null on unrecoverable errors.
 */
export async function processInvoice(
  pdfPath: string
): Promise<InvoiceVerification | null> {
  const startTime = Date.now();

  try {
    // 1. Extract text
    console.log(`[invoice] Extracting text from: ${pdfPath}`);
    const text = await extractText(pdfPath);

    if (!text || text.trim().length < 20) {
      console.log("[invoice] Insufficient text extracted from PDF");
      return null;
    }

    // 2. Detect vendor
    const vendor = detectVendor(text);
    const vendorDisplay = vendor ? VENDOR_DISPLAY[vendor] : "Unknown";
    console.log(`[invoice] Detected vendor: ${vendorDisplay}`);

    // 3. Parse metadata
    const meta = parseInvoiceMetadata(text);

    // 4. Parse line items
    const lineItems = parseLineItems(text, vendor);
    console.log(`[invoice] Parsed ${lineItems.length} line items`);

    if (lineItems.length === 0) {
      // Still return a result — Claude can analyze the raw text
      return {
        vendor,
        vendorDisplay,
        ...meta,
        lineItems: [],
        rateMatches: [],
        mathChecks: [],
        issues: ["No line items could be parsed from the invoice"],
        verdict: "REVIEW_REQUIRED",
        summary: `${vendorDisplay} invoice: no line items parsed — manual review needed`,
        extractedText: text,
        processedAt: new Date().toISOString(),
      };
    }

    // 5. Load contract rates and match
    const contractRates = vendor ? await loadRates(vendor) : [];
    const rateMatches = matchRates(lineItems, contractRates);

    // 6. Math verification
    const mathChecks = verifyMath(lineItems);

    // 7. Collect issues
    const issues = collectIssues(rateMatches, mathChecks, meta.invoiceTotal, lineItems);

    // 7b. PO validation (cross-reference against purchase_orders table)
    const poValidation = await validateAgainstPO(
      meta.poNumber,
      vendor,
      meta.invoiceTotal,
      meta.invoiceDate
    );
    if (poValidation.issues.length > 0) {
      issues.push(...poValidation.issues);
    }

    // 8. Determine verdict
    const verdict = determineVerdict(rateMatches, mathChecks, issues);

    // 9. Build summary
    const matchedCount = rateMatches.filter((m) => m.tier !== "none").length;
    const mathErrorCount = mathChecks.filter((c) => !c.ok).length;
    const rateIssueCount = rateMatches.filter(
      (m) => m.contractRate && !m.rateOk
    ).length;
    const summary = buildSummary(
      verdict,
      lineItems.length,
      matchedCount,
      mathErrorCount,
      rateIssueCount,
      vendorDisplay
    );

    const result: InvoiceVerification = {
      vendor,
      vendorDisplay,
      ...meta,
      lineItems,
      rateMatches,
      mathChecks,
      issues,
      verdict,
      summary,
      extractedText: text,
      processedAt: new Date().toISOString(),
    };

    const elapsed = Date.now() - startTime;
    console.log(`[invoice] Processing complete in ${elapsed}ms — ${verdict}`);

    // 10. Save to Supabase audit trail (non-blocking)
    saveVerification(result).catch((err) => {
      console.error("[invoice] Failed to save verification:", err);
    });

    return result;
  } catch (error) {
    console.error("[invoice] Processing failed:", error);
    return null;
  }
}

// ---------------------------------------------------------------------------
// Supabase Audit Trail
// ---------------------------------------------------------------------------

async function saveVerification(result: InvoiceVerification): Promise<void> {
  const sb = getSupabase();
  if (!sb) return;

  try {
    await sb.from("invoice_verifications").insert({
      vendor: result.vendor,
      vendor_display: result.vendorDisplay,
      invoice_number: result.invoiceNumber,
      po_number: result.poNumber,
      invoice_date: result.invoiceDate,
      invoice_total: result.invoiceTotal,
      line_item_count: result.lineItems.length,
      verdict: result.verdict,
      issues: result.issues,
      summary: result.summary,
      raw_result: {
        rateMatches: result.rateMatches.map((m) => ({
          line: m.lineItem.lineNumber,
          description: m.lineItem.description,
          invoicedRate: m.lineItem.unitRate,
          contractRate: m.contractRate?.rate,
          tier: m.tier,
          similarity: m.similarity,
          rateVariance: m.rateVariance,
          rateOk: m.rateOk,
        })),
        mathChecks: result.mathChecks,
      },
    });
  } catch (error) {
    console.error("[invoice] Supabase insert failed:", error);
  }
}

// ---------------------------------------------------------------------------
// Re-export formatters for bot.ts integration
// ---------------------------------------------------------------------------

export { formatTelegramSummary, formatClaudeContext };

// ---------------------------------------------------------------------------
// Standalone CLI
// ---------------------------------------------------------------------------

if (import.meta.main) {
  const pdfPath = process.argv[2] || Bun.argv[2];

  if (!pdfPath) {
    console.error("Usage: bun run src/lib/invoice/processor.ts <path-to-pdf>");
    process.exit(1);
  }

  // Load env for Supabase
  const { loadEnv } = await import("../env");
  await loadEnv();

  const result = await processInvoice(pdfPath);

  if (!result) {
    console.error("\nProcessing failed — no result.");
    process.exit(1);
  }

  console.log("\n" + "=".repeat(60));
  console.log("TELEGRAM SUMMARY:");
  console.log("=".repeat(60));
  console.log(formatTelegramSummary(result));

  console.log("\n" + "=".repeat(60));
  console.log("CLAUDE CONTEXT:");
  console.log("=".repeat(60));
  console.log(formatClaudeContext(result));

  console.log("\n" + "=".repeat(60));
  console.log(`Verdict: ${result.verdict}`);
  console.log(`Line items: ${result.lineItems.length}`);
  console.log(`Issues: ${result.issues.length}`);
  console.log("=".repeat(60));
}
