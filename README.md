<div align="center">

# Pocki

### Your money, simplified.

**Version 1.0** · Premium personal finance for iPhone

<br/>

[![iOS](https://img.shields.io/badge/iOS-26%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-0F9B8E?style=for-the-badge)](#tech-stack)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

<br/>

```text
┌─────────────────────────────────────────────────────────┐
│                                                         │
│     📸  Screenshot from any UPI app                     │
│                                                         │
│         GPay · PhonePe · Paytm · BHIM · …               │
│                                                         │
│     ✨  Pocki reads amount, merchant & date             │
│                                                         │
│     📊  Your spending — clear, calm, beautiful          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Snap a UPI payment. Drop it in. Done.**

No endless typing. No forgotten purchases. Just your money — finally understandable.

<br/>

[Features](#-features)·[The Vision](#-the-vision)·[Roadmap](#-roadmap)·[Run](#-run-locally)·[License](#-license)

</div>

---

## Why Pocki exists

You already screenshot every UPI payment.

You just never put those screenshots to work.

**Pocki** turns payment screenshots from **any UPI app** into clean expense entries — then shows you where your money actually went, in an interface that feels like Apple designed it.

> Manual tracking ships in **v1**.  
> Screenshot import from GPay, PhonePe, Paytm, BHIM & more is the product’s north star — and the architecture is already built for it.

---

## The vision

<table>
<tr>
<td width="50%" valign="top">

### Today — Version 1

Track spending by hand in seconds.

Beautiful home dashboard.  
Smart insights.  
Budget ring that actually motivates you.

Calm. Fast. Native.

</td>
<td width="50%" valign="top">

### Tomorrow — Screenshot magic

Upload a UPI payment screenshot.

Pocki extracts:

- **Amount**
- **Merchant**
- **Date & time**

Works across UPI apps — not locked to one wallet.

</td>
</tr>
</table>

```text
  any UPI screenshot  ──▶  OCR  ──▶  verified expense  ──▶  insights
       ▲
   GPay · PhonePe · Paytm · BHIM · Amazon Pay · … 
```

---

## Features

### Home — “How am I doing this month?”

| | |
| :--- | :--- |
| Greeting that feels personal | Monthly spend vs budget |
| Animated progress ring | Today · Week · Daily average · Remaining |
| Recent transactions | Large type, glass cards, zero clutter |

### Expenses — Your full ledger

- Instant search across **merchant · category · notes**
- Grouped by date
- Swipe to **edit** or **delete**
- Detail view with source & OCR confidence placeholders (ready for screenshot flow)

### Add Expense — Bottom sheet bliss

- Amount field auto-focused
- Merchant, category, date, notes
- Validation + success haptic
- One large Save button

### Insights — Charts that breathe

Powered by **Apple Charts**:

- Weekly bars & monthly trend
- Category breakdown
- Top merchants
- Daily average & week-over-week delta

### Settings — Keep it simple

Monthly budget · Currency · Export (soon) · Reset · About

---

## Design language

Inspired by **Apple Wallet · Journal · Fitness · Health**.

| Detail | Choice |
| --- | --- |
| Corners | Soft 16–24pt radii |
| Color | Calm teal accent, minimal palette |
| Type | Large, rounded, readable |
| Motion | Subtle rings, sheets, list updates |
| Mode | Full Dark Mode + Dynamic Type |
| Feel | Premium. Quiet. Native. |

Not Material. Not noisy. Just Apple-clean.

---

## Tech stack

```text
SwiftUI  ·  SwiftData  ·  MVVM  ·  Apple Charts
NavigationStack  ·  SF Symbols  ·  Swift 6  ·  iOS 26+
```

### Project structure

```text
Pocki/
├── Models/         Expense · Category · Source · Settings
├── ViewModels/     Home · Expenses · Insights · Settings · Add / Detail
├── Views/          Tabs + sheets
├── Components/     BudgetCard · ProgressRing · GlassCard · …
├── Services/       Expense · Budget · Haptics · Export
├── Extensions/     Date · Currency · Theme
└── Utilities/      Constants · Mock data · Previews
```

Views = UI only. Logic = ViewModels + Services.

Future-ready fields already live on every expense:

`source` · `isVerified` · `confidence` → built for OCR & UPI imports.

---

## Roadmap

| Status | Feature |
| :---: | --- |
| ✅ | Manual expense tracking (v1) |
| ✅ | Budget ring & insights |
| ✅ | Search, swipe actions, dark mode |
| 🔜 | **UPI screenshot upload** (GPay, PhonePe, Paytm, BHIM, …) |
| 🔜 | On-device OCR for amount / merchant / date |
| 🔜 | Smart category suggestions |
| 🔜 | CSV / PDF export |
| 🔜 | Share Extension · Widgets · Live Activities |
| 🔜 | CloudKit sync · Multiple wallets |

---

## Requirements

- macOS with **Xcode 26+**
- **iOS 26** simulator or device

---

## Run locally

```bash
git clone https://github.com/amritkang165/Pocki.git
cd Pocki
open Pocki.xcodeproj
```

1. Pick an **iPhone** simulator (or your device)  
2. Set **Signing Team** if running on device  
3. Hit **⌘R**

---

## Privacy

- Data stays **on your device** (SwiftData)
- No accounts · no backend · no tracking in v1
- Screenshot OCR will prefer **on-device** processing

---

## Categories

`Food` `Shopping` `Travel` `Bills` `Entertainment`  
`Health` `Education` `Groceries` `Subscriptions` `Other`

---

## License

**MIT** — see [LICENSE](LICENSE)

Copyright © 2026 **Amrit Kang**

---

<div align="center">

### Built for people who already screenshot every payment.

**Pocki v1** — track manually today.  
Screenshot any UPI app tomorrow.

<br/>

**[★ Star this repo](https://github.com/amritkang165/Pocki)** if the idea resonates.

<br/>

<sub>Designed to feel like Apple made it · Made in India 🇮🇳</sub>

</div>
