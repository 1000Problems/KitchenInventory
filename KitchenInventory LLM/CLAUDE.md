# CLAUDE.md

## Project

KitchenInventory LLM — iOS kitchen inventory app. AI assistant IS the product. Voice-first input, agentic tool-calling, SwiftData local persistence.

## Architecture

- **Swift 6** strict concurrency: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- **SwiftData** for persistence: InventoryItem, PurchaseHistory, ChatMessage, UserSettings
- **Claude API**: Haiku for voice parsing (~1-2s), Sonnet for chat tool loop
- **SpeechService**: actor with SFSpeechRecognizer + AVAudioEngine, chains sessions at ~1 min limit
- **Xcode PBXFileSystemSynchronizedRootGroup**: auto-discovers new files, no pbxproj edits needed

## Key Files

- `Views/MicTabView.swift` — Record tab, auto-starts recording on appear, inline recording UI
- `Views/AI/AIView.swift` — Chat tab with agentic tool-calling loop, mic for speech-to-chat
- `Views/AI/AIViewModel.swift` — Shared ViewModel owned by MainTabView, voice + chat state
- `Views/AI/VoiceConfirmationView.swift` — Review parsed items before adding to inventory
- `Views/Kitchen/KitchenView.swift` — Dashboard: Just Added, Expiring Soon, Storage cards, Recently Added
- `Views/Kitchen/StorageDetailView.swift` — Drill-down by storage location with expand/collapse all
- `Views/Kitchen/UniversalItemRow.swift` — Single expandable item component used everywhere
- `Services/VoiceItemParser.swift` — Sends transcript to Claude with today's date, returns absolute dates
- `Services/AppColors.swift` — Full color palette (baby blue accent #A7D3F0)
- `Services/ToolRegistry.swift` — Agentic tools: getInventory, removeItems, moveItems, addItems, etc.
- `Models/ParsedItem.swift` — Voice-parsed item with absolute expirationDate and purchaseDate

## Design System
Always read DESIGN.md before making any visual or UI decisions.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match DESIGN.md.

## Voice Input Formats
Two supported formats — AI prompt includes today's date for absolute date calculation:
1. Purchase: "I bought milk today" / "I got chicken last week"
2. Expiration: "I have milk that expires April 7th" / "Yogurt expiring tomorrow"

## Tab Structure
0. Record (default) — auto-recording mic, voice-to-inventory pipeline
1. AI — chat with agentic assistant, speech-to-chat mic
2. Kitchen — dashboard with inventory overview
3. Settings — API key, reset

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health

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
