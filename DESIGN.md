# Design System — KitchenInventory LLM

## Product Context
- **What this is:** AI-first kitchen inventory app. Voice input, agentic tool-calling, expiration tracking.
- **Who it's for:** Home cooks who want to reduce food waste and know what's in their kitchen.
- **Space/industry:** Kitchen management, food tracking. Competitors: KitchenPal, CozZo, Fridge Hero, Pantry Check.
- **Project type:** iOS native app (SwiftUI, SwiftData)

## Aesthetic Direction
- **Direction:** Organic/Natural
- **Decoration level:** Intentional — subtle warmth in surfaces, not flat gray everywhere.
- **Mood:** Warm, approachable, feels like home. Not sterile tech. The app should feel like a place you'd actually cook in.
- **Reference sites:** KitchenPal, CozZo, Dribbble food inventory designs. Research showed the space converges on cold blues/grays. Our warm palette is a deliberate departure.

## Typography
- **Display/Hero:** SF Pro Display — native iOS, consistent with workout app portfolio
- **Body:** SF Pro Text — optimized for readability at small sizes
- **UI/Labels:** Same as body
- **Data/Tables:** SF Pro with tabular-nums feature
- **Code:** SF Mono
- **Loading:** System fonts, no CDN needed
- **Scale:** iOS Dynamic Type (title: 28pt, headline: 17pt, body: 17pt, subheadline: 15pt, caption: 12pt, caption2: 11pt)

## Color
- **Approach:** Balanced — warm accent replaces cold blue. Earth tones for depth.

### Light Mode
| Token | Hex | Usage |
|-------|-----|-------|
| appBg | #FAF8F5 | Warm off-white background |
| surface1 | #FFFFFF | Cards, sheets |
| surface2 | #F5F0EB | Secondary surfaces, date chips |
| surface3 | #EBE5DE | Tertiary surfaces |
| border | #DDD5CC | Card borders, dividers |
| textPrimary | #2C2C2E | Main text |
| textSecondary | #636366 | Secondary labels |
| textMuted | #8E8E93 | Hints, placeholders, unchecked circles |
| accent | #E8722A | Primary action, selected tab, FAB |
| success | #34C759 | Checkmarks, positive states |
| warning | #E8A030 | Expiring soon badges |
| error | #FF3B30 | Expired, destructive actions |
| appPurple | #7B8EC2 | Freezer color, "Freeze it" button |
| gold | #FFCC00 | Badges, highlights |

### Dark Mode
| Token | Hex | Usage |
|-------|-----|-------|
| appBg | #0A0A0A | True black background |
| surface1 | #1C1C1E | Cards, sheets |
| surface2 | #2C2824 | Warm-tinted secondary surfaces |
| surface3 | #3A3530 | Warm-tinted tertiary surfaces |
| border | #3A3530 | Card borders |
| textPrimary | #FFFFFF | Main text |
| textSecondary | #ABABAF | Secondary labels |
| textMuted | #636366 | Hints, placeholders |
| accent | #F08040 | Primary action (brighter for dark bg) |
| success | #30D158 | Checkmarks |
| warning | #F0A830 | Warning badges |
| error | #FF453A | Error states |
| appPurple | #8B9ED2 | Freezer (brighter for dark bg) |
| gold | #FFD60A | Badges |

### Storage Location Colors
| Location | Light | Dark | Background (12% opacity) |
|----------|-------|------|--------------------------|
| Pantry | #D4A853 | #E0B860 | pantry color @ 0.12 |
| Fridge | #4A9B8E | #5AABA0 | fridge color @ 0.12 |
| Freezer | #7B8EC2 | #8B9ED2 | freezer color @ 0.12 |

### Semantic Colors
- Success: green (already correct)
- Warning: warm amber (not stock orange)
- Error: red (already correct)
- Info: accent color

## Spacing
- **Base unit:** 4px (inherited from workout app)
- **Density:** Comfortable
- **Scale:** 2xs(2) xs(4) sm(8) md(16) lg(24) xl(32) 2xl(48) 3xl(64)

## Layout
- **Approach:** Card-based (matches workout app portfolio)
- **Grid:** Single column, full-width cards with 16px horizontal padding
- **Max content width:** Device width (iOS native)
- **Border radius:** sm:7px (icons), md:10px (date chips), lg:14px (cards), full:9999px (pills, capsules, FAB)

## Motion
- **Approach:** Minimal-functional
- **Easing:** enter(ease-out) exit(ease-in) move(ease-in-out)
- **Duration:** micro(0.15s) short(0.2s) medium(0.25s) long(0.3s)
- **Reduce motion:** Respects `accessibilityReduceMotion`, falls back to opacity-only transitions

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-03 | Initial design system created | Created by /design-consultation based on competitive research in kitchen/food app space |
| 2026-04-03 | Warm orange accent (#E8722A) over cold blue (#4A6CF7) | Research showed every competitor uses cold blue/gray. Warm orange evokes food, appetite, kitchen warmth. Differentiates from workout app while keeping structural consistency. |
| 2026-04-03 | Warm off-white bg (#FAF8F5) over cold gray (#F5F5F7) | Subtle shift that changes the entire feel from "tech dashboard" to "kitchen space" |
| 2026-04-03 | Teal-green fridge (#4A9B8E) over stock blue | Cooler tone for fridge makes semantic sense (cold storage) without being the same blue as the old accent |
| 2026-04-03 | Warm gold pantry (#D4A853) over stock orange | Warmer, more refined than the old warning-orange. Evokes dry goods, wood shelves. |
