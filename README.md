<div align="center">

# Pocki
### Your money, simplified.

**v1.0** · iOS · SwiftUI · SwiftData

[![iOS](https://img.shields.io/badge/iOS-26%2B-000000?style=flat-square&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)

</div>

---

## What’s unique

Most expense apps make you type every purchase.

**Pocki’s core idea is different:**

> You already screenshot every UPI payment.  
> Pocki turns that screenshot into an expense.

Not locked to one wallet. **Any UPI app:**

`GPay` · `PhonePe` · `Paytm` · `BHIM` · `Amazon Pay` · and more

```text
  UPI payment  →  screenshot  →  Pocki  →  amount + merchant + date  →  insights
```

That’s the product. Everything else supports it.

**v1** ships beautiful manual tracking (and the architecture for OCR).  
**Next** ships screenshot import from any UPI app.

---

## Why this matters

| Old way | Pocki way |
| --- | --- |
| Open app → type amount → type merchant → pick date | Drop the UPI screenshot you already have |
| Works for one wallet, or none | Built for **every** UPI app |
| Easy to forget small spends | Capture happens at payment time |
| Feels like homework | Feels like Apple made it |

---

## Version 1 (now)

Manual tracking done right — fast, calm, native:

- **Home** — monthly budget ring, today / week / average / remaining
- **Expenses** — search, group by date, swipe edit & delete
- **Add** — bottom sheet, amount auto-focused, haptics
- **Insights** — Apple Charts (weekly, monthly, categories, top merchants)
- **Settings** — budget, currency, reset, about

Future-ready on every expense: `source` · `isVerified` · `confidence` (for OCR).

---

## What’s next

1. **Upload any UPI screenshot**
2. On-device OCR → amount, merchant, date
3. Smart categories
4. Export · widgets · CloudKit

---

## Stack

`SwiftUI` · `SwiftData` · `MVVM` · `Apple Charts` · `Swift 6` · `iOS 26+`

```text
Pocki/
├── Models/        ViewModels/        Views/
├── Components/    Services/          Extensions/
└── Utilities/
```

---

## Run

```bash
git clone https://github.com/amritkang165/Pocki.git
cd Pocki
open Pocki.xcodeproj
```

Xcode 26+ · iOS 26 · **⌘R**

---

## Privacy

On-device SwiftData. No accounts. No backend in v1. OCR will prefer local processing.

---

## License

MIT © 2026 [Amrit Kang](https://github.com/amritkang165) — [LICENSE](LICENSE)

---

<div align="center">

**The unique thing:** screenshot any UPI payment → expense, done.

★ [Star the repo](https://github.com/amritkang165/Pocki) if that idea clicks.

</div>
