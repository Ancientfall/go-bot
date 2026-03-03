/**
 * Invoice Processor — Vendor Detection & Rate Loading
 *
 * Detects vendor from extracted PDF text via substring matching.
 * Loads contract rates from CSV files in config/rates/ with caching.
 */

import { readFile } from "fs/promises";
import { join } from "path";
import type { VendorId, ContractRate } from "./types";

// ---------------------------------------------------------------------------
// Vendor Detection
// ---------------------------------------------------------------------------

const VENDOR_PATTERNS: { id: VendorId; patterns: string[] }[] = [
  {
    id: "pmi",
    patterns: [
      "production management industries",
      "pmi industries",
      "pmi ",
      "production mgmt",
    ],
  },
  {
    id: "arcwood",
    patterns: ["arcwood", "arc wood"],
  },
  {
    id: "rcs",
    patterns: [
      "rcs ",
      "r.c.s.",
      "rcs,",
      "rcs-",
    ],
  },
  {
    id: "c-logistics",
    patterns: [
      "c-logistics",
      "c logistics",
      "clogistics",
      "c-log",
    ],
  },
  {
    id: "danos",
    patterns: ["danos", "danos &", "danos and"],
  },
];

/**
 * Detect vendor from extracted invoice text.
 * Returns null if no vendor pattern matches.
 */
export function detectVendor(text: string): VendorId | null {
  const lower = text.toLowerCase();

  for (const vendor of VENDOR_PATTERNS) {
    for (const pattern of vendor.patterns) {
      if (lower.includes(pattern)) {
        return vendor.id;
      }
    }
  }

  return null;
}

// ---------------------------------------------------------------------------
// Contract Rate CSV Loading
// ---------------------------------------------------------------------------

const rateCache = new Map<VendorId, ContractRate[]>();
const PROJECT_ROOT = process.env.GO_PROJECT_ROOT || process.cwd();

/**
 * Load contract rates for a vendor from its CSV file.
 * Cached after first load. Returns empty array if file not found.
 *
 * Expected CSV format (header row required):
 *   description,catalog_number,unit,rate,category
 *
 * Minimal required columns: description, rate
 */
export async function loadRates(vendor: VendorId): Promise<ContractRate[]> {
  const cached = rateCache.get(vendor);
  if (cached) return cached;

  const csvPath = join(PROJECT_ROOT, "config", "rates", `${vendor}.csv`);

  let content: string;
  try {
    content = await readFile(csvPath, "utf-8");
  } catch {
    console.log(`[invoice] No rate file found: ${csvPath}`);
    rateCache.set(vendor, []);
    return [];
  }

  const rates = parseRateCsv(content, vendor);
  rateCache.set(vendor, rates);
  console.log(`[invoice] Loaded ${rates.length} rates for ${vendor}`);
  return rates;
}

/**
 * Parse a CSV string into ContractRate objects.
 * Handles quoted fields and trims whitespace.
 */
function parseRateCsv(content: string, vendor: VendorId): ContractRate[] {
  const lines = content.split("\n").filter((l) => l.trim());
  if (lines.length < 2) return []; // need header + at least 1 data row

  const header = parseCsvLine(lines[0]).map((h) => h.toLowerCase().trim());
  const descIdx = header.findIndex((h) =>
    h.includes("description") || h.includes("desc") || h.includes("item")
  );
  const rateIdx = header.findIndex((h) =>
    h.includes("rate") || h.includes("price") || h.includes("cost")
  );

  if (descIdx === -1 || rateIdx === -1) {
    console.error(
      `[invoice] CSV for ${vendor} missing description or rate column. Headers: ${header.join(", ")}`
    );
    return [];
  }

  const catalogIdx = header.findIndex((h) =>
    h.includes("catalog") || h.includes("part") || h.includes("sku") || h.includes("item_number")
  );
  const unitIdx = header.findIndex((h) =>
    h.includes("unit") || h.includes("uom")
  );
  const categoryIdx = header.findIndex((h) =>
    h.includes("category") || h.includes("cat") || h.includes("type")
  );

  const rates: ContractRate[] = [];

  for (let i = 1; i < lines.length; i++) {
    const fields = parseCsvLine(lines[i]);
    const desc = fields[descIdx]?.trim();
    const rateStr = fields[rateIdx]?.trim().replace(/[$,]/g, "");
    const rate = parseFloat(rateStr || "");

    if (!desc || isNaN(rate)) continue;

    rates.push({
      vendor,
      description: desc,
      catalogNumber: catalogIdx >= 0 ? fields[catalogIdx]?.trim() || undefined : undefined,
      unit: unitIdx >= 0 ? fields[unitIdx]?.trim() || "EA" : "EA",
      rate,
      category: categoryIdx >= 0 ? fields[categoryIdx]?.trim() || undefined : undefined,
    });
  }

  return rates;
}

/**
 * Parse a single CSV line, handling quoted fields with commas inside.
 */
function parseCsvLine(line: string): string[] {
  const fields: string[] = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++; // skip escaped quote
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch === "," && !inQuotes) {
      fields.push(current);
      current = "";
    } else {
      current += ch;
    }
  }
  fields.push(current);

  return fields;
}

/**
 * Clear the rate cache (useful for testing or reloading updated CSVs).
 */
export function clearRateCache(): void {
  rateCache.clear();
}
