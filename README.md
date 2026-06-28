# Eversense E3/365 CGM Plugin for AndroidAPS dev

Patches to add Eversense E3 and E365 CGM support to any AndroidAPS dev build.

Developed by [n0rb33r7](https://github.com/n0rb33r7), [bastiaanv](https://github.com/bastiaanv), and [CAPTCG](https://github.com/CAPTCG).

---

## Patches Included

| Patch | Description | Apply Order |
| --- | --- | --- |
| `eversense-combined.patch` | Full Eversense E3/365 BLE driver, plugin, and core integration | 1st |
| `eversense-e3-stabilization-v2.patch` | E3 stabilization fixes for BT sync, placement signal, and timer drift | 2nd |

---

## Requirements

- An existing AndroidAPS dev clone from https://github.com/nightscout/AndroidAPS
- Android Studio
- Git

---

## How to Add Eversense to Your AndroidAPS Dev Build

### Step 1 - Download the patches

Click the green Code button on this page and select Download ZIP.

Extract the ZIP somewhere on your computer e.g. `C:\EversensePatches\`

> **Note:** The base patch is verified to apply cleanly against AndroidAPS dev commit [`3616b5a476`](https://github.com/nightscout/AndroidAPS/commit/3616b5a476) (`fix showing head`). If upstream dev has newer commits, the patch may fail to apply. In that case, check back here for an updated patch or open an issue.

### Step 2 - Switch to the dev branch

Before applying the patches, make sure you are on the dev branch. In Android Studio:

1. Look at the bottom right corner and click the branch name
2. Find `origin/dev` in the list and click Checkout
3. Wait for Android Studio to finish switching branches

Note: If you do not see `origin/dev`, click Fetch first.

### Step 3 - Apply both patches in order

Open the Terminal in Android Studio and run:

    git am --3way C:/EversensePatches/eversense-combined.patch
    git apply C:/EversensePatches/eversense-e3-stabilization-v2.patch
    git add -A
    git commit -m "E3 stabilization: BT sync, placement signal, timer drift (E3 only, 365 unchanged)"

### Step 4 - Verify

    git log --oneline -2

You should see both commits: the Eversense integration and the E3 stabilization.

### Step 5 - Build

1. File → Sync Project with Gradle Files
2. Build → Generate Signed Bundle/APK → APK → full → release
3. Install the APK on your phone

---

## What the Base Patch Adds (eversense-combined.patch)

- Complete Eversense E3 and E365 BLE driver with GATT callback, SecureV2 crypto, and all packet types
- EversensePlugin with DMS cloud upload, calibration, status, and placement activities
- Core registration — SourceSensor enums, DB models, PluginsListModule, notification IDs
- E365 auth with shortcut optimization — DMS only called on fresh install/restart
- E365 BLE disconnect timeout set to 0 (never disconnect)
- E365 fullSync failure handling — disconnects to reset BLE session
- E3 calibration with correct register addresses and clock drift sync
- E3 battery percentage with correct register mapping
- Credential sync from AAPS preferences into SECURE_STATE
- Package namespace: `app.aaps.plugins.eversense`

---

## What the Stabilization Patch Fixes (eversense-e3-stabilization-v2.patch)

Field-tested E3 fixes contributed by [overfrenk](https://github.com/overfrenk). All changes are E3-specific — E365 behavior is unchanged.

**1. Bluetooth Sync Optimization and Lag Removal**

The previous system suffered from 1–2 minute delays or missed cycles due to rigid timers and the parking buffer. The glucose freshness cutoff was reduced from 270s to 60s, the full sync threshold from 270s to 180s, and the BLE disconnect timeout from 300s to 10s. Glucose data delivery to AAPS is now near-instantaneous and aligned with the hardware push packets.

**2. Placement Signal Stability**

Optimized the management of diagnostic packets for transmitter placement on the arm. Diagnostic mode now toggles on `onResume`/`onPause` instead of `onCreate`/`onDestroy`, making the UI more responsive. Removed the `rssiToStrength` override during RSSI reads that caused anomalous signal spikes. The placement indicator no longer flickers with erratic values, making the pairing procedure smoother and more reliable.

**3. Home Screen Time Drift Fix (E3 only)**

The sensor age counter on the AAPS home screen was constantly slipping backward. This was caused by the forced overwriting of the SENSOR_CHANGE event at every Bluetooth cycle, which injected the raw transmitter uptime (subject to the chip's deep-sleep pauses). This overwrite is now disabled for E3 only — AAPS uses the system timestamp (absolute clock) and no longer loses minutes, allowing precise manual reset by the user. E365 retains the original sync behavior.

---

## Transmitter Support

| Transmitter | Notes |
| --- | --- |
| Eversense E3 (180-day) | Standalone after initial sensor initialization via official Eversense app |
| Eversense 365 (1-year) | Standalone — after first successful auth, works indefinitely offline/airplane mode |

---

## Related

- PR: https://github.com/nightscout/AndroidAPS/pull/4869
- Original work: https://github.com/nightscout/AndroidAPS/pull/4474
