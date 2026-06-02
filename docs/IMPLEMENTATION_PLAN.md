# AAPS Afrezza Inhaled Insulin Support — Implementation Plan

## Target Branch: `dev` (nightscout/AndroidAPS)
## AAPS Version: Post-3.4.x (new insulin management architecture)

---

## Executive Summary

The AAPS `dev` branch has undergone a major insulin architecture refactor (authored by Philoul, Dec 2024). The old plugin-based system (one global `activeInsulin` plugin) has been replaced with a per-bolus insulin configuration model. **Every bolus now carries its own `ICfg` (insulin configuration) containing peak time, DIA, and concentration. The IOB calculator already uses this per-bolus ICfg — not a global setting.**

This means the hardest architectural problem (dual-curve IOB) is already solved. Implementing Afrezza support is now primarily a matter of:

1. Adding Afrezza as an insulin type template
2. Relaxing the DIA hard limit for inhaled insulin
3. Building a streamlined one-tap logging UX
4. Validating the IOB math at short DIA values

---

## Architecture Discovery (Dev Branch)

### What Already Works

| Component | Status | Location |
|-----------|--------|----------|
| Per-bolus ICfg (non-nullable) | **Done** | `core/data/src/main/kotlin/.../BS.kt` — `iCfg: ICfg` |
| IOB calc uses per-bolus curve | **Done** | `core/objects/src/.../BolusExtension.kt` — `iCfg.iobCalcForTreatment(this, time)` |
| IOB math on ICfg itself | **Done** | `core/data/src/.../ICfg.kt` — `iobCalcForTreatment()` |
| Multi-insulin CRUD manager | **Done** | `implementation/src/.../InsulinImpl.kt` — `insulins: ArrayList<ICfg>` |
| Insulin editor UI (Compose) | **Done** | `ui/src/.../insulinManagement/` — carousel with add/edit/remove |
| Insulin selection dropdown | **Done** | `ui/src/.../insulinDialog/InsulinDialogScreen.kt` — dropdown in record-only mode |
| DB persistence of per-bolus ICfg | **Done** | `database/.../Bolus.kt` — `@Embedded insulinConfiguration` |
| Pump boluses auto-tagged | **Done** | `PumpSyncImplementation.kt` — `iCfg = profile.iCfg` |
| Concentration support | **Done** | `ConcentrationType.kt` — U10 through U500 |

### What's Missing for Afrezza

| Component | Status | Effort |
|-----------|--------|--------|
| Afrezza InsulinType enum entry | **Not done** | Small |
| DIA hard limit allows < 5h | **Not done** | Medium |
| Afrezza in template list | **Not done** | Small |
| IOB math validation at DIA ~2.5h | **Not done** | Medium |
| One-tap Afrezza cartridge logging | **Not done** | Medium |
| Quick-action widget (4U/8U/12U) | **Not done** | Medium |
| Afrezza IOB curve visualization | **Not done** | Small |
| NS sync preserves Afrezza ICfg | **Verify** | Small |
| Wear OS Afrezza tile | **Not done** | Medium |

---

## Phase 1: Core Insulin Model (Enable Afrezza)

### 1.1 Add `OREF_INHALED_AFREZZA` to InsulinType

**File:** `core/interfaces/src/main/kotlin/app/aaps/core/interfaces/insulin/InsulinType.kt`

Add a new enum entry with Afrezza's pharmacokinetic parameters:

- **Peak:** 40 minutes (2,400,000 ms) — published Technosphere insulin Tmax
- **DIA:** 150 minutes / 2.5 hours (9,000,000 ms) — conservative; Afrezza is clinically active for ~90-180 min
- **Value:** 6 (next available int)

```kotlin
OREF_INHALED_AFREZZA(6, (2.5 * 3600 * 1000).toLong(), 40 * 60000L, R.string.inhaled_afrezza, R.string.inhaled_afrezza_comment),
```

**String resources to add:**
- `R.string.inhaled_afrezza` → "Afrezza (Inhaled)"
- `R.string.inhaled_afrezza_comment` → "Technosphere inhaled insulin — peak ~40 min, duration ~2.5 hours"

### 1.2 Relax DIA Hard Limits for Inhaled Insulin

**File:** `core/interfaces/src/main/kotlin/app/aaps/core/interfaces/utils/HardLimits.kt`

Current MIN_DIA is 5.0h across all patient types. Afrezza needs ~2.0-3.0h.

**Recommended approach:** Add a separate minimum for inhaled insulin rather than lowering the global minimum (which protects against misconfigured pump insulin).

```kotlin
companion object {
    val MIN_DIA = doubleArrayOf(5.0, 5.0, 5.0, 5.0, 5.0)        // Pump insulin
    val MIN_DIA_INHALED = doubleArrayOf(1.5, 1.5, 1.5, 1.5, 1.5) // Inhaled insulin
    val MAX_DIA = doubleArrayOf(9.0, 9.0, 9.0, 9.0, 10.0)
    // ...
}
fun minDiaInhaled(): Double  // New method
```

**File:** `ui/src/.../insulinManagement/InsulinManagementViewModel.kt`

Modify `saveCurrentInsulin()` validation (lines 317-323) to use `minDiaInhaled()` when the template is `OREF_INHALED_AFREZZA`:

```kotlin
val minDia = if (editedICfg.isInhaled()) hardLimits.minDiaInhaled() else hardLimits.minDia()
if (editedICfg.dia < minDia || editedICfg.dia > hardLimits.maxDia()) {
    // ...
}
```

**Decision:** How to identify an ICfg as "inhaled" — two options:

- **Option A (simple):** Check peak AND DIA ranges. If DIA < 5h, it must have been created from the inhaled template.
- **Option B (explicit, recommended):** Add a `deliveryRoute` field to ICfg:

```kotlin
enum class DeliveryRoute { SUBCUTANEOUS, INHALED }
```

This is cleaner and future-proofs for other non-pump insulins (e.g., intranasal research insulins). The field would be set from the InsulinType template and persisted with the ICfg.

### 1.3 Add Afrezza to Template List

**File:** `implementation/src/main/kotlin/app/aaps/implementation/insulin/InsulinImpl.kt`

```kotlin
override fun insulinTemplateList(): List<InsulinType> = listOf(
    InsulinType.OREF_RAPID_ACTING,
    InsulinType.OREF_ULTRA_RAPID_ACTING,
    InsulinType.OREF_LYUMJEV,
    InsulinType.OREF_FREE_PEAK,
    InsulinType.OREF_INHALED_AFREZZA   // <-- add
)
```

### 1.4 Validate IOB Math at Short DIA

**File:** `core/data/src/main/kotlin/app/aaps/core/data/model/ICfg.kt`

The oref exponential IOB model in `iobCalcForTreatment()` uses:

```
tau = tp * (1 - tp/td) / (1 - 2*tp/td)
```

where `tp` = peak (minutes), `td` = DIA (minutes).

With Afrezza parameters (tp=40, td=150):
- `tau = 40 * (1 - 40/150) / (1 - 80/150) = 40 * 0.733 / 0.467 = 62.8`
- `a = 2 * 62.8 / 150 = 0.837`
- `s = 1 / (1 - 0.837 + 1.837 * exp(-150/62.8)) = ...`

This should produce valid curves, but **must be validated with unit tests** to confirm:
- IOB starts at ~1.0 at t=0
- IOB reaches 0.0 at t=DIA
- Peak activity occurs near t=40 min
- No NaN or negative values
- The curve shape matches published Afrezza PK data

**New test file:** `plugins/insulin/src/test/kotlin/.../InsulinAfrezzaIobTest.kt`

Plot the curve against published Technosphere insulin pharmacokinetic data (Rave et al., Diabetes Technology & Therapeutics) to validate the model fit.

**Important:** The oref bilinear model was designed for subcutaneous insulin with DIA 5-8h. At DIA=2.5h, the curve shape may not accurately reflect Afrezza's true absorption profile. If validation shows poor fit, a custom curve function may be needed. However, since the IOB calculation is now on `ICfg` itself, adding an alternative model (e.g., a Weibull or log-normal curve parameterized for pulmonary absorption) is localized to one method.

---

## Phase 2: One-Tap Afrezza Logging UX

### 2.1 Existing Flow (Already Works)

With Phase 1 complete, users CAN log Afrezza today using the existing InsulinDialog:

1. Open Insulin Dialog
2. Toggle "Record Only" (since Afrezza isn't pump-delivered)
3. Select Afrezza from the insulin dropdown (populated from InsulinManager.insulins)
4. Enter dose amount
5. Confirm

This works but requires 5 taps and navigating a general-purpose dialog. For a feature used 3-5x daily at meals, it needs to be faster.

### 2.2 Afrezza Quick-Log Dialog

Create a dedicated Afrezza entry point — a streamlined dialog showing only cartridge-size buttons.

**New files:**
- `ui/src/.../afrezzaDialog/AfrezzaDialogScreen.kt`
- `ui/src/.../afrezzaDialog/AfrezzaDialogViewModel.kt`
- `ui/src/.../afrezzaDialog/AfrezzaDialogUiState.kt`

**UI design:** A bottom sheet with three large tap targets:

```
┌─────────────────────────┐
│   Log Afrezza Dose      │
├────────┬────────┬───────┤
│        │        │       │
│  4 U   │  8 U   │ 12 U  │
│        │        │       │
├────────┴────────┴───────┤
│  [Confirm]              │
└─────────────────────────┘
```

On tap:
1. User taps cartridge size
2. Confirmation dialog shows: "Log 8U Afrezza?"
3. User confirms → BS created with Afrezza ICfg, record-only, timestamp = now
4. Done. Two taps total.

**Implementation:** The ViewModel:
- Looks up the Afrezza ICfg from `insulinManager.insulins` (matched by `InsulinType.OREF_INHALED_AFREZZA` peak)
- Creates the bolus via `persistenceLayer.insertOrUpdateBolus(BS(..., iCfg = afrezzaICfg))`
- No pump command — always record-only
- Auto-sets `notes = "Afrezza inhaled"` for easy filtering

### 2.3 Home Screen Access Point

Add an Afrezza button to the AAPS overview quick-action buttons. The existing overview action bar has buttons for insulin, carbs, temp target, etc.

**File:** `plugins/main/src/.../general/overview/` — add Afrezza action alongside existing insulin action.

Alternatively, integrate with the existing Actions plugin as a new action type.

### 2.4 Android Notification Quick-Action

Create a persistent notification with Afrezza cartridge buttons, allowing logging from the notification shade without opening the app.

**File:** New service in `app/src/main/kotlin/.../services/AfrezzaNotificationService.kt`

---

## Phase 3: Safety Validation and Display

### 3.1 IOB Display Verification

The Overview IOB graph already sums all bolus IOB using per-bolus ICfg. After Phase 1, Afrezza boluses will automatically decay faster in the graph. **Verify:**

- The IOB graph shows Afrezza IOB decaying to zero by ~2.5h
- Combined IOB (Fiasp pump + Afrezza) displays correctly
- The prediction lines (UAM, ZT, IOB) account for both curves

**File to verify:** `workflow/src/.../PrepareIobAutosensGraphDataWorker.kt`

### 3.2 Distinguish Afrezza in Treatment History

When viewing treatments, Afrezza boluses should be visually distinct from pump boluses.

**File:** `plugins/main/src/.../general/overview/graphExtensions/BolusDataPoint.kt` or equivalent in the new Compose UI

Add an icon or color indicator for inhaled insulin (distinguish by `iCfg.deliveryRoute` or by matching the insulin label/peak).

### 3.3 oref Algorithm Interaction

The oref SMB algorithm uses IOB to decide when to issue correction boluses. With Afrezza, the fast IOB decay means oref will "see" IOB dropping earlier and may issue SMBs sooner. This is actually correct behavior — if Afrezza has worn off and BG is rising, the pump should step in.

**Verify:** Run the algorithm with simulated Afrezza + Fiasp scenarios to confirm:
- oref doesn't over-correct while Afrezza is still active
- oref correctly resumes delivery once Afrezza IOB drops
- No oscillation or instability from the two different decay curves

### 3.4 Nightscout Sync

**File:** `plugins/sync/src/.../nsclientV3/extensions/BolusExtension.kt`

Verify that the Afrezza ICfg (with short DIA) round-trips correctly through NS sync. The `toNSBolus()` / `toBolus()` converters currently don't serialize `iCfg`. This needs to be added so that:
- Afrezza boluses uploaded to NS retain their ICfg
- Afrezza boluses downloaded from NS are created with the correct ICfg (not the pump default)

---

## Phase 4: Wear OS Support

### 4.1 Afrezza Tile/Complication

Add a Wear OS tile with 4U/8U/12U buttons mirroring the phone quick-log UI.

**Directory:** `wear/src/main/kotlin/`

The existing Wear complication infrastructure for bolus logging can be extended.

---

## File Change Summary

### New Files

| File | Purpose |
|------|---------|
| `ui/src/.../afrezzaDialog/AfrezzaDialogScreen.kt` | One-tap Afrezza logging UI |
| `ui/src/.../afrezzaDialog/AfrezzaDialogViewModel.kt` | Afrezza logging logic |
| `ui/src/.../afrezzaDialog/AfrezzaDialogUiState.kt` | UI state |
| `plugins/insulin/src/test/.../InsulinAfrezzaIobTest.kt` | IOB curve validation tests |
| String resources for Afrezza labels | Localization |

### Modified Files

| File | Change |
|------|--------|
| `core/interfaces/.../insulin/InsulinType.kt` | Add `OREF_INHALED_AFREZZA` enum entry |
| `core/interfaces/.../utils/HardLimits.kt` | Add `MIN_DIA_INHALED`, `minDiaInhaled()` |
| `core/data/.../model/ICfg.kt` | Add `deliveryRoute` field (optional but recommended) |
| `implementation/.../insulin/InsulinImpl.kt` | Add Afrezza to `insulinTemplateList()` |
| `ui/.../insulinManagement/InsulinManagementViewModel.kt` | Use inhaled DIA limits for inhaled types |
| `database/.../entities/embedments/InsulinConfiguration.kt` | Add `deliveryRoute` field if using Option B |
| `database/.../persistence/converters/InsulinConfigurationExtension.kt` | Map `deliveryRoute` |
| `plugins/sync/.../nsclientV3/extensions/BolusExtension.kt` | Serialize/deserialize ICfg in NS sync |
| Overview action bar | Add Afrezza quick-action button |
| Navigation graph | Add route for Afrezza dialog |

### Database Migration

If adding `deliveryRoute` to `InsulinConfiguration`:
- New Room migration adding the column with default `SUBCUTANEOUS`
- Existing boluses are unaffected (all are pump-delivered → subcutaneous)

---

## Implementation Order

```
Step 1:  InsulinType.OREF_INHALED_AFREZZA enum entry
Step 2:  HardLimits — MIN_DIA_INHALED + minDiaInhaled()
Step 3:  ICfg — optional deliveryRoute field + DB migration
Step 4:  InsulinImpl — add to templateList()
Step 5:  InsulinManagementViewModel — route-aware DIA validation
Step 6:  IOB math unit tests at Afrezza parameters
Step 7:  Afrezza quick-log dialog (Screen + ViewModel + UiState)
Step 8:  Overview action bar integration
Step 9:  NS sync — ICfg serialization in bolus sync
Step 10: Wear OS tile
Step 11: Integration testing with AAPS loop simulation
```

Steps 1-6 form a minimal PR that enables Afrezza as a usable insulin type.
Steps 7-8 form a follow-up PR for the one-tap UX.
Steps 9-11 are polish/completeness PRs.

---

## Pharmacokinetic Reference Data

### Afrezza (Technosphere Insulin) — Published Parameters

| Parameter | 4U Cartridge | 8U Cartridge | 12U Cartridge |
|-----------|:----------:|:----------:|:-----------:|
| Onset | ~12 min | ~12 min | ~12 min |
| Tmax (peak) | 35-45 min | 40-50 min | 45-55 min |
| Duration (clinical) | 1.5-2 h | 2-2.5 h | 2.5-3 h |
| DIA (practical) | ~2 h | ~2.5 h | ~3 h |

Sources: Rave et al., Diabetes Technology & Therapeutics (2015); Afrezza prescribing information (MannKind Corporation).

**Design decision:** Use a single ICfg for all cartridge sizes (peak=40, DIA=2.5h) rather than per-size curves. The oref model already handles dose-proportional IOB scaling through the `bolus.amount` parameter. Per-size curve differences are small enough that a single model is clinically adequate, and it avoids requiring the user to maintain three separate insulin profiles.

---

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| oref bilinear model may not fit Afrezza PK curve well at DIA=2.5h | Unit test against published PK data; implement alternative curve if needed (localized to ICfg.iobCalcForTreatment) |
| User enters wrong Afrezza dose | Cartridge-size buttons (4/8/12U) prevent free-form entry errors |
| AAPS over-corrects after Afrezza wears off | This is actually correct behavior — oref should resume delivery. Validate with simulation. |
| NS sync loses Afrezza ICfg | Explicit serialization in BolusExtension; test round-trip |
| MIN_DIA change affects existing users | Separate MIN_DIA_INHALED constant; pump insulin limits unchanged |
| Existing AAPS community resistance | Feature-flagged; zero impact on non-Afrezza users; aligned with Issue #269 goals |

---

## Community Engagement Strategy

1. **Reference Issue #269** — "Insulin Management" improvement request (Jan 2021) directly aligns with this work
2. **Post design document** to AAPS Discord #dev channel before coding
3. **First PR: Core only** (Steps 1-6) — small, reviewable, testable
4. **Second PR: UX** (Steps 7-8) — separate review cycle
5. **Recruit beta testers** from Afrezza+pump communities (TuDiabetes, Reddit r/diabetes)
