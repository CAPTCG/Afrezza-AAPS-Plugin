# Afrezza (Technosphere) Inhaled Insulin Plugin for AndroidAPS

A patch that adds Afrezza inhaled insulin as a first-class insulin type in AndroidAPS — its own
pharmacokinetic curve, hard limits, dose-logging dialog (phone and Wear OS), and IOB tracking that
runs independently of whatever injected/pumped insulin the loop is already using.

Developed by [CAPTCG](https://github.com/CAPTCG).

This is an experimental, community-developed modification. It is not approved by any regulatory
body. **Discuss any changes to your diabetes management with your endocrinologist before use, and
always keep fingerstick meter access as a backup.**

---

## What This Patch Adds

- **Afrezza as a real insulin type** (`InsulinType.OREF_INHALED_AFREZZA`) in Insulin Management,
  alongside Novorapid/Fiasp/Lyumjev/etc. — factory default peak 15 min, DIA 1.5 h, per published
  Technosphere pharmacokinetic data.
- **Its own hard-limit ranges** — inhaled insulin acts far faster than injected insulin, so it's
  validated against `HardLimits.LIMIT_PEAK_INHALED` (10–30 min) and `LIMIT_DIA_INHALED` (1.0–3.0 h)
  instead of the standard injected-insulin ranges, which would reject every valid Afrezza profile.
- **Stored, not derived, identity** — `ICfg.isInhaled` is authored in the insulin editor and
  persisted (DB, JSON catalogue, Nightscout sync), not re-derived from the peak value on every read.
  That means editing the peak anywhere in its valid 10–30 min range keeps the dose recognized as
  Afrezza — earlier designs that inferred "inhaled" purely from an exact peak match lost that
  identity the moment a user adjusted it off the factory default.
- **One-tap dose logging** — a dedicated Afrezza dialog (phone) and Wear OS tile/activity, both
  offering the three real cartridge sizes (4U / 8U / 12U). Logged as a `BS.Type.NORMAL` bolus using
  the U100-equivalent halved amount (4U → 2.0, 8U → 4.0, 12U → 6.0), tagged with the Afrezza `ICfg`
  so IOB math uses the correct curve.
- **Distinct treatment-list presentation** — Afrezza doses show their own "Afrezza" type label and
  icon in the treatment list and Overview action bar, instead of being lumped in as a generic "Meal
  Bolus".
- **Full Nightscout sync** — the `isInhaled` flag round-trips through NS sync (`NSICfg`/`RemoteICfg`)
  and the local database (reconstructed from the stored peak where an older payload has no flag, since
  the inhaled and injected peak ranges are disjoint and unambiguous).
- **Local-only, never remote-deliverable** — Afrezza is inhaled directly by the user; the app is
  documenting a dose that already physically happened, not commanding a pump. It's explicitly kept
  off the master/client relay path (same category as Fill) and rejected outright if invoked from an
  AAPS client, so a dose is never silently duplicated or desynced between master and client.

---

## Requirements

- An existing AndroidAPS dev clone from https://github.com/nightscout/AndroidAPS, **or** let the
  apply script clone one for you
- Android Studio
- Git

---

## How to Apply

### Option 1 — automated script (recommended)

1. Download this repository (Code → Download ZIP, or `git clone`).
2. Run the applicator for your platform from the extracted folder:

   **Windows (PowerShell):**
       .\apply-afrezza-patches.ps1

   **macOS/Linux:**
       ./apply-afrezza-patches.sh

   By default this clones AndroidAPS dev into `../AndroidAPS-Afrezza` next to this folder, checks
   out the exact commit the patch was verified against, creates a `feature/afrezza-inhaled-insulin`
   branch, and applies + commits the patch. Pass a path as the first argument to use an existing
   clone instead.

### Option 2 — manual

    git clone https://github.com/nightscout/AndroidAPS.git
    cd AndroidAPS
    git checkout 283a184f60eb8b18dac42e228faebbe260c3aa22
    git checkout -b feature/afrezza-inhaled-insulin
    git apply --verbose /path/to/patches/afrezza-combined.patch
    git add -A
    git commit -m "Add Afrezza inhaled insulin support"

> **Note:** the patch is a plain `git diff`, applied with `git apply` — **not** `git am`. It is
> verified to apply cleanly, with zero conflicts, against AndroidAPS dev at commit
> [`283a184f6`](https://github.com/nightscout/AndroidAPS/commit/283a184f60eb8b18dac42e228faebbe260c3aa22).
> If upstream dev has moved on since, either check out that exact commit first (recommended — the
> app still builds and runs fine on it), or apply with `--3way` and resolve any conflicts by hand
> before trusting it for real dosing.

### Build

1. File → Sync Project with Gradle Files
2. Build → Generate Signed Bundle/APK → APK → full → release
3. Build the Wear OS module too if you use a watch: `:wear:assembleFullRelease`
4. Install the APK(s) on your phone/watch

---

## Setting Up Afrezza After Installing

1. Open **AAPS Settings → Insulin Management**.
2. Add a new insulin, and pick the **Afrezza** template from the list — this seeds the correct
   inhaled peak/DIA defaults and marks it as inhaled.
3. Adjust peak/DIA within the inhaled ranges (10–30 min peak, 1.0–3.0 h DIA) if your own response
   differs from the factory default; the peak field is locked from the general preset chips since
   Afrezza's peak range doesn't overlap the injected-insulin presets.
4. Once an inhaled insulin exists in your insulin list, the **Afrezza** button appears in the
   Overview action bar / treatment dialog (and the Wear OS action list) automatically.
5. To log a dose: tap **Afrezza**, pick the cartridge you inhaled (4U / 8U / 12U), confirm. It's
   logged immediately as a bolus with the Afrezza curve — no wizard/carb entry required, though the
   dialog offers to open the Bolus Calculator afterward if you also want to log carbs for the meal.

---

## Known Limitations

- This patch is actively evolving. Check this repo's commit history for the latest state before
  relying on it for a real dosing decision.
- The IOB curve uses AAPS's existing bilinear oref model with Afrezza-specific peak/DIA parameters,
  not a distinct pharmacokinetic model — this is clinically adequate per the published Technosphere
  data but is not a perfect fit to Afrezza's real absorption curve at every point.
- A single `ICfg` covers all three cartridge sizes; per-size curve differences are small enough that
  AAPS's existing dose-proportional IOB scaling (via `bolus.amount`) handles it without needing three
  separate insulin profiles.
- `docs/IMPLEMENTATION_PLAN.md` is the original design/research document from before implementation
  started — useful for the pharmacokinetic sourcing and reasoning, but some of its specifics (notably
  the single fixed `peak=40min, DIA=2.5h` design) were superseded by what's described above. See the
  note at the top of that file.

---

## Related

- Nightscout `AndroidAPS` issue #269 ("Insulin Management" improvement request) motivated part of
  the underlying per-bolus insulin-configuration groundwork this patch builds on.
