# KitchenInventory LLM

iOS kitchen inventory app. AI assistant IS the product. Voice-first input, agentic tool-calling, SwiftData local persistence.

## Before Implementing Any TASK

1. **Read the full TASK spec** — understand scope, acceptance criteria, and the Do Not Change section.
2. **Query LightRAG** for cross-project context before touching shared patterns:
   ```bash
   curl -X POST http://localhost:9621/query \
     -H "Content-Type: application/json" \
     -d '{"query": "architectural context for [feature being implemented]", "mode": "hybrid"}'
   ```
3. **Stay in scope.** Only modify files and components explicitly listed in the TASK spec. If you discover something that needs changing outside the spec, create a new VybePM task — do NOT fix it inline.
4. **Verify before committing.** Build in Xcode (Cmd+B), confirm zero warnings, and check that nothing outside the TASK scope changed with `git diff`.

### Protected Areas (global — TASK specs may add more)

These components are stable and must NOT be modified unless the TASK spec explicitly names them:

- `Services/SpeechService.swift` — Voice recognition pipeline. Ported to Vybe, proven stable.
- `Services/ClaudeAPIService.swift` — Agentic tool-calling client.
- `Services/KeychainHelper.swift` — Keychain storage.
- SwiftData model files — schema changes require migration planning, never alter existing properties.
- DESIGN.md — the visual source of truth. Do not deviate without explicit approval.

## Design System
Always read DESIGN.md before making any visual or UI decisions.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match DESIGN.md.

## gstack

Use the `/browse` skill from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools directly.

### Available gstack skills

/office-hours, /plan-ceo-review, /plan-eng-review, /plan-design-review, /design-consultation, /design-shotgun, /design-html, /review, /ship, /land-and-deploy, /canary, /benchmark, /browse, /connect-chrome, /qa, /qa-only, /design-review, /setup-browser-cookies, /setup-deploy, /retro, /investigate, /document-release, /codex, /cso, /autoplan, /careful, /freeze, /guard, /unfreeze, /gstack-upgrade, /learn

### Troubleshooting

If gstack skills aren't working, run:
```
cd .claude/skills/gstack && ./setup
```
This builds the binary and registers all skills.
