# Vitaly App 💎 — Luxury Stone & Wood Warehouse ERP

> Phase 1 complete — Dark Luxury Shell with 8 Modules

---

## Setup (run these once, in order)

```bash
# 1. Scaffold native Flutter boilerplate around our existing lib/ code
flutter create . --org com.vitaly.app --project-name vitaly_app

# 2. Fetch all dependencies
flutter pub get

# 3. Run on Chrome (web preview — best for desktop layout)
flutter run -d chrome

# 4. Or run on Windows native
flutter run -d windows

# 5. Or list available devices
flutter devices
```

> ⚠️ If `flutter` isn't recognized, install from https://docs.flutter.dev/get-started/install/windows

---

## Architecture

```
lib/
├── main.dart                          ← Entry point + Splash Screen
├── core/
│   ├── theme/
│   │   └── app_theme.dart             ← Dark Luxury palette (AppColors + AppTheme)
│   ├── models/
│   │   ├── category.dart
│   │   ├── material_item.dart
│   │   ├── slab.dart                  ← Core inventory unit
│   │   ├── customer.dart
│   │   ├── reservation.dart
│   │   └── sale.dart
│   └── mock/
│       └── mock_data.dart             ← 20 slabs, 20 materials, 6 customers
└── modules/
    ├── navigation/
    │   └── main_layout_screen.dart    ← Responsive Shell (Sidebar ≥900px / Drawer+BottomNav <900px)
    ├── data_entry/
    ├── available_stone/               ← Renders full slab list with defect badges
    ├── reservations/                  ← Shows reservation cards with hold dates
    ├── sales/                         ← Revenue card + transaction list
    ├── category_check/                ← Category breakdown with slab counts
    ├── data_check/                    ← Flags defective/damaged slabs
    ├── print_labels/                  ← Label grid preview (qr_flutter ready)
    └── scan/                          ← Scanner viewfinder (mobile_scanner ready)
```

---

## Design System

| Token | Value |
|---|---|
| Background | `#0F1216` Deep charcoal |
| Surface / Cards | `#181C22` |
| Surface Variant | `#222831` |
| Primary Gold | `#E5A93C` |
| Borders | `#262C36` |
| Text Primary | `#FFFFFF` |
| Text Secondary | `#9CA3AF` |
| Success | `#10B981` |
| Warning | `#F59E0B` |
| Font | Google Fonts — Inter |

---

## Phase Roadmap

- ✅ **Phase 1** — Project scaffold, design system, mock data, 8-module navigation shell
- 🔲 **Phase 2** — Data Entry form (bundle + slab registration), Available Stone grid with filters
- 🔲 **Phase 3** — Reservation management CRUD, Sales workflow + invoice generation
- 🔲 **Phase 4** — QR label printing (qr_flutter), live camera scan (mobile_scanner)
- 🔲 **Phase 5** — InsForge API integration, cloud sync, multi-user auth
