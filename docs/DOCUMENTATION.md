# Pocki — Full Documentation

**Version:** 1.0  
**Tagline:** Your money, simplified.  
**Platform:** iPhone · iOS 26+  
**License:** MIT  
**Author:** Amrit Kang

This document explains the product, architecture, data model, screens, services, and roadmap for Pocki end-to-end.

---

## Table of contents

1. [What is Pocki?](#1-what-is-pocki)
2. [What makes it unique](#2-what-makes-it-unique)
3. [MVP scope (v1)](#3-mvp-scope-v1)
4. [Tech stack](#4-tech-stack)
5. [Project structure](#5-project-structure)
6. [Architecture (MVVM)](#6-architecture-mvvm)
7. [Data models](#7-data-models)
8. [Persistence (SwiftData)](#8-persistence-swiftdata)
9. [Services](#9-services)
10. [ViewModels](#10-viewmodels)
11. [Screens & navigation](#11-screens--navigation)
12. [Reusable components](#12-reusable-components)
13. [Design system](#13-design-system)
14. [Budget system](#14-budget-system)
15. [Search](#15-search)
16. [Animations & haptics](#16-animations--haptics)
17. [How to run](#17-how-to-run)
18. [Privacy](#18-privacy)
19. [Roadmap & future architecture](#19-roadmap--future-architecture)
20. [Contributing guidelines](#20-contributing-guidelines)

---

## 1. What is Pocki?

Pocki is a **premium personal finance tracker for iPhone**.

The goal is not to be a feature-heavy banking app. The goal is an app people **enjoy opening every day** — simple, fast, beautiful, and native.

It helps answer one question clearly:

> How am I doing with my money this month?

---

## 2. What makes it unique

Most expense apps force you to type every purchase.

**Pocki’s core product idea:**

> People already screenshot every UPI payment.  
> Pocki turns that screenshot into a clean expense entry.

This is **not locked to Google Pay**. It is designed for **any UPI app**:

- Google Pay (GPay)
- PhonePe
- Paytm
- BHIM
- Amazon Pay
- Other UPI clients

```text
  Pay on any UPI app
          │
          ▼
  Screenshot (already a habit)
          │
          ▼
  Pocki OCR (roadmap)
          │
          ▼
  amount + merchant + date
          │
          ▼
  Insights · budget · history
```

**v1 ships manual tracking** with the data model already prepared for screenshot OCR (`source`, `isVerified`, `confidence`).

That unique loop is the north star of the product.

---

## 3. MVP scope (v1)

### Included

| Area | What ships |
| --- | --- |
| Tracking | Create, read, update, delete expenses manually |
| Home | Month spend, budget ring, today / week / average / remaining |
| Expenses | Search, date groups, swipe edit/delete, detail |
| Insights | Apple Charts — weekly, monthly, categories, merchants, trends |
| Settings | Monthly budget, currency, reset data, about |
| Design | Dark Mode, Dynamic Type, glass cards, haptics |

### Explicitly not in v1

- User accounts / authentication
- Cloud sync / backend
- OCR / screenshot import (architecture only)
- Google Pay / UPI API integration
- AI categorization
- Widgets / Live Activities / Dynamic Island
- Notifications
- Recurring transactions
- Multiple wallets / accounts

---

## 4. Tech stack

| Layer | Choice |
| --- | --- |
| UI | SwiftUI |
| Persistence | SwiftData |
| Pattern | MVVM |
| Charts | Apple Charts |
| Navigation | `NavigationStack` + `TabView` |
| Icons | SF Symbols |
| Language | Swift 6 |
| Minimum OS | iOS 26+ |

Avoid UIKit except where needed (haptics via `UIKit` feedback generators).

---

## 5. Project structure

```text
Pocki/
├── PockiApp.swift              App entry + ModelContainer
├── Models/
│   ├── Expense.swift
│   ├── ExpenseCategory.swift
│   ├── ExpenseSource.swift
│   └── AppSettings.swift
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── ExpensesViewModel.swift
│   ├── AddExpenseViewModel.swift
│   ├── ExpenseDetailViewModel.swift
│   ├── InsightsViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── MainTabView.swift
│   ├── Home/HomeView.swift
│   ├── Expenses/
│   │   ├── ExpensesView.swift
│   │   ├── AddExpenseView.swift
│   │   └── ExpenseDetailView.swift
│   ├── Insights/InsightsView.swift
│   └── Settings/SettingsView.swift
├── Components/                 Reusable UI building blocks
├── Services/                   Business logic / persistence helpers
├── Extensions/                 Date, currency, theme, View helpers
├── Utilities/                  Constants, mock data, previews
└── Assets.xcassets/
```

**Rule of thumb:** Views = UI only. Logic = ViewModels + Services.

---

## 6. Architecture (MVVM)

```text
  View  ──binds──▶  ViewModel  ──uses──▶  Service  ──▶  SwiftData
   │                    │
   │                    └── @Observable state
   └── SwiftUI rendering only
```

### Responsibilities

| Layer | Does | Does not |
| --- | --- | --- |
| **View** | Layout, navigation, presentation | Business rules, persistence |
| **ViewModel** | Formatting, validation, screen state | Direct networking (none in v1) |
| **Service** | CRUD, budget math, haptics, export stubs | UI decisions |
| **Model** | Data shape + SwiftData persistence | UI |

Dependency injection is done by constructing services with `ModelContext` from the environment.

---

## 7. Data models

### Expense

Primary spending record.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `UUID` | Identity |
| `amount` | `Double` | Positive spend amount |
| `merchant` | `String` | Where money went |
| `category` | `ExpenseCategory` | Stored as `categoryRaw` |
| `date` | `Date` | When the spend happened |
| `note` | `String?` | Optional |
| `createdAt` / `updatedAt` | `Date` | Audit timestamps |
| `source` | `ExpenseSource` | `manual` / `ocr` / `import` |
| `isVerified` | `Bool` | User confirmed OCR result (future) |
| `confidence` | `Double?` | OCR confidence 0…1 (future) |

### ExpenseCategory

`Food` · `Shopping` · `Travel` · `Bills` · `Entertainment` · `Health` · `Education` · `Groceries` · `Subscriptions` · `Other`

Each category has an SF Symbol and accent color for badges/charts.

### ExpenseSource

| Value | Meaning |
| --- | --- |
| `manual` | Typed by user (v1 default) |
| `ocr` | Created from a screenshot (future) |
| `import` | Imported from file/extension (future) |

### AppSettings

| Field | Purpose |
| --- | --- |
| `monthlyBudget` | User-defined monthly budget |
| `currencyCode` | ISO currency (USD, INR, …) |
| `updatedAt` | Last change |

---

## 8. Persistence (SwiftData)

- Local-only store (no CloudKit in v1)
- Schema registered in `PockiApp`:
  - `Expense`
  - `AppSettings`
- `@Query` in views for live updates
- Services call `modelContext.save()` after mutations

Previews use an in-memory container via `PreviewContainer` (optionally seeded with `MockData`).

---

## 9. Services

### ExpenseService

Full CRUD:

- `create` · `update` · `delete` · `deleteAll`
- `fetchAll`
- `search` across merchant, category, notes

### BudgetService

- Load or create default `AppSettings`
- Update budget / currency
- Compute spent, remaining, progress ratio

### HapticService

Thin wrapper over UIKit feedback:

- success · warning · error
- light / medium impact
- selection

### ExportService

Placeholder for future CSV / PDF export. Returns `nil` today so the Settings UI can show “coming soon” without fake implementations.

---

## 10. ViewModels

| ViewModel | Role |
| --- | --- |
| `HomeViewModel` | Greeting, month/today/week totals, daily average, recent list, budget metrics |
| `ExpensesViewModel` | Search text, date grouping, delete |
| `AddExpenseViewModel` | Form fields, validation, create or update |
| `ExpenseDetailViewModel` | Delete action for a single expense |
| `InsightsViewModel` | Chart datasets: weekly, monthly, categories, merchants, trend delta |
| `SettingsViewModel` | Budget text, currency picker, reset confirmation |

All ViewModels are `@MainActor` + `@Observable`.

---

## 11. Screens & navigation

### Root: `MainTabView`

Tabs:

| Tab | Icon | Screen |
| --- | --- | --- |
| Home | `house.fill` | Dashboard |
| Expenses | `creditcard.fill` | Full ledger |
| Insights | `chart.bar.fill` | Charts |
| Settings | `gearshape.fill` | Preferences |

A floating circular **+** button is always visible and presents `AddExpenseView` as a sheet.

Tapping an expense opens `ExpenseDetailView` as a sheet.

### Home

Answers: *How am I doing this month?*

- Greeting (time of day)
- Brand + tagline
- `BudgetCard` with animated ring
- Stat grid: today, week, daily average, remaining
- Recent transactions (top 5) with “See All”

### Expenses

- Instant search
- Grouped by calendar day
- Swipe leading = Edit · trailing = Delete
- Empty and “no matches” states

### Add / Edit Expense

Bottom sheet fields:

1. Amount (auto-focused)
2. Merchant
3. Category grid
4. Date & time
5. Notes

Validation: amount > 0 and merchant non-empty. Success haptic on save.

### Expense Detail

Shows amount, merchant, category, date, notes, source, verified flag, and an **OCR confidence placeholder** for the future screenshot flow. Actions: Edit, Delete.

### Insights

- Month total & daily average
- Weekly bar chart
- Monthly area/line chart
- Category donut + legend
- Top merchants
- Week-over-week trend

### Settings

- Monthly budget (save)
- Currency picker
- Export (placeholder alert)
- Reset all data (confirmation)
- App name / version / tagline

---

## 12. Reusable components

| Component | Purpose |
| --- | --- |
| `BudgetCard` | Month budget summary + ring |
| `ProgressRing` | Animated circular progress |
| `ExpenseRow` | List row: icon, merchant, category, amount |
| `StatCard` | Compact metric tile |
| `CategoryBadge` | Tinted SF Symbol circle |
| `SectionHeader` | Title + optional action |
| `GlassCard` | Frosted elevated surface |
| `FloatingAddButton` | Global + FAB |
| `PrimaryButton` | Full-width CTA with press scale |
| `EmptyStateView` | Illustration + message + optional CTA |
| `LoadingView` | Simple loading placeholder |

---

## 13. Design system

Inspired by Apple Wallet, Journal, Fitness, and Health — not Material Design.

| Token | Choice |
| --- | --- |
| Accent | Calm teal `#0F9B8E` (`Color.pockiAccent`) |
| Success / warning | Soft green / orange |
| Cards | Ultra-thin material + soft shadow · radius ~20 |
| Type | Large rounded titles, clear hierarchy |
| Spacing | Generous padding (`Constants.Layout`) |
| Modes | Light + Dark · Dynamic Type · accessibility labels |

Background: subtle adaptive gradient via `PockiBackground`.

---

## 14. Budget system

1. User sets `monthlyBudget` in Settings (default `2000` in the user’s currency unit).
2. Home / BudgetService sum expenses in the current calendar month → **spent**.
3. **Remaining** = budget − spent.
4. **Progress** = spent / budget (can exceed 1.0 when over budget; ring tints to warning).

The ring animates with a spring when values change.

---

## 15. Search

`ExpenseService.search` filters instantly on:

- Merchant
- Category name
- Notes

Case-insensitive substring match. Empty query returns the full list.

---

## 16. Animations & haptics

| Moment | Feedback |
| --- | --- |
| Budget ring appear / update | Spring trim animation |
| Floating + press | Scale + medium impact |
| Save expense | Success notification haptic |
| Delete / reset | Warning haptic |
| Category select | Selection haptic |
| Cards / insights | Soft opacity / offset entrance |
| Primary button | Scale button style |

Keep motion subtle and Apple-like — never noisy.

---

## 17. How to run

### Requirements

- macOS with **Xcode 26+**
- **iOS 26** simulator or device

### Steps

```bash
git clone https://github.com/amritkang165/Pocki.git
cd Pocki
open Pocki.xcodeproj
```

1. Select an iPhone simulator (or a physical device).
2. For device builds: set your **Team** under *Signing & Capabilities*.
3. Press **⌘R**.

### First launch

- Empty expense list → polished empty states
- Default settings inserted if none exist
- Use **+** to add your first expense
- Set monthly budget in **Settings**

---

## 18. Privacy

- All data is **on-device** via SwiftData
- No accounts, no analytics SDK, no network calls in v1
- When screenshot OCR ships, prefer **on-device** recognition so payment screenshots stay private

---

## 19. Roadmap & future architecture

### What to add in next versions

#### v1.1 — Screenshot intake (the unique feature)

**In progress in the app:** photo picker + on-device Vision OCR + UPI parser + review-before-save.

| Add | Details | Status |
| --- | --- | :---: |
| Pick UPI screenshot | Photos picker on Add Expense | ✅ |
| On-device OCR | Apple Vision text recognition | ✅ |
| Multi-app parser | Generic UPI heuristics (GPay / PhonePe / Paytm / BHIM-friendly) | ✅ early |
| Review before save | Prefills form; user confirms | ✅ |
| Confidence + verify | `confidence` shown; `isVerified` on save | ✅ |
| Source tagging | Saves with `ExpenseSource.ocr` | ✅ |
| Per-app layout tuning | Dedicated parsers per UPI app | 🔜 |
| Share Extension | Share screenshot from Photos | 🔜 |

```text
  Photos / Files  →  OCR service  →  prefilled form  →  user confirms  →  expense
```

#### v1.2 — Smarter tracking

| Add | Details |
| --- | --- |
| Smart categories | Suggest category from merchant name / history |
| Merchant memory | Remember last category per merchant |
| Filters on Expenses | By category, source (manual vs OCR), date range |
| Notes templates | Quick chips (“food”, “split”, “refund”) |
| Duplicate detection | Warn if same amount + merchant + day already exists |

#### v1.3 — Export & share

| Add | Details |
| --- | --- |
| CSV export | Wire `ExportService.exportCSV` |
| PDF monthly statement | Wire `ExportService.exportPDF` |
| Share sheet | Share file via system share |
| Share Extension | “Share screenshot → Pocki” from Photos / any app |

#### v2.0 — Glanceable iOS surfaces

| Add | Details |
| --- | --- |
| Home Screen widget | Month spent / remaining / ring |
| Lock Screen widget | Today’s spend |
| Live Activities | Optional “budget day” progress |
| Dynamic Island | Compact remaining budget (optional) |
| Local notifications | Soft budget warnings (80% / 100%) — opt-in only |

#### v2.1 — Sync & multi-wallet

| Add | Details |
| --- | --- |
| CloudKit sync | Same data across user’s devices |
| Multiple wallets / accounts | Cash, UPI, card — optional split |
| Recurring expenses | Rent, subscriptions auto-suggest |
| Budgets per category | Caps for Food, Travel, etc. |
| Accounts / sign-in | Only if CloudKit or multi-device needs it |

#### Later / experimental

| Add | Details |
| --- | --- |
| AI categorization | On-device or private model for merchants |
| Receipt OCR beyond UPI | Store bills, invoices |
| Bank CSV import | `ExpenseSource.import` |
| Apple Watch glance | Today + remaining |
| App Intents / Siri | “Log ₹120 at Starbucks” |

### Version snapshot

```text
  v1.0   ✅  Manual tracking · budget · insights · settings
  v1.1   ▢   Any UPI screenshot → OCR → confirm → save
  v1.2   ▢   Smart categories · filters · duplicates
  v1.3   ▢   CSV / PDF export · Share Extension
  v2.0   ▢   Widgets · Live Activities · budget alerts
  v2.1   ▢   CloudKit · multi-wallet · recurring
  later  ▢   AI · Watch · Siri · bank import
```

### How the code is already prepared

| Hook | Location |
| --- | --- |
| `ExpenseSource.ocr` / `.importSource` | Models |
| `confidence`, `isVerified` | `Expense` |
| OCR placeholder UI | Expense Detail → “Recognition” |
| `ExportService` stubs | Services |
| Settings “Export” alert | Settings |

Adding OCR should mean a new service (e.g. `ScreenshotOCRService`) that creates an `Expense` with `source: .ocr` — not a rewrite of Home / Insights.

Suggested future module layout:

```text
Services/
  OCR/
    ScreenshotOCRService.swift
    UPIScreenshotParser.swift      # per-app / generic UPI layouts
Extensions/
  ShareExtension/                  # later target
Widgets/
  BudgetWidget/                    # later target
```

### Build order (recommended)

1. Photo picker → prefill manual fields (no OCR yet)  
2. On-device Vision OCR → parse amount / merchant / date  
3. Review UI + `confidence` / `isVerified`  
4. Per-app UPI layout tweaks  
5. Export CSV  
6. Share Extension (“share screenshot to Pocki”)  
7. Widgets  
8. CloudKit  

Keep each version shippable. Don’t block v1.1 on widgets or sync.

---

## 20. Contributing guidelines

When extending Pocki:

1. Keep Views free of business logic.
2. Put persistence and math in Services.
3. Prefer optional fields + enums over breaking model changes.
4. No force unwraps.
5. Use `MARK` sections and short documentation comments on public types.
6. Match the calm teal design language — avoid Material patterns and purple-gradient defaults.
7. Add SwiftUI previews for new components where practical.

---

## Quick reference

| Question | Answer |
| --- | --- |
| What is unique? | Screenshot **any UPI** payment → expense |
| What ships in v1? | Manual tracking + budget + insights |
| Where is data stored? | On-device SwiftData |
| Where do I change budget? | Settings |
| Where is OCR going? | New service + `ExpenseSource.ocr` |
| License? | MIT |

---

*Pocki v1 — track manually today. Screenshot any UPI app tomorrow.*
