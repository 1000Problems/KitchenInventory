# KitchenInventory — Development Plan

## Overview
iOS kitchen inventory app where the AI assistant IS the product. Talk to your kitchen → AI parses items → tracks inventory with expiration dates and storage locations. Agentic AI assistant for queries, recipes, and inventory management. Voice-first input: open your fridge, describe what's inside.

**Core thesis:** The AI chat that knows your kitchen is the value proposition. Inventory tracking and receipt scanning exist to feed the AI, not the other way around.

**Target:** App Store approval on first submission.

---

## Architecture Decisions

```
DATA FLOW
═══════════════════════════════════════════════════

Phase 1A: AI Chat + Manual Add
───────────────────────────────
User Input (text)
    │
    ▼
AIView.swift ──→ KitchenPromptBuilder.swift
    │                   │
    │                   ▼
    │            System prompt + inventory summary
    │            (counts + top 10 expiring)
    │            + tool definitions + last 5 messages
    │                   │
    ▼                   ▼
LLMService protocol ──→ ClaudeAPIService (claude-haiku-4-5)
    │                    (future: LocalModelService via HuggingFace)
    │
    ├── text response ──→ display in chat
    │
    └── tool_use blocks
            │
            ▼
    Tool-call loop (method on ClaudeAPIService, max 5 iterations)
            │
            ▼
    ToolRegistry (self-contained tool structs)
            │
            ▼
    SwiftData (background ModelContext)
            │
            └── result ──→ back to Claude ──→ loop or final text
                          (@Query auto-refreshes views)

Phase 1B: Voice Input Pipeline
───────────────────────────────
Microphone (AVAudioEngine)
    │
    ▼
SpeechService.swift (SFSpeechRecognizer, on-device)
    │
    ▼
Partial transcription stream → text field (real-time)
    │
    ▼
Final text → existing chat pipeline
    │
    ▼
ClaudeAPIService (claude-haiku-4-5) + add_items tool
    │
    ▼
SwiftData (InventoryItem insert via ToolRegistry)
    │
    └── AI confirms: "Added X, Y, Z. Sound right?" + undo toast
```

### Key Decisions (from eng review)
1. **Phase 1 split into 1A/1B** — 1A ships AI chat + manual add. 1B layers voice input pipeline.
2. **LLMService protocol** — Both ClaudeAPIService and future LocalModelService conform. Views don't know which backend they're talking to.
3. **Single ClaudeAPIService actor** — Takes model parameter per request (haiku for chat, sonnet for future receipt parsing). Tool-call loop is a method on this actor, not a separate file.
4. **ToolRegistry pattern** — Each tool is a self-contained struct conforming to Tool protocol: name, jsonSchema, execute(context:params:). One place to add a tool.
5. **Actor isolation** — ToolExecutor uses background ModelContext for SwiftData writes. SwiftUI views use @Query which auto-refreshes via SwiftData notifications. No main thread blocking.
6. **Conversation history: 5 messages** — Designed for future local model constraints. Keeps token cost low.
7. **Prompt summarization** — KitchenPromptBuilder includes item counts per location + top 10 expiring items. AI uses get_inventory tool for detail.

### Error Handling

```swift
enum KitchenError: Error {
    case noAPIKey          // → show API key setup screen
    case networkUnavailable // → "No internet connection. Try again when online."
    case apiError(Int, String) // → status-specific: 401="Invalid API key", 429="Too many requests, wait a moment", 500="Service temporarily unavailable"
    case parseError        // → "Couldn't understand the response. Try again."
    case speechUnavailable  // → "Speech recognition isn't available. You can still type to add items."
    case microphoneDenied   // → "Microphone access needed. Enable in Settings > Privacy > Microphone."
}
```

### Tool Confirmation Tiers

| Tool | Tier | Behavior |
|------|------|----------|
| get_inventory | Silent | Read-only, no UI feedback |
| get_purchase_history | Silent | Read-only, no UI feedback |
| add_items | Undo toast | Immediate action + "Added 3 items. Undo?" |
| move_items | Undo toast | Immediate + "Moved milk to freezer. Undo?" |
| update_expiration | Undo toast | Immediate + "Updated expiration. Undo?" |
| consume_items | Undo toast | Immediate + "Used 2 eggs. Undo?" |
| remove_items (1-2) | Undo toast | Immediate + "Removed expired milk. Undo?" |
| remove_items (3+) | Confirmation card | "Remove 12 expired items?" [Confirm] [Cancel] |

---

## Design Specs (from design review)

### Navigation & Defaults
- **Default tab:** AI tab (tag 0). The AI IS the product. First-time users land here.
- **Tab bar:** 2 tabs — AI (sparkles icon) + Kitchen (refrigerator.fill icon)
- **Voice input button:** Mic button on AI tab input bar. Kitchen tab: mic icon in nav bar for quick voice add.
- **Scan receipt button (Post-MVP):** Camera-based receipt scanning deferred to Phase 5.

### AI Tab Layout — Action-First (not conversation-first)
```
┌────────────────────────────────────┐
│  AI Assistant                  ⚙️  │  ← nav bar
│                                    │
│  "Why did the tomato turn red?     │
│   Because it saw the salad         │
│   dressing!"                       │  ← dad joke card (textMuted, small)
│                                    │
│  ┌──────────────────────────────┐  │
│  │  🔍 What's expiring?        │  │  ← BIG action chips
│  └──────────────────────────────┘  │     (surface1 bg, accent border,
│  ┌──────────────────────────────┐  │      20pt pill corners)
│  │  🍳 Recipe ideas            │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  ➕ Add items               │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  🛒 What can I cook?        │  │
│  └──────────────────────────────┘  │
│                                    │
│  ┌──────────────────────────────┐  │
│  │  Ask me anything...      ➤  │  │  ← text input (bottom)
│  └──────────────────────────────┘  │
└────────────────────────────────────┘
```
- After first message, chips collapse to horizontal scroll row above input
- Chat area fills the space between joke and input
- Action chips are the PRIMARY interaction (80% of users tap, 20% type)

### Component Spec Table

| Component | Background | Text Color | Border | Corners | Shadow |
|-----------|-----------|------------|--------|---------|--------|
| User chat bubble | accent (#4a6cf7) | white | none | 16pt (top-right: 4pt) | none |
| AI chat bubble | surface1 (#ffffff) | textPrimary (#1c1c1e) | border (#d1d1d6) 0.5pt | 14pt (top-left: 4pt) | subtle (0,1,3,0.08) |
| Action chip (big) | surface1 | textPrimary | accent 1.5pt | 20pt pill | none |
| Action chip (small/collapsed) | surface2 (#f0f0f3) | textSecondary | none | 16pt pill | none |
| Dad joke card | surface2 | textMuted (#8e8e93) | none | 12pt | none |
| Undo toast | textPrimary (#1c1c1e) | white | none | 24pt pill | medium |
| Confirmation card | surface1 | textPrimary | border 0.5pt | 14pt | subtle |
| Storage chip | storageColor bg (10% opacity) | storageColor | none | 8pt pill | none |
| Date strip date (normal) | transparent | textSecondary | none | 8pt | none |
| Date strip date (selected) | accent | white | none | 8pt | none |
| Date strip date (AI suggested) | success (10% opacity) | success (#34c759) | none | 8pt | none |
| Expiring chip (safe) | success (10% opacity) | success | none | 6pt | none |
| Expiring chip (warning) | warning (10% opacity) | warning (#ff9500) | none | 6pt | none |
| Expiring chip (danger) | error (10% opacity) | error (#ff3b30) | none | 6pt | none |

### Dark Mode Tokens
| Token | Light | Dark |
|-------|-------|------|
| surface1 | #ffffff | #1c1c1e |
| surface2 | #f0f0f3 | #2c2c2e |
| textPrimary | #1c1c1e | #ffffff |
| textSecondary | #6c6c70 | #ababaf |
| textMuted | #8e8e93 | #636366 |
| border | #d1d1d6 | #38383a |
| accent | #4a6cf7 | #5a7cf7 |
| success | #34c759 | #30d158 |
| warning | #ff9500 | #ff9f0a |
| error | #ff3b30 | #ff453a |

### AI Response Formatting
- **Inventory data:** Structured mini-cards within chat bubble. Each item = compact row with storage colored dot + name + expiration chip. Tappable for actions.
- **Recipes:** Markdown-style. Bold ingredients, numbered steps. Rendered with AttributedString.
- **Confirmations:** Inline card in chat (not system alert). White card, description, item count, [Confirm] accent button + [Cancel] text button.
- **Max bubble width:** 80% of screen width
- **AI voice:** Brief, specific kitchen friend. Not "I'd be happy to help!" Just "4 items expiring by Friday. Want a recipe using the chicken and broccoli?"

### Interaction States

| Feature | Loading | Empty | Error | Success |
|---------|---------|-------|-------|---------|
| AI Chat | Animated dots in AI bubble + new joke | Action-first layout IS empty state (chips + joke) | KitchenError-specific message in red card | Response appears in chat |
| Voice input | Pulsing mic icon + partial transcription in text field | Mic button on input bar (idle state) | "Couldn't hear you. Try again in a quieter spot." + [Try Again] | Transcribed text sends as chat message |
| Dashboard | n/a (SwiftData instant) | "Your kitchen is empty! Tell me what's in your fridge or type to add items." + illustration + [Voice Add] [Type] | n/a | n/a |
| Storage drill-down | n/a | "No items in your [Fridge] yet." + [Add via Voice] | n/a | n/a |
| Quick-add | n/a | No chips (just text input with placeholder) | Toast: "Couldn't add item" | Undo toast: "Added eggs. Undo?" |

### Undo Toast Behavior
- Appears at bottom center, dark pill (#1c1c1e), white text, 24pt corners
- "Added 3 items. Undo?" with tappable "Undo" text in accent color
- Auto-dismisses after 5 seconds with fade animation
- Tap anywhere outside = dismiss immediately
- Tap "Undo" = reverse action + brief "Undone" toast (2 seconds)
- Respects `UIAccessibility.isReduceMotionEnabled` (no animation, instant show/hide)

### Accessibility Requirements
- **Touch targets:** 44pt minimum on all interactive elements (Apple HIG)
- **Dynamic Type:** All text uses system text styles (.body, .headline, .caption) that scale
- **VoiceOver labels:** Every interactive element labeled. Chat messages announce role ("AI: ...", "You: ...")
- **Date strip a11y:** Each date = separate button. Label: "April 9, Tuesday". Selected: "Selected". AI suggested: "Suggested by AI"
- **Color contrast:** Verify warning orange (#ff9500) on white passes WCAG AA (may need darkened variant for text)
- **Reduce Motion:** Typing dots and toast animations respect system setting

---

## Phase 1A — AI Chat + Manual Input

### 1A.1 SwiftData Models
- `InventoryItem` — name, category, storageLocation (enum: pantry/fridge/freezer), purchaseDate, estimatedExpiration, userExpiration, quantity, unit, isConsumed
- `PurchaseHistory` — canonical item name, purchaseCount, lastPurchaseDate, preferredStorage, averageExpirationDays, category, isDismissed
- `ChatMessage` — role, content, timestamp
- `UserSettings` — apiKey reference, onboardingComplete, preferredUnits
- Register all models in `KitchenInventory_LLMApp.swift` schema
- **Deferred:** `Receipt` model moves to Phase 5 (receipt scanning post-MVP)

### 1A.2 Services
- `DateHelper.swift` — Pacific timezone helpers, date formatting (carry from RubberJoints)
- `AppColors.swift` — Already done
- `KeychainHelper.swift` — Secure API key storage (carry from RubberJoints)
- `KitchenJokes.swift` — Already done (move into project from /mnt/IOS Kitchen Inventory/)
- `LLMService.swift` — Protocol: sendMessage(messages:tools:model:) async throws -> LLMResponse
- `ClaudeAPIService.swift` — Actor conforming to LLMService. HTTP client for Claude API. Tool-call loop as method (max 5 iterations). Model param per request.
- `KitchenPromptBuilder.swift` — Assembles system prompt: AI personality, item counts per location, top 10 expiring items, current date. Conversation history: last 5 messages.
- `ToolRegistry.swift` — Tool protocol + 7 tool structs (get_inventory, remove_items, move_items, update_expiration, add_items, consume_items, get_purchase_history). Each struct has name, jsonSchema, execute().

### 1A.3 Agentic AI Chat
- `AIView.swift` — Action-first layout per design spec (big chips → collapses to horizontal scroll after first message)
- Dad joke display: one joke on load, rotates on each interaction (textMuted, small, surface2 card)
- Action chips: "What's expiring?", "Recipe ideas", "Add items", "What can I cook?" — big pills, accent border
- **Smart empty state:** When inventory has 0 items, show "Add items" chip prominently. Other chips dimmed with "(add items first)" subtitle. Prevents confusion on first launch.
- After first message: chips collapse to small horizontal scroll above input
- AI responses: structured mini-cards for inventory data, markdown for recipes, inline confirmation cards for destructive actions
- Chat bubbles: user = accent bg right-aligned, AI = surface1 left-aligned (per component spec table)
- Typing indicator: animated dots in AI bubble + new joke appears
- Max bubble width: 80% of screen width
- Confirmation tiers as specified above
- Use `claude-haiku-4-5` for chat (speed + cost)

### 1A.4 Quick-Add Mode
- "+" button on dashboard → opens AI tab with focused input field
- Purchase history chips shown (sorted by frequency x recency, local data only)
- Single chip tap → instant add with learned defaults + undo toast
- Natural language bulk entry: "eggs, milk, bread → fridge" (requires API)

### 1A.5 Tests (ship with Phase 1A)
- **Models:** InventoryItem init, isExpired edge cases, storageLocation enum encoding
- **ToolRegistry:** Each tool's execute() with valid/invalid inputs, empty inventory
- **KitchenPromptBuilder:** System prompt assembly, empty inventory, conversation truncation
- **ClaudeAPIService:** Mock URLProtocol tests for all KitchenError cases
- **Tool-call loop:** Single call, multi-chain, max iterations, mid-chain error
- **KeychainHelper:** Save, retrieve, delete API key

### 1A.6 Build Verification
- Build in Xcode, fix all errors and warnings
- Manual add → query AI → tool fires → response displayed
- Test all 7 tools via chat commands
- Test error states: no API key, network off, invalid key
- Commit + push

---

## Phase 1B — Voice Input Pipeline

### 1B.1 SpeechService
- `SpeechService.swift` — Actor wrapping `SFSpeechRecognizer` + `AVAudioEngine`
  - `startListening() async throws -> AsyncStream<String>` — streams partial transcriptions
  - `stopListening()` — ends recording, returns final transcription
  - `requestPermissions() async -> Bool` — handles both microphone + speech recognition auth
  - On-device recognition preferred (`requiresOnDeviceRecognition = true`). If on-device model unavailable (older device, language model not downloaded), fall back to server-based recognition with a brief "Using cloud speech recognition" note. If both unavailable, throw `KitchenError.speechUnavailable` with graceful fallback to typing.
  - Locale: `.current` with fallback to `en-US`
  - Auto-stop after 2 seconds of silence (configurable via `silenceTimeout`)
- **Audio session configuration:**
  - `AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.duckOthers, .defaultToSpeaker])`
  - Ducks any playing audio (music, podcasts) during recording, restores after
  - Deactivate audio session on `stopListening()` to release audio focus
- Info.plist keys:
  - `NSMicrophoneUsageDescription` — "KitchenInventory uses your microphone so you can add items by voice."
  - `NSSpeechRecognitionUsageDescription` — "KitchenInventory uses speech recognition to understand what items you're adding."
- Error cases already in `KitchenError`: `speechUnavailable`, `microphoneDenied`

### 1B.2 Voice UI on AI Tab
- Mic button added to input bar (next to send button)
  - Mic icon: `mic.fill` when idle, `mic.circle.fill` with pulsing animation when recording
  - Tap to start recording, tap again to stop (or auto-stops on silence)
  - Partial transcription streams into the text field in real-time so user sees what's being recognized
  - On stop: final text sends as a normal chat message through existing pipeline
- **Silence timeout visual feedback:**
  - While speech detected: pulsing mic animation (accent color)
  - Silence begins: mic animation transitions to a shrinking ring (1.5s visual countdown)
  - At 2s silence: ring disappears, mic stops, text sends
  - User can tap mic to cancel during countdown
  - Respects `UIAccessibility.isReduceMotionEnabled` — use opacity fade instead of ring animation
- Recording indicator: pulsing red dot in nav bar while active
- Permission flow:
  - First tap → system permission dialogs (microphone, then speech recognition)
  - If denied → show inline card: "Microphone access needed" with [Open Settings] button
- **Progressive fallback:** After 2 consecutive voice failures (silence timeout or no speech detected), show inline suggestion: "Having trouble? Try typing instead" with keyboard auto-focus on text field
- Accessibility: VoiceOver announces "Start voice input" / "Stop recording"

### 1B.3 Voice-Optimized AI Behavior
- No new Claude tools needed — existing `add_items` tool handles everything
- KitchenPromptBuilder updated to handle voice-style input:
  - System prompt addition: "User may speak naturally about their kitchen items. Parse spoken descriptions like 'I have milk, a dozen eggs, some chicken I bought yesterday' into structured inventory additions. Infer storage locations, quantities, and estimate purchase/expiration dates from context clues like 'bought yesterday' or 'just got'."
- AI confirms additions conversationally: "Added milk, 12 eggs, and chicken to your fridge. Chicken expires around April 5th. Sound right?" (with undo toast)
- Handles follow-up corrections naturally: "Actually move the eggs to the pantry" → `move_items` tool fires

### 1B.4 Tests (ship with Phase 1B)
- **SpeechService:** Permission state handling (authorized, denied, restricted), start/stop lifecycle
- **Voice input integration:** Simulated text (as if from speech) → sent through chat → `add_items` tool fires → items in SwiftData
- **Prompt coverage:** Test voice-style inputs: "I have X", "Just bought X", "X and Y go in the freezer", "A dozen X"
- **Error states:** Microphone denied, speech recognition unavailable, no speech detected (silence timeout)
- **UI:** Mic button state transitions (idle → recording → sending), permission denial card

### 1B.5 Build Verification
- Test on physical device (microphone not available in Simulator)
- Speak 5+ natural inventory descriptions, verify correct items added
- Test silence auto-stop behavior
- Test permission denial and recovery flow
- Test while AI tab has existing conversation (voice input mid-chat)
- Commit + push

### Future (Post-MVP)
- **Receipt scanning:** Camera → OCR → AI parsing (original 1B plan, repurposed as Phase 5)
- **Fridge photo:** Take a picture of fridge contents → Vision API identifies items → AI adds to inventory
- **Continuous listening mode:** Optional always-on mode while app is foregrounded (with privacy indicator)

---

## Phase 2 — Dashboard + Drill-Down Views

### 2.1 Kitchen Dashboard (KitchenView)
- "Expiring Soon" section — top 5 items, color-coded (green/yellow/red)
- Three storage cards: Pantry, Fridge, Freezer with item count + health badge
- "Recently Added" row showing last receipt scan summary
- Floating "+" button → navigates to AI tab in quick-add mode
- Search bar at top (SwiftData `#Predicate` filtering)

### 2.2 Storage Drill-Down Views
- `StorageDetailView` — shows items grouped by category (Dairy, Produce, Meats, etc.)
- Collapsible category headers with colored dot, label, count, expiring badge
- Compact item rows: name, expiration chip (color-coded), quantity
- Swipe left to delete (consumed/tossed), swipe right to move storage location
- Search bar filtering within location

### 2.3 Tests (ship with Phase 2)
- **Dashboard:** Expiring items sort order, storage card counts, empty state
- **Drill-down:** Category grouping, swipe actions, search filtering
- **UI tests:** Dashboard → Drill-down → Back navigation

### 2.4 Build Verification
- Test navigation flow end-to-end
- Test with 0 items, 10 items, 100+ items
- Test search across all views
- Commit + push

---

## Phase 3 — Memory + Learning System

### 3.1 Purchase History Intelligence
- On every item entering inventory (any path: voice, manual, or future receipt scan): upsert PurchaseHistory record
- Track: purchase count, last date, preferred storage, average expiration days
- Name normalization: AI maps voice/text input to existing canonical names (e.g. "some chicken" → "Chicken")
- DismissedItems: auto-suppress after 3 dismissals from AI suggestions

### 3.2 Expiration Learning
- Store both `estimatedExpiration` (AI) and `userExpiration` (user's correction) on InventoryItem
- `ExpirationLearner.swift` — computes running average of user corrections per item
- Future additions use learned expiration instead of AI default when available

### 3.3 Quick-Add Ranking
- Score = (purchaseCount x recencyWeight)
- RecencyWeight decays over time (items not bought in 30+ days sink)
- Top 8-10 items shown as chips

### 3.4 Tests (ship with Phase 3)
- **PurchaseHistory:** Upsert logic, dismissal threshold, name normalization
- **ExpirationLearner:** Running average calculation, preference over AI default
- **Quick-Add Ranking:** Score calculation, recency decay, chip ordering

### 3.5 Build Verification
- Add same items multiple times (voice + manual) → verify PurchaseHistory updates
- Correct expiration dates → verify learning kicks in on next addition
- Commit + push

---

## Phase 4 — Polish + App Store Readiness

### 4.1 Settings View
- `SettingsView.swift` — API key entry (secure, via Keychain)
- API connection status indicator
- About section, version info
- Privacy notice (all data stored on-device)
- Clear data option

### 4.2 Onboarding
- First-launch welcome screen explaining the app
- Microphone + Speech Recognition permission request with clear explanation
- Optional API key setup (app works with local model without it)
- Brief walkthrough of voice → AI adds items → manage flow

### 4.3 App Store Compliance
- **Privacy:** No data collection, no tracking, no analytics (clean privacy nutrition label)
- **Microphone usage:** Clear `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` strings
- **Network:** Only outbound HTTPS to Anthropic API, no other network calls
- **No web views, no external sign-in, no subscriptions** in v1
- **Content:** No user-generated public content
- **Age rating:** 4+ (no objectionable content)
- **Local model fallback:** App works fully without Claude API via on-device Hugging Face model. Manual add, inventory management, camera scan with OCR all functional offline.

### 4.4 UI Polish
- App icon design
- Launch screen
- Empty states for all views (no items yet, no receipts yet)
- Error states (network failure, OCR failure, API error) per KitchenError enum
- Haptic feedback on key interactions (item check, swipe delete)
- Dark mode support using semantic colors
- Dynamic Type support
- VoiceOver accessibility labels on all interactive elements

### 4.5 Final Testing
- Test on multiple device sizes (iPhone SE, iPhone 15 Pro, iPad)
- Test offline mode end-to-end (local model only)
- Test with 100+ inventory items for performance
- Full regression pass across all phases

### 4.6 Final Submission Prep
- App Store screenshots (6.7" and 6.1" required)
- App description and keywords
- Privacy policy URL (required)
- Support URL (required)
- TestFlight beta testing round
- Archive + submit via Xcode

---

## What Already Exists

| File | Status |
|------|--------|
| **Models/** | |
| StorageLocation.swift | Done (Phase 1A). Enum: pantry/fridge/freezer |
| InventoryItem.swift | Done (Phase 1A). Core SwiftData model |
| PurchaseHistory.swift | Done (Phase 1A). Frequency/recency ranking |
| ChatMessage.swift | Done (Phase 1A). SwiftData chat persistence |
| UserSettings.swift | Done (Phase 1A). Onboarding + preferences |
| **Services/** | |
| AppColors.swift | Done. Full color palette + storageColor() |
| ClaudeAPIService.swift | Done (Phase 1A). Actor + tool-call loop |
| LLMService.swift | Done (Phase 1A). Protocol + types |
| ToolRegistry.swift | Done (Phase 1A). 7 tools |
| KitchenPromptBuilder.swift | Done (Phase 1A). System prompt + inventory summary |
| KeychainHelper.swift | Done (Phase 1A). Secure API key storage |
| KitchenError.swift | Done (Phase 1A). Error enum |
| DateHelper.swift | Done (Phase 1A). Pacific timezone helpers |
| KitchenJokes.swift | Done (Phase 1A). 200 dad jokes |
| **Views/** | |
| MainTabView.swift | Done (Phase 1A). AI default tab |
| AIView.swift | Done (Phase 1A). Action-first layout + chat |
| AIViewModel.swift | Done (Phase 1A). Chat orchestration |
| KitchenView.swift | Placeholder (to be replaced in Phase 2) |
| ContentView.swift | Done. Loads MainTabView |
| KitchenInventory_LLMApp.swift | Done (Phase 1A). All models registered |

## NOT in Scope

| Item | Rationale |
|------|-----------|
| Cloud sync / iCloud | Local-only in v1. Validates product thesis without sync complexity. |
| Subscriptions / payments | v1 is free. Monetization after retention is proven. |
| Social features / sharing | Single-user app. Sharing adds privacy complexity. |
| Barcode scanning | Voice is the wedge. Barcode adds scanning UX complexity for MVP. |
| Meal planning / calendar | Outside core loop. Could be Phase 5+. |
| Multi-language receipt support | English-only in v1. Reduces OCR/parsing edge cases. |
| iPad-optimized layout | iPhone-first. iPad works but no split-view optimization. |
| Offline quick-add NLP | Deferred until local Hugging Face model ships. Purchase history chips work offline. |

## Phase Summary

| Phase | Focus | Deliverable |
|-------|-------|-------------|
| 1A | AI Chat + Manual Input | SwiftData models, LLMService protocol, ClaudeAPIService actor, ToolRegistry (7 tools), AI chat, quick-add, tests |
| 1B | Voice Input | SpeechService, mic button on AI tab, voice-optimized prompts, tests |
| 2 | Dashboard + Views | Glanceable dashboard, storage drill-downs, search, tests |
| 3 | Memory + Learning | Purchase history intelligence, expiration learning, smart ranking, tests |
| 4 | App Store | Settings, onboarding, local model integration, polish, final testing, submission |

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | issues_found | 5 premises evaluated, API key resolved (local HF model), voice pivot validated |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | unavailable | Codex not available in this environment |
| Eng Review | `/plan-eng-review` | Architecture & tests | 2 | issues_found | 5 critical code fixes, 4 high-priority, 15 new test cases |
| Design Review | `/plan-design-review` | UI/UX gaps | 2 | issues_found | 7 dimensions rated 7.4/10, smart chips, dark mode tokens, voice fallback |
| Outside Voice | Claude subagent | Independent challenge | 2 | issues_found | 10 strategic findings, local model strategy confirmed |

### Eng Review Decisions
1. Phase 1 split into 1A (AI chat) + 1B (voice input) — **accepted** (updated: receipt scanning deferred to post-MVP)
2. Single ClaudeAPIService actor with model param — **accepted**
3. Tool-call loop as method on actor (not separate file) — **accepted**
4. LLMService protocol for future local model — **accepted**
5. ToolExecutor background ModelContext + @Query auto-refresh — **accepted**
6. Keep prompt builders separate (no shared base) — **accepted**
7. ToolRegistry pattern (self-contained tool structs) — **accepted**
8. KitchenError enum with per-error UX — **accepted**
9. Tests ship per phase — **accepted**
10. Prompt summarization (counts + top 10 expiring) — **accepted**
11. Tool confirmation tier mapping — **accepted**
12. 5-message conversation history limit — **accepted** (designed for future local model constraints)
13. Offline quick-add deferred until local model — **accepted**

### Design Review Decisions
1. AI tab action-first layout (big chips, not empty chatbot) — **accepted**
2. Animated dots + joke rotation for loading state — **accepted**
3. Navigate to dashboard after receipt confirmation (instant payoff) — **accepted**
4. AI tab as default tab (not Kitchen) — **accepted**
5. Voice/mic button prominent on AI tab — **accepted** (updated: replaced receipt scan button with mic)
6. Component spec table with specific tokens per component — **accepted**
7. Structured mini-cards for AI inventory responses (not plain text) — **accepted**
8. Individual buttons for date strip VoiceOver — **accepted**
9. AI voice: brief kitchen friend, not chatbot — **accepted**
10. Full interaction state table for all features — **accepted**

### Design Ratings (post-review)
| Dimension | Before | After |
|-----------|--------|-------|
| Information Architecture | 4 | 7 |
| Interaction States | 2 | 7 |
| User Journey | 3 | 7 |
| AI Slop Risk | 8 | 8 |
| Design System | 6 | 8 |
| Responsive/A11y | 4 | 7 |
| Unresolved Decisions | 3 | 8 |
| **Overall** | **5** | **7.4** |

### Autoplan Review (2026-04-02) — CEO + Design + Eng

**Strategic decisions:**
1. Claude API is for dev/testing ONLY. Production ships with Hugging Face on-device model. No API key for users.
2. 5-message conversation history CONFIRMED — designed for local model constraints.
3. Phase order (1A manual → 1B voice) CONFIRMED — validates pipeline before adding speech complexity.
4. Voice pivot over receipt scanning CONFIRMED — reuses 100% of existing tool pipeline.

**Code fixes required (before shipping 1A):**
1. Fix `daysFromNow` force unwrap → guard unwrap with error
2. Add quantity validation: `quantity > 0` in InventoryItem, AddItemsTool, ConsumeItems
3. Fix negative quantity in ConsumeItems: `max(0, item.quantity - consumeQty)`
4. Store Task handle in AIViewModel for cancellation on new send
5. Fix case-insensitive `contains` → exact match first, then fallback
6. Replace `try? modelContext.save()` with explicit error logging
7. Add 90-second aggregate timeout on tool-call loop
8. Guard purchase history upsert divide-by-zero (`purchaseCount > 0`)

**Design additions:**
1. Smart empty-state chips: when inventory is empty, show only "Add items" prominently, others dimmed
2. Voice progressive fallback: after 2 failed voice attempts, suggest typing with keyboard auto-focus
3. Model parsing fallback: if AI can't parse voice input, ask for clarification
4. Dark mode tokens: add dark mode column to component spec table
5. Add "search chat history" to Phase 4 polish backlog

**Test plan additions (Phase 1A.5):**
- Tool loop: non-KitchenError throws, empty results, max iterations
- Concurrency: rapid sends, task cancellation, race conditions
- Edge cases: negative quantity, floating point precision, duplicate names, nil expiration
- Error paths: network timeout, malformed JSON, database corruption

**VERDICT:** REVIEWED — plan validated with voice pivot confirmed. 8 code fixes and 5 design additions required before Phase 1A is complete. Architecture is sound. Local model strategy resolves API key friction. Ready for implementation.
