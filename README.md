# Afrezza Inhaled Insulin Plugin for AAPS

Patch set adding **Afrezza (Technosphere) inhaled insulin** support to [AndroidAPS](https://github.com/nightscout/AndroidAPS) (`dev` branch).

This enables hybrid closed-loop users who take Afrezza for meals to have their inhaled insulin IOB tracked with the correct pharmacokinetic curve (peak ~40 min, DIA ~2.5 h) alongside their pump insulin (Fiasp, Lyumjev, etc.), so the oref algorithm makes accurate basal adjustment decisions.

> **⚠️ IMPORTANT SAFETY NOTICE**
>
> This is an **experimental, community-developed modification** to AAPS. It is **not approved** by any regulatory body. Use at your own risk. Always discuss insulin regimen changes with your endocrinologist. Monitor your CGM closely during initial use. The authors assume no liability.

---

## What This Patch Does

### The Problem

AAPS models all insulin using a single curve (your pump insulin). When you take Afrezza and manually log it, AAPS applies the pump insulin's 5+ hour DIA curve to the Afrezza dose. This creates **phantom IOB** for hours after Afrezza has actually worn off (~2.5 hours), causing AAPS to hold back basal and leaving you running high.

### The Solution

The AAPS `dev` branch already supports **per-bolus insulin configurations** — every bolus carries its own `ICfg` with peak time, DIA, and concentration. The IOB calculator already uses this per-bolus curve. This patch leverages that architecture to add Afrezza as a properly modeled insulin type.

### What Changes

| Component | Change |
|-----------|--------|
| `InsulinType` | New `OREF_INHALED_AFREZZA` entry (peak=40min, DIA=2.5h) with `isInhaled` flag |
| `HardLimits` | New `MIN_DIA_INHALED` (1.5h) / `MAX_DIA_INHALED` (4.0h) — pump DIA limits unchanged |
| `InsulinImpl` | Afrezza added to insulin template list |
| `InsulinManagementViewModel` | DIA editor slider uses inhaled range for inhaled templates |
| `AfrezzaDialog` | New one-tap Compose bottom sheet with 4U/8U/12U cartridge buttons |
| `ElementType` | New `AFREZZA` navigation entry with icon, color, label |
| `AppNavGraph` | Afrezza dialog route registered |
| `TreatmentBottomSheet` | Afrezza button auto-appears when inhaled insulin is configured |
| `QuickLaunchAction` | Afrezza available for home screen quick-launch bar |
| `Sources` | New `AfrezzaDialog` source for UserEntry/treatment history |
| IOB Tests | 179-line test suite validating the oref model at Afrezza parameters |
| `AfrezzaActivity` (Wear) | New Compose activity for 4U/8U/12U cartridge selection on watch |
| `ActionSource` (Wear) | Afrezza added to Wear OS Actions tile as a configurable action |
| `EventData` | New `ActionAfrezzaPreCheck` / `ActionAfrezzaConfirmed` sealed events |
| `DataHandlerMobile` | Phone-side handler logs Afrezza via PersistenceLayer (bypasses pump queue) |
| `AfrezzaMaxBasalState` | New `:core:data` runtime state for the post-dose max-basal feature |
| `DoubleKey.AfrezzaMaxBasalRate` | New configurable max-basal rate setting (shown under OpenAPS SMB) |
| `OpenAPSSMBPlugin` | Enforces Afrezza max basal in `applyBasalConstraints`: hypo guard (pauses below BG 70), COB / extended-carb awareness, min 2.0 U/h |
| `AfrezzaDialog` (max basal) | Optional post-dose prompt to hold an elevated basal (60/120/180 min) with a cancel button |

**Total: 39 files changed, ~1,230 lines added.**

---

## Prerequisites

- **Android Studio** (Hedgehog 2023.1.1 or later recommended)
- **JDK 17** or later
- **Git** installed and configured
- A working AAPS build environment — if you haven't built AAPS before, follow the [official build guide](https://wiki.aaps.app/en/latest/Installing-AndroidAPS/Building-APK.html) first
- AAPS `dev` branch source code

---

## Quick Start (Combined Patch)

If you want to apply all changes at once:

```bash
# 1. Clone AAPS and switch to dev branch
git clone https://github.com/nightscout/AndroidAPS.git
cd AndroidAPS
git checkout dev

# 2. Create a feature branch
git checkout -b feature/afrezza-inhaled-insulin

# 3. Download and apply the combined patch
#    (copy afrezza-combined.patch from this repo's patches/ directory)
git am --3way /path/to/afrezza-combined.patch

# 4. Build
./gradlew assembleFullDebug
```

---

## Step-by-Step Build Instructions

### Step 1: Clone the AAPS Repository

```bash
git clone https://github.com/nightscout/AndroidAPS.git
cd AndroidAPS
```

### Step 2: Switch to the Dev Branch

```bash
git checkout dev
```

Verify you're on dev:
```bash
git branch --show-current
# Should output: dev
```

### Step 3: Create a Feature Branch

```bash
git checkout -b feature/afrezza-inhaled-insulin
```

### Step 4: Clone This Repository

```bash
cd ..
git clone https://github.com/CAPTCG/afrezza-aaps-plugin.git
cd AndroidAPS
```

### Step 5: Apply the Patch

```bash
git am --3way ../afrezza-aaps-plugin/patches/afrezza-combined.patch
```

### Step 6: Verify the Patch Applied

```bash
git log --oneline -1
```

You should see: `feat: Add Afrezza inhaled insulin support`

### Step 7: Open in Android Studio

1. Open Android Studio
2. File → Open → select the `AndroidAPS` directory
3. Wait for Gradle sync to complete
4. If prompted, accept any SDK or dependency updates

### Step 8: Run the Tests

```bash
./gradlew :core:data:test --tests "*ICfgAfrezzaIobTest*"
```

All 9 tests should pass, confirming the IOB curve math works correctly at Afrezza parameters.

### Step 9: Build the APK

**Debug build (for testing):**
```bash
./gradlew assembleFullDebug
```

**Release build (for daily use):**
```bash
./gradlew assembleFullRelease
```

The APK will be at:
```
app/build/outputs/apk/full/debug/app-full-debug.apk
  — or —
app/build/outputs/apk/full/release/app-full-release.apk
```

### Step 10: Install on Your Phone

Transfer the APK to your phone and install it, or use:
```bash
adb install -r app/build/outputs/apk/full/debug/app-full-debug.apk
```

---

## How to Use Afrezza in AAPS

### First-Time Setup

1. Open AAPS → **Insulin Management** (via hamburger menu or search)
2. Tap **Add** (+ button)
3. Select the **Afrezza (Inhaled)** template
4. The defaults (peak 40 min, DIA 2.5 h, U100) work for most users — adjust if needed
5. Tap **Save**

The Afrezza button will now automatically appear in your Treatment Bottom Sheet.

### Logging an Afrezza Dose

1. Tap the **Treatment** button on the AAPS home screen (or the Afrezza quick-launch button if configured)
2. Tap **Afrezza**
3. Tap your cartridge size: **4U**, **8U**, or **12U**
4. Confirm

That's it — two taps. The dose is recorded with Afrezza's own insulin curve. AAPS will:

- Show the Afrezza IOB decaying over ~2.5 hours (not 5+ hours)
- Resume basal delivery once Afrezza wears off
- Correctly sum Afrezza IOB + pump IOB for prediction calculations

### Adding Afrezza to Quick Launch Bar

1. Go to the Quick Launch configuration (long-press the action bar or search "Quick Launch")
2. Add the **Afrezza** action
3. The Afrezza button now appears directly on your home screen

### Using the Standard Insulin Dialog

You can also log Afrezza through the regular Insulin Dialog:

1. Open Insulin Dialog
2. Toggle **Record Only** (Afrezza is not pump-delivered)
3. Select your Afrezza insulin from the dropdown
4. Enter the dose
5. Confirm

### Logging Afrezza from Your Watch (Wear OS)

The Afrezza action is available in the Wear OS **Actions tile**:

1. On your watch, open the AAPS Actions tile settings
2. Assign one of the tile slots to **Afrezza** (listed as "Afrz")
3. To log a dose, tap the Afrezza tile button
4. Select your cartridge: **4U**, **8U**, or **12U**
5. Swipe to the confirmation page and tap the green check
6. Accept the confirmation prompt on the watch

The dose is logged directly to the persistence layer with the correct Afrezza ICfg — it does **not** go through the pump command queue since Afrezza is inhaled, not pump-delivered.

---

## Pharmacokinetic Parameters

| Parameter | Afrezza (This Plugin) | Fiasp (Typical Pump) |
|-----------|:--------------------:|:--------------------:|
| Onset | ~12 min | ~10-20 min |
| Peak | **40 min** | 55 min |
| DIA | **2.5 hours** | 5-8 hours |
| Delivery | Inhaled | Subcutaneous |

The oref bilinear IOB model is used with these parameters. The included test suite validates that the curve behaves correctly (no NaN, proper peak timing, monotonic decay, zero at DIA).

---

## Patch Details

### Commit List

| # | Commit | Description |
|---|--------|-------------|
| 1 | `feat: Add Afrezza inhaled insulin string resources` | Labels for UI, dialogs, and navigation |
| 2 | `feat: Add InsulinType.OREF_INHALED_AFREZZA and inhaled DIA limits` | Enum entry + `HardLimits` interface, impl, and test mock |
| 3 | `feat: Add Afrezza to insulin template list, fix editor DIA validation` | Template + editor slider range |
| 4 | `test: Add IOB curve validation tests for Afrezza parameters` | 9 tests covering curve correctness |
| 5 | `feat: Add Afrezza quick-log dialog for one-tap dose logging` | Compose bottom sheet (4U/8U/12U) |
| 6 | `feat: Add Afrezza to navigation system` | ElementType, icon, color, label |
| 7 | `feat: Wire Afrezza dialog into navigation, quick-launch, and routing` | AppRoute + NavGraph + QuickLaunch + staticActions |
| 8 | `feat: Add Afrezza button to Treatment Bottom Sheet` | Auto-appears when inhaled insulin configured, includes Preview |
| 9 | `feat: Add Sources.AfrezzaDialog for treatment history` | Sources enum, DB enum, SourcesExtension, UserEntryPresentation |
| 10 | `feat: Add Afrezza 4U/8U/12U logging to Wear OS Actions tile` | AfrezzaActivity, EventData events, ActionSource, DataHandlerMobile handler |
| 11 | `feat: Afrezza max basal (post-dose temporary basal)` | Configurable elevated basal after a dose — hypo guard, COB / extended-carb awareness, min 2.0 U/h, enforced in `OpenAPSSMBPlugin`; state in `:core:data` |

### Files Changed (by module)

```
app/                          — ComposeMainActivity, AppNavGraph, AppRoute
core/data/                    — Sources enum, IOB curve tests, AfrezzaMaxBasalState
core/interfaces/              — InsulinType, HardLimits, EventData (Afrezza events), strings
core/keys/                    — DoubleKey.AfrezzaMaxBasalRate, strings
core/ui/                      — ElementType, ElementTypeStyle, strings
database/impl/                — UserEntry.Sources DB enum
database/persistence/         — SourcesExtension bidirectional mapping
implementation/               — InsulinImpl, HardLimitsImpl, UserEntryPresentationHelperImpl
plugins/aps/                  — OpenAPSSMBPlugin (Afrezza max basal setting + enforcement)
plugins/sync/                 — DataHandlerMobile (Wear <-> phone Afrezza event handling)
shared/tests/                 — HardLimitsMock
ui/                           — AfrezzaDialog (3 files), InsulinManagementViewModel,
                                MainScreen, QuickLaunchAction, TreatmentBottomSheet,
                                TreatmentUiState, TreatmentViewModel, strings
wear/                         — AfrezzaActivity, ActionSource, WearActivitiesModule,
                                ic_afrezza drawable, AndroidManifest, strings
```

### Base Commit

This combined patch was regenerated in June 2026 from the active feature branch and is
applied with `git am --3way`, whose three-way merge absorbs minor upstream drift. It is
not pinned to a single upstream commit; if `git am` reports a conflict on a current `dev`
checkout, resolve the reported file(s) and run `git am --continue`, or open an issue.

---

## Troubleshooting

### Patch fails to apply

If the AAPS dev branch has changed since these patches were created:

```bash
# Try applying with 3-way merge
git am --3way ../afrezza-aaps-plugin/patches/afrezza-combined.patch

# If conflicts occur, resolve them, then:
git add .
git am --continue
```

### Build fails

1. Make sure you're on the `dev` branch, not `master` — the architectures are completely different
2. Run `./gradlew clean` before building
3. Ensure your Android Studio and Gradle versions match what AAPS requires (check AAPS wiki)

### Afrezza button doesn't appear

The Afrezza button in the Treatment Bottom Sheet only appears after you've added an Afrezza insulin configuration in Insulin Management. Go to Insulin Management → Add → select "Afrezza (Inhaled)" → Save.

### IOB seems wrong

If Afrezza IOB isn't decaying as expected, verify that the logged bolus has the correct ICfg. In Treatments history, Afrezza doses should show "Afrezza inhaled" in the notes and use the 2.5h DIA curve.

---

## Contributing

If you improve these patches or add features (automation triggers, Nightscout sync, etc.), please submit a PR to this repository. The goal is to eventually submit this as a PR to the upstream AAPS repository.

### Regenerating Patches

If you make changes to the AAPS feature branch:

```bash
cd AndroidAPS
git diff dev..HEAD > ../afrezza-aaps-plugin/patches/afrezza-combined.patch
```

---

## References

- [AAPS Wiki](https://wiki.aaps.app)
- [AAPS Issue #269 — Insulin Management](https://github.com/nightscout/AndroidAPS/issues/269) — prior discussion on multi-insulin support
- [Afrezza Prescribing Information](https://www.afrezza.com/) — MannKind Corporation
- Rave et al., "Inhaled Technosphere Insulin Compared With Injected Prandial Insulin in Type 1 Diabetes", *Diabetes Technology & Therapeutics*, 2015

---

## License

This patch set follows the same license as AAPS: [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.en.html).
