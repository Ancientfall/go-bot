/**
 * Invoice Processor — Rate Matching
 *
 * Matches parsed invoice line items against contract rates.
 * Cascade: exact → catalog → token (Jaccard) → partial substring
 * Stops at first match per line item.
 */

import type {
  ContractRate,
  InvoiceLineItem,
  RateMatch,
  MatchTier,
} from "./types";

// Words to strip before token comparison — common noise in descriptions
const NOISE_WORDS = new Set([
  "the", "a", "an", "and", "or", "of", "for", "to", "in", "on", "at",
  "with", "per", "ea", "each", "lot", "ls", "lump", "sum",
  "hr", "hrs", "hour", "hours", "day", "days", "mo", "month",
  "service", "services", "supply", "supplies", "rental", "rentals",
]);

const RATE_VARIANCE_THRESHOLD = 0.05; // 5%

/**
 * Match all line items against a vendor's contract rates.
 */
export function matchRates(
  lineItems: InvoiceLineItem[],
  contractRates: ContractRate[]
): RateMatch[] {
  return lineItems.map((item) => matchSingle(item, contractRates));
}

/**
 * Match a single line item against contract rates.
 * Tries each tier in order, stops at first match.
 */
function matchSingle(
  item: InvoiceLineItem,
  rates: ContractRate[]
): RateMatch {
  // If no contract rates available, return unmatched
  if (rates.length === 0) {
    return {
      lineItem: item,
      contractRate: null,
      tier: "none",
      similarity: 0,
      rateVariance: 0,
      rateOk: true, // can't verify without rates
    };
  }

  // Tier 1: Exact match (normalized description)
  const exactMatch = tryExact(item, rates);
  if (exactMatch) return buildMatch(item, exactMatch, "exact", 1.0);

  // Tier 2: Catalog number match
  if (item.catalogNumber) {
    const catalogMatch = tryCatalog(item, rates);
    if (catalogMatch) return buildMatch(item, catalogMatch, "catalog", 1.0);
  }

  // Tier 3: Token-based Jaccard similarity (≥0.60)
  const tokenResult = tryToken(item, rates);
  if (tokenResult) {
    return buildMatch(item, tokenResult.rate, "token", tokenResult.similarity);
  }

  // Tier 4: Partial substring match (≥0.70 of shorter string length)
  const partialResult = tryPartial(item, rates);
  if (partialResult) {
    return buildMatch(item, partialResult.rate, "partial", partialResult.similarity);
  }

  // No match found
  return {
    lineItem: item,
    contractRate: null,
    tier: "none",
    similarity: 0,
    rateVariance: 0,
    rateOk: true,
  };
}

// ---------------------------------------------------------------------------
// Tier 1: Exact Match
// ---------------------------------------------------------------------------

function tryExact(
  item: InvoiceLineItem,
  rates: ContractRate[]
): ContractRate | null {
  const norm = normalize(item.description);
  return rates.find((r) => normalize(r.description) === norm) || null;
}

// ---------------------------------------------------------------------------
// Tier 2: Catalog Number Match
// ---------------------------------------------------------------------------

function tryCatalog(
  item: InvoiceLineItem,
  rates: ContractRate[]
): ContractRate | null {
  if (!item.catalogNumber) return null;
  const cat = item.catalogNumber.toLowerCase().trim();
  return (
    rates.find(
      (r) => r.catalogNumber && r.catalogNumber.toLowerCase().trim() === cat
    ) || null
  );
}

// ---------------------------------------------------------------------------
// Tier 3: Token-based Jaccard Similarity
// ---------------------------------------------------------------------------

function tryToken(
  item: InvoiceLineItem,
  rates: ContractRate[]
): { rate: ContractRate; similarity: number } | null {
  const itemTokens = tokenize(item.description);
  let best: { rate: ContractRate; similarity: number } | null = null;

  for (const rate of rates) {
    const rateTokens = tokenize(rate.description);
    const sim = jaccardSimilarity(itemTokens, rateTokens);
    if (sim >= 0.60 && (!best || sim > best.similarity)) {
      best = { rate, similarity: sim };
    }
  }

  return best;
}

function jaccardSimilarity(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 && b.size === 0) return 0;
  let intersection = 0;
  a.forEach((token) => {
    if (b.has(token)) intersection++;
  });
  const union = a.size + b.size - intersection;
  return union === 0 ? 0 : intersection / union;
}

// ---------------------------------------------------------------------------
// Tier 4: Partial Substring Match
// ---------------------------------------------------------------------------

function tryPartial(
  item: InvoiceLineItem,
  rates: ContractRate[]
): { rate: ContractRate; similarity: number } | null {
  const normItem = normalize(item.description);
  let best: { rate: ContractRate; similarity: number } | null = null;

  for (const rate of rates) {
    const normRate = normalize(rate.description);
    const sim = substringScore(normItem, normRate);
    if (sim >= 0.70 && (!best || sim > best.similarity)) {
      best = { rate, similarity: sim };
    }
  }

  return best;
}

/**
 * Score based on longest common substring relative to shorter string.
 * Also checks if either string fully contains the other.
 */
function substringScore(a: string, b: string): number {
  // Full containment check
  if (a.includes(b)) return b.length / a.length;
  if (b.includes(a)) return a.length / b.length;

  // Longest common substring ratio
  const shorter = a.length <= b.length ? a : b;
  const longer = a.length > b.length ? a : b;
  const lcs = longestCommonSubstring(shorter, longer);
  return lcs / shorter.length;
}

function longestCommonSubstring(a: string, b: string): number {
  let maxLen = 0;
  // Sliding window approach for efficiency
  for (let i = 0; i < a.length; i++) {
    for (let j = 0; j < b.length; j++) {
      let len = 0;
      while (
        i + len < a.length &&
        j + len < b.length &&
        a[i + len] === b[j + len]
      ) {
        len++;
      }
      if (len > maxLen) maxLen = len;
    }
  }
  return maxLen;
}

// ---------------------------------------------------------------------------
// Build Match Result
// ---------------------------------------------------------------------------

function buildMatch(
  item: InvoiceLineItem,
  rate: ContractRate,
  tier: MatchTier,
  similarity: number
): RateMatch {
  const variance =
    rate.rate === 0
      ? 0
      : (item.unitRate - rate.rate) / rate.rate;

  return {
    lineItem: item,
    contractRate: rate,
    tier,
    similarity,
    rateVariance: variance,
    rateOk: Math.abs(variance) <= RATE_VARIANCE_THRESHOLD,
  };
}

// ---------------------------------------------------------------------------
// Text Normalization
// ---------------------------------------------------------------------------

function normalize(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function tokenize(s: string): Set<string> {
  const words = normalize(s).split(" ");
  return new Set(words.filter((w) => w.length > 1 && !NOISE_WORDS.has(w)));
}
