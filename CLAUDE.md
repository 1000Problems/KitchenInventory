# KitchenInventory LLM

iOS kitchen inventory app. AI assistant IS the product. Voice-first input, agentic tool-calling, SwiftData local persistence.

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
