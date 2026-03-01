/**
 * Go - Multi-Agent Base Configuration
 *
 * Base interface and utilities for agent configurations.
 * Each agent has specialized instructions, tools, and reasoning style.
 */

import { readFile } from "fs/promises";
import { join } from "path";

export interface AgentConfig {
  name: string;
  topicId?: number;
  systemPrompt: string;
  allowedTools?: string[]; // Optional: restrict tools per agent. If omitted, Claude gets full access to all tools, MCP servers, and skills.
  model: string;
  reasoning?: string;
  personality?: string;
}

// Default topic-to-agent mapping. Update these with your Telegram forum topic IDs.
// Find topic IDs by sending a message in each topic and checking the bot logs.
export const topicAgentMap: Record<number, string> = {
  2: "software",
  3: "database",
  6: "bp-docs",
  8: "bp-invoices",
  9: "bp-finance",
  27: "bp-contracts",
};

export function getAgentByTopicId(topicId: number): string | undefined {
  return topicAgentMap[topicId];
}

export function getAgentConfig(agentName: string): AgentConfig | undefined {
  switch (agentName.toLowerCase()) {
    case "software":
    case "swe":
    case "engineer":
    case "code":
      return require("./software").default;
    case "database":
    case "db":
    case "supabase":
      return require("./database").default;
    case "bp-docs":
    case "bpdocs":
    case "documents":
      return require("./bp-docs").default;
    case "bp-contracts":
    case "bpcontracts":
    case "contracts":
      return require("./bp-contracts").default;
    case "bp-invoices":
    case "bpinvoices":
    case "invoices":
      return require("./bp-invoices").default;
    case "bp-finance":
    case "bpfinance":
    case "budgets":
    case "finance":
      return require("./bp-finance").default;
    case "critic":
    case "devils-advocate":
      return require("./critic").default;
    case "general":
    case "orchestrator":
    default:
      return require("./general").default;
  }
}

// Cross-agent invocation permissions
export const AGENT_INVOCATION_MAP: Record<string, string[]> = {
  software: ["critic", "database"],
  database: ["critic", "software"],
  "bp-docs": ["critic", "bp-contracts", "bp-finance"],
  "bp-contracts": ["critic", "bp-docs", "bp-finance"],
  "bp-invoices": ["critic", "bp-contracts", "bp-finance"],
  "bp-finance": ["critic", "bp-invoices", "bp-contracts"],
  general: ["critic", "software", "database", "bp-docs", "bp-contracts", "bp-invoices", "bp-finance"],
  critic: [], // Critic doesn't invoke others (prevents loops)
};

export function canInvokeAgent(
  sourceAgent: string,
  targetAgent: string
): boolean {
  const allowed = AGENT_INVOCATION_MAP[sourceAgent.toLowerCase()] || [];
  return allowed.includes(targetAgent.toLowerCase());
}

export function formatCrossAgentContext(
  sourceAgent: string,
  targetAgent: string,
  context: string,
  question: string
): string {
  return `
## CROSS-AGENT CONSULTATION

You are being consulted by the **${sourceAgent}** agent.

**CONTEXT FROM ${sourceAgent.toUpperCase()}:**
${context}

**QUESTION/REQUEST:**
${question}

---

Provide your analysis from your specialized perspective. Be concise since your response will be incorporated into the ${sourceAgent}'s reply.
`;
}

export interface InvocationContext {
  chain: string[];
  maxDepth: number;
}

export function canContinueInvocation(
  ctx: InvocationContext,
  targetAgent: string
): boolean {
  if (ctx.chain.includes(targetAgent)) return false;
  if (ctx.chain.length >= ctx.maxDepth) return false;
  return true;
}

/**
 * Load user profile from config/profile.md for agent context.
 * Returns empty string if no profile exists.
 */
async function loadUserProfile(): Promise<string> {
  try {
    const profilePath = join(process.cwd(), "config", "profile.md");
    return await readFile(profilePath, "utf-8");
  } catch {
    return "";
  }
}

// Cached profile (loaded once)
let _userProfile: string | null = null;

export async function getUserProfile(): Promise<string> {
  if (_userProfile === null) {
    _userProfile = await loadUserProfile();
  }
  return _userProfile;
}

// Base context shared by all agents
export const BASE_CONTEXT = `
You are an AI assistant operating as part of a multi-agent system.
Each agent specializes in a different domain.

CORE IDENTITY:
- You operate as part of an AI Second Brain system
- You have access to memory, tools, and skills
- You speak in first person ("I recommend..." not "the bot recommends...")

COMMUNICATION:
- Keep responses concise (Telegram-friendly)
- Be direct, no fluff
`;

// User context placeholder - populated from config/profile.md at runtime
export const USER_CONTEXT_PLACEHOLDER = `
{{USER_CONTEXT}}
`;
