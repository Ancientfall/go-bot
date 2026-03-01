/**
 * Gemini AI News Data Source
 *
 * Fetches AI news summary using Gemini with Google Search grounding.
 * Uses the same GEMINI_API_KEY as voice/transcription — no extra key needed.
 *
 * Required env vars: GEMINI_API_KEY
 */

import { register } from "../registry";
import type { DataSource, DataSourceResult } from "../types";

const geminiNewsSource: DataSource = {
  id: "gemini-news",
  name: "AI News",
  emoji: "📰",

  isAvailable(): boolean {
    // Only use Gemini for news if Grok (XAI) isn't configured
    return !!process.env.GEMINI_API_KEY && !process.env.XAI_API_KEY;
  },

  async fetch(): Promise<DataSourceResult> {
    const apiKey = process.env.GEMINI_API_KEY!;

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              role: "user",
              parts: [
                {
                  text: "What are today's top 3-5 AI and technology news stories? Return concise bullet points, one sentence each. Format: • [news item] (source). No headers, no fluff. Only include real, verified news from the last 24 hours.",
                },
              ],
            },
          ],
          tools: [{ google_search: {} }],
          generationConfig: {
            maxOutputTokens: 400,
            temperature: 0,
          },
        }),
      }
    );

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Gemini API error (${response.status}): ${text}`);
    }

    const data = await response.json();
    const content =
      data.candidates?.[0]?.content?.parts
        ?.map((p: any) => p.text)
        .filter(Boolean)
        .join("\n")
        .trim() || "";

    if (!content) {
      return { lines: ["No news available"], meta: { empty: true } };
    }

    // Check for grounding metadata (confirms search was used)
    const hasGrounding =
      data.candidates?.[0]?.groundingMetadata?.searchEntryPoint ||
      data.candidates?.[0]?.groundingMetadata?.groundingChunks?.length > 0 ||
      content.includes("http") ||
      content.includes(".com");

    if (!hasGrounding && !content.toLowerCase().includes("quiet")) {
      console.warn(
        "Gemini news response has no grounding metadata — may not reflect real news"
      );
    }

    const lines = content
      .split("\n")
      .map((l: string) => l.trim())
      .filter((l: string) => l.length > 0);

    return { lines, meta: { model: "gemini-2.5-flash", grounded: !!hasGrounding } };
  },
};

register(geminiNewsSource);
