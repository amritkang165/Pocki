<p align="center">
  <img src="https://img.shields.io/badge/Pocki-Your%20money%2C%20simplified.-0F9B8E?style=for-the-badge&labelColor=111111" alt="Pocki" />
</p>

<h1 align="center">Pocki</h1>

<p align="center">
  <strong>Your money, simplified.</strong><br />
  A premium iOS personal finance tracker — calm, fast, and designed like an Apple first-party app.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-26%2B-black?style=flat-square&logo=apple&logoColor=white" alt="iOS 26+" />
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6" />
  <img src="https://img.shields.io/badge/SwiftUI-Native-0F9B8E?style=flat-square" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/SwiftData-Local-5AC8FA?style=flat-square" alt="SwiftData" />
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="MIT License" />
</p>

---

## The idea

Most expense apps ask you to type everything. That friction is why people quit.

**Pocki’s signature idea:** upload a **Google Pay payment screenshot**, and the app reads the amount, merchant, and date for you — turning a receipt you already have into a clean expense entry.

The current MVP ships **manual tracking** first, with architecture already prepared for screenshot OCR, imports, and smarter categorization.

> Snap it. Save it. Understand it.

---

## Why Pocki

| Principle | What it means |
| --- | --- |
| **Simplicity** | One job — know where your money went |
| **Speed** | Add an expense in seconds |
| **Beauty** | Large type, glass cards, calm teal accents |
| **Native** | SwiftUI, SwiftData, Apple Charts, SF Symbols |
| **Future-ready** | OCR, GPay import, CloudKit, widgets — without a rewrite |

---

## Features (MVP)

### Home
- Personalized greeting
- Monthly spending vs budget
- Animated budget progress ring
- Today, this week, daily average, remaining
- Recent transactions

### Expenses
- Full history with instant search (merchant, category, notes)
- Grouped by date
- Swipe to edit / delete
- Detail view with source & OCR confidence placeholders

### Add Expense
- Bottom sheet with auto-focused amount field
- Merchant, category, date, notes
- Validation + success haptics

### Insights
- Weekly & monthly charts (Apple Charts)
- Category breakdown
- Top merchants
- Daily average & week-over-week trend

### Settings
- Monthly budget
- Currency
- Export placeholder
- Reset all data
- About / version

---

## Coming next

Built into the data model and services — not bolted on later:

- [ ] **Google Pay screenshot upload + OCR**
- [ ] Smart merchant categorization
- [ ] CSV / PDF export
- [ ] Share Extension
- [ ] Widgets & Live Activities
- [ ] CloudKit sync
- [ ] Multiple accounts / wallets

```text
ExpenseSource:  manual  →  ocr  →  import
                ✓ now      soon     soon
```

---

## Screens

| Tab | Purpose |
| --- | --- |
| 🏠 **Home** | “How am I doing this month?” |
| 💸 **Expenses** | Searchable ledger |
| 📊 **Insights** | Charts & trends |
| ⚙️ **Settings** | Budget, currency, data |

Floating **+** button everywhere → add expense sheet.

---

## Tech stack

```text
SwiftUI · SwiftData · MVVM · Apple Charts
NavigationStack · SF Symbols · Swift 6 · iOS 26+
```

### Architecture

```text
Pocki/
├── Models/          # Expense, Category, Source, Settings
├── ViewModels/      # Home, Expenses, Insights, Settings, Add/Detail
├── Views/           # Tab screens + sheets
├── Components/      # BudgetCard, ProgressRing, GlassCard, …
├── Services/        # Expense, Budget, Haptics, Export (placeholder)
├── Extensions/      # Date, Currency, Theme
└── Utilities/       # Constants, Mock data, Previews
```

Views stay UI-only. Logic lives in ViewModels and Services.

---

## Requirements

- macOS with **Xcode 26+**
- **iOS 26** simulator or device
- Apple Developer account (optional for simulator; required for a physical device)

---

## Run locally

```bash
git clone https://github.com/amritkang165/Pocki.git
cd Pocki
open Pocki.xcodeproj
```

1. Select an **iPhone** simulator (or your device)
2. Set your **Team** under *Signing & Capabilities* if running on device
3. Press **⌘R**

---

## Data & privacy

- Everything is stored **on-device** with SwiftData
- No accounts, no backend, no network calls in the MVP
- Screenshot OCR (when shipped) will process locally whenever possible

---

## Categories

Food · Shopping · Travel · Bills · Entertainment · Health · Education · Groceries · Subscriptions · Other

---

## License

Released under the [MIT License](LICENSE).

Copyright © 2026 Amrit Kang

---

## Author

**Amrit Kang** — creator of Pocki.

The core product vision: *make expense tracking feel effortless by starting from the payment screenshot you already took.*

---

<p align="center">
  <sub>Built with SwiftUI · Designed to feel like Apple made it</sub>
</p>
