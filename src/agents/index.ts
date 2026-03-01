/**
 * Go - Multi-Agent System
 *
 * Agent configuration exports and utilities.
 *
 * Architecture:
 * - Each Telegram forum topic maps to a specialized agent
 * - Agents have distinct system prompts, reasoning styles, and tool access
 * - General topic (no thread_id) uses the default Orchestrator agent
 *
 * Usage:
 * 1. Create a Telegram group with forum topics enabled
 * 2. Add your bot as admin
 * 3. Map topic IDs to agent names in topicAgentMap (src/agents/base.ts)
 * 4. Messages in each topic will use that agent's configuration
 */

export type { AgentConfig, InvocationContext } from "./base";
export {
  BASE_CONTEXT,
  getAgentConfig,
  getAgentByTopicId,
  topicAgentMap,
  AGENT_INVOCATION_MAP,
  canInvokeAgent,
  formatCrossAgentContext,
  canContinueInvocation,
  getUserProfile,
} from "./base";

// Agent configurations
export { default as generalAgent } from "./general";
export { default as criticAgent } from "./critic";
export { default as softwareAgent } from "./software";
export { default as databaseAgent } from "./database";
export { default as bpDocsAgent } from "./bp-docs";
export { default as bpContractsAgent } from "./bp-contracts";
export { default as bpInvoicesAgent } from "./bp-invoices";
export { default as bpFinanceAgent } from "./bp-finance";

// Quick reference
export const AGENTS = {
  general: "General Agent - Default assistant, cross-agent orchestration",
  critic: "Critic Agent - Devil's advocate, stress-testing (internal, not topic-bound)",
  software: "Software Engineering Agent - Full-stack coding, debugging, DevOps, shipping (Systematic reasoning)",
  database: "Database Agent (Supabase) - Schema, queries, migrations, RLS, performance (CoT reasoning)",
  "bp-docs": "BP Documents Agent - bp document creation, reports, SOPs (CoT reasoning)",
  "bp-contracts": "BP Contracts Agent - MSAs, SOWs, vendor agreements, compliance (CoT reasoning)",
  "bp-invoices": "BP Invoices Agent - Invoice review, PO matching, discrepancy tracking (CoT reasoning)",
  "bp-finance": "BP Finance & Budgets Agent - Budget tracking, forecasting, cost analysis (CoT reasoning)",
};
