/**
 * Invoice Processor — Line Item Parsers
 *
 * Vendor-specific regex parsers that extract line items from invoice text.
 * Each vendor has its own invoice format; the generic fallback catches
 * common patterns (description + qty + rate + extended).
 */

import type { VendorId, InvoiceLineItem } from "./types";

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Parse line items from extracted invoice text.
 * Uses vendor-specific parser if available, otherwise generic fallback.
 */
export function parseLineItems(
  text: string,
  vendor: VendorId | null
): InvoiceLineItem[] {
  const parser = vendor ? VENDOR_PARSERS[vendor] : null;
  const items = parser ? parser(text) : genericParser(text);

  // De-duplicate by line number
  const seen = new Set<number>();
  return items.filter((item) => {
    if (seen.has(item.lineNumber)) return false;
    seen.add(item.lineNumber);
    return true;
  });
}

/**
 * Extract invoice metadata (invoice number, PO, date, total) from text.
 */
export function parseInvoiceMetadata(text: string): {
  invoiceNumber?: string;
  poNumber?: string;
  invoiceDate?: string;
  invoiceTotal?: number;
} {
  const meta: ReturnType<typeof parseInvoiceMetadata> = {};

  // Invoice number patterns
  const invMatch = text.match(
    /(?:invoice\s*(?:#|no\.?|number)\s*:?\s*)([A-Z0-9][\w-]{2,20})/i
  );
  if (invMatch) meta.invoiceNumber = invMatch[1].trim();

  // PO number patterns
  const poMatch = text.match(
    /(?:p\.?o\.?\s*(?:#|no\.?|number)?\s*:?\s*)(\d[\w-]{3,20})/i
  );
  if (poMatch) meta.poNumber = poMatch[1].trim();

  // Invoice date patterns
  const dateMatch = text.match(
    /(?:invoice\s*date|date\s*of\s*invoice|inv\.?\s*date)\s*:?\s*(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})/i
  );
  if (dateMatch) meta.invoiceDate = dateMatch[1].trim();

  // Total amount — look for "total" near a dollar amount at end of document
  const totalMatch = text.match(
    /(?:total|amount\s*due|balance\s*due|grand\s*total)\s*:?\s*\$?\s*([\d,]+\.\d{2})/i
  );
  if (totalMatch) {
    meta.invoiceTotal = parseFloat(totalMatch[1].replace(/,/g, ""));
  }

  return meta;
}

// ---------------------------------------------------------------------------
// Vendor-Specific Parsers
// ---------------------------------------------------------------------------

type ParserFn = (text: string) => InvoiceLineItem[];

const VENDOR_PARSERS: Record<VendorId, ParserFn> = {
  pmi: pmiParser,
  arcwood: arcwoodParser,
  rcs: rcsParser,
  "c-logistics": cLogisticsParser,
  danos: danosParser,
};

/**
 * PMI — Production Management Industries
 * Format: line items typically in tabular layout with
 *   description | qty | unit | rate | extended
 */
function pmiParser(text: string): InvoiceLineItem[] {
  const items: InvoiceLineItem[] = [];
  const lines = text.split("\n");
  let lineNum = 0;

  // PMI invoices often have catalog numbers like "PMI-1234"
  // Pattern: optional line# / catalog, description, qty, rate, amount
  const linePattern =
    /^[\s]*(\d+)?[\s]*(?:(PMI[\w-]*)\s+)?(.{10,60}?)\s{2,}(\d+(?:\.\d+)?)\s+([\w]+)\s+\$?\s*([\d,]+\.\d{2})\s+\$?\s*([\d,]+\.\d{2})/;

  for (const line of lines) {
    const match = line.match(linePattern);
    if (match) {
      lineNum++;
      items.push({
        lineNumber: lineNum,
        description: match[3].trim(),
        catalogNumber: match[2]?.trim(),
        quantity: parseFloat(match[4]),
        unit: match[5]?.trim(),
        unitRate: parseDollar(match[6]),
        extended: parseDollar(match[7]),
        raw: line.trim(),
      });
    }
  }

  // Fallback: try generic if vendor-specific found nothing
  return items.length > 0 ? items : genericParser(text);
}

/**
 * Arcwood
 * Format varies — often description on left, numbers right-aligned
 */
function arcwoodParser(text: string): InvoiceLineItem[] {
  const items: InvoiceLineItem[] = [];
  const lines = text.split("\n");
  let lineNum = 0;

  // Pattern: description (flexible width), qty, rate, extended
  const linePattern =
    /^[\s]*(.{10,70}?)\s{2,}(\d+(?:\.\d+)?)\s+\$?\s*([\d,]+\.\d{2})\s+\$?\s*([\d,]+\.\d{2})/;

  for (const line of lines) {
    if (isHeaderOrFooter(line)) continue;
    const match = line.match(linePattern);
    if (match) {
      lineNum++;
      items.push({
        lineNumber: lineNum,
        description: match[1].trim(),
        quantity: parseFloat(match[2]),
        unitRate: parseDollar(match[3]),
        extended: parseDollar(match[4]),
        raw: line.trim(),
      });
    }
  }

  return items.length > 0 ? items : genericParser(text);
}

/**
 * RCS
 * Similar tabular format with possible catalog/part numbers
 */
function rcsParser(text: string): InvoiceLineItem[] {
  const items: InvoiceLineItem[] = [];
  const lines = text.split("\n");
  let lineNum = 0;

  // RCS often has part number prefix
  const linePattern =
    /^[\s]*(?:(\w{2,10}-\d+)\s+)?(.{10,65}?)\s{2,}(\d+(?:\.\d+)?)\s+(?:\w+\s+)?\$?\s*([\d,]+\.\d{2})\s+\$?\s*([\d,]+\.\d{2})/;

  for (const line of lines) {
    if (isHeaderOrFooter(line)) continue;
    const match = line.match(linePattern);
    if (match) {
      lineNum++;
      items.push({
        lineNumber: lineNum,
        description: match[2].trim(),
        catalogNumber: match[1]?.trim(),
        quantity: parseFloat(match[3]),
        unitRate: parseDollar(match[4]),
        extended: parseDollar(match[5]),
        raw: line.trim(),
      });
    }
  }

  return items.length > 0 ? items : genericParser(text);
}

/**
 * C-Logistics
 * Logistics invoices — often have service codes and day rates
 */
function cLogisticsParser(text: string): InvoiceLineItem[] {
  const items: InvoiceLineItem[] = [];
  const lines = text.split("\n");
  let lineNum = 0;

  const linePattern =
    /^[\s]*(?:(\d{3,6})\s+)?(.{10,65}?)\s{2,}(\d+(?:\.\d+)?)\s+(?:(?:day|hr|ea|each|lot|ls|mo)\s+)?\$?\s*([\d,]+\.\d{2})\s+\$?\s*([\d,]+\.\d{2})/i;

  for (const line of lines) {
    if (isHeaderOrFooter(line)) continue;
    const match = line.match(linePattern);
    if (match) {
      lineNum++;
      items.push({
        lineNumber: lineNum,
        description: match[2].trim(),
        catalogNumber: match[1]?.trim(),
        quantity: parseFloat(match[3]),
        unitRate: parseDollar(match[4]),
        extended: parseDollar(match[5]),
        raw: line.trim(),
      });
    }
  }

  return items.length > 0 ? items : genericParser(text);
}

/**
 * Danos
 * Often has labor categories with hourly rates
 */
function danosParser(text: string): InvoiceLineItem[] {
  const items: InvoiceLineItem[] = [];
  const lines = text.split("\n");
  let lineNum = 0;

  const linePattern =
    /^[\s]*(.{10,65}?)\s{2,}(\d+(?:\.\d+)?)\s+(?:(?:hrs?|hours?|days?|ea|each)\s+)?\$?\s*([\d,]+\.\d{2})\s+\$?\s*([\d,]+\.\d{2})/i;

  for (const line of lines) {
    if (isHeaderOrFooter(line)) continue;
    const match = line.match(linePattern);
    if (match) {
      lineNum++;
      items.push({
        lineNumber: lineNum,
        description: match[1].trim(),
        quantity: parseFloat(match[2]),
        unitRate: parseDollar(match[3]),
        extended: parseDollar(match[4]),
        raw: line.trim(),
      });
    }
  }

  return items.length > 0 ? items : genericParser(text);
}

// ---------------------------------------------------------------------------
// Generic Fallback Parser
// ---------------------------------------------------------------------------

/**
 * Generic parser that catches common invoice line item patterns:
 *   description    qty    rate    extended
 *
 * Handles optional $ signs, commas, and unit labels.
 */
function genericParser(text: string): InvoiceLineItem[] {
  const items: InvoiceLineItem[] = [];
  const lines = text.split("\n");
  let lineNum = 0;

  // Pattern: description (10-70 chars), then 2+ spaces, qty, rate, extended
  // The description must not start with common header/footer words
  const linePattern =
    /^[\s]*(.{10,70}?)\s{2,}(\d+(?:\.\d+)?)\s+\$?\s*([\d,]+\.\d{2})\s+\$?\s*([\d,]+\.\d{2})/;

  for (const line of lines) {
    if (isHeaderOrFooter(line)) continue;
    const match = line.match(linePattern);
    if (match) {
      const desc = match[1].trim();
      // Skip if description looks like a header
      if (/^(description|item|qty|quantity|rate|amount|unit|total|subtotal)/i.test(desc)) {
        continue;
      }
      lineNum++;
      items.push({
        lineNumber: lineNum,
        description: desc,
        quantity: parseFloat(match[2]),
        unitRate: parseDollar(match[3]),
        extended: parseDollar(match[4]),
        raw: line.trim(),
      });
    }
  }

  return items;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function parseDollar(s: string): number {
  return parseFloat(s.replace(/[$,]/g, ""));
}

function isHeaderOrFooter(line: string): boolean {
  const lower = line.toLowerCase().trim();
  return (
    lower === "" ||
    /^(page\s+\d|remit\s+to|bill\s+to|ship\s+to|terms:|payment\s+terms)/i.test(lower) ||
    /^-{3,}$/.test(lower) ||
    /^={3,}$/.test(lower)
  );
}
