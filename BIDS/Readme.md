# DICOM — BIDS, including T1 denoising (End‑to‑End README)

This README describes a clean, reproducible workflow for taking raw MRI exports through to **BIDS‑valid** datasets with optional **MP2RAGE UNI denoising**. It covers the order of operations, when to use each script, and key exceptions/branching logic so you know which path to follow in tricky cases.

---

## ✨ At a glance — the right order (with branches & exceptions)

**Typical path (recommended):**

1) **`rename_reorder.sh`** (optional)  
   Standardise incoming study/folder names and series ordering right after export.

2) **`DCM_NiFTI.sh`**  
   Convert DICOM → NIfTI (e.g., via `dcm2niix`).

3) **MP2RAGE denoising — choose ONE (depending on input format & goals):**  
   **A.** **NIfTI path:** `NoiseStrip_NiFTI.m` (MATLAB)  
   **B.** **DICOM path:** `NoiseStrip.m` (MATLAB)

4) **`BIDS.sh`**  
   Move/rename to BIDS layout (subjects/sessions, modalities, filenames, JSON sidecars).

5) **`check_BIDS.sh`**  
   Run the BIDS validator (and any internal checks). Fix anything flagged and re‑run until clean.

**When to pick A vs B in Step 3:**  
- Pick **A (NIfTI)** if you already converted with `DCM_NiFTI.sh` and intend to keep analysis in NIfTI/BIDS (FreeSurfer, fMRIPrep, MRtrix, etc.).  
- Pick **B (DICOM)** if you need the **denoised series in DICOM** (e.g., for PACS ingestion, preserving DICOM headers/series semantics), or if you want denoising **before** any conversion.

> **Do not run both denoising paths on the same data**. Choose either the NIfTI or DICOM denoiser to avoid double processing.

---

## 🧭 Decision guide (common exceptions)

- **Your export contains classic MP2RAGE folders (INV1/INV2/UNI) in DICOM:**  
  You can **denoise in DICOM (B)** first, _then_ convert to NIfTI → BIDS.  
  Or convert first → denoise in NIfTI (A) → BIDS. Both are supported. Choose based on downstream needs.

- **You already have NIfTIs from the scanner or prior conversion:**  
  Skip DICOM steps; go straight to **NIfTI denoising (A)** → `BIDS.sh` → `check_BIDS.sh`.

- **Mixed/odd exports (one 4D DICOM per series vs many 3D slices):**  
  The denoising scripts auto‑detect **4D volumes vs multiple 3D images** and safely handle **mismatched counts** by using the largest common set (see “What the MATLAB denoisers do”).

- **Already processed datasets:**  
  The denoisers and BIDS steps are conservative: they check for **existing outputs** and skip those participants/sets to avoid clobbering. Delete/rename outputs if you want a fresh run.

---

## 🔧 Prerequisites

- **Shell scripts:** standard POSIX shell + common tools.  
  - `DCM_NiFTI.sh`: requires `dcm2niix` (or your site’s DICOM→NIfTI converter).  
  - `BIDS.sh`: your BIDS mover/renamer depends on how you encode subject/session and sequence metadata.  
  - `check_BIDS.sh`: BIDS Validator (Node.js package or Docker/Singularity image).

- **MATLAB denoisers:**  
  - MATLAB R2018b+ recommended.  
  - Image Processing Toolbox (for `dicomread/dicominfo/dicomwrite`) and NIfTI I/O (`niftiread/niftiinfo/niftiwrite`).  
  - Update the **`basepath`**, **`participants`**, and (for NIfTI) the **file patterns** to match your data.  
  - Parameter **`beta`** controls the denoising strength (default `10000`).

---

## 🗂️ Script‑by‑script details

### 0) `rename_reorder.sh` (optional but helpful)
**Purpose:** normalise folder and file naming straight out of the scanner, and (if needed) reorder series to your expected chronology.  
**Use when:** different consoles/techs output slightly different names, or to simplify downstream pattern matching for INV1/INV2/UNI.  
**Outputs:** same DICOM tree but with consistent names and predictable order.  
**Skip when:** your exports are already tidy and your downstream patterns match them reliably.

### 1) `DCM_NiFTI.sh`
**Purpose:** batch‑convert DICOM → NIfTI + JSON sidecars, preserving essential metadata.  
**Use when:** moving from DICOM to NIfTI/BIDS workflows (MRtrix, FreeSurfer, fMRIPrep).  
**Tips:**  
- Keep originals read‑only. Write NIfTIs into a parallel `derivatives/` or `converted/` tree.  
- Use consistent subject IDs (e.g., `sub-001`) now—this pays off in BIDS.

### 2) MP2RAGE denoising (choose **one** path)

#### A) `NoiseStrip_NiFTI.m` (MATLAB, NIfTI input)
- **Input:** NIfTI **INV1**, **INV2**, and **UNI** volumes in the same space/resolution.  
- **What it does:**  
  - Loads the three volumes, validates matching dims, computes `V5 = (UNI * (INV1^2 + INV2^2) + β) / ((INV1^2 + INV2^2) + 2β)`.  
  - Saves a **denoised UNI** as NIfTI (datatype chosen to fit original scaling), writes a **comparison figure** and a **metrics text file** (noise reduction %, correlation).  
- **Why this path:** convenient for BIDS‑centric analysis; stays in NIfTI.  
- **Outputs:** `*_denoised.nii[.gz]`, `[sub]_set[ID]_comparison.png`, metrics `.txt` in the participant folder.

#### B) `NoiseStrip.m` (MATLAB, DICOM input)
- **Input:** DICOM **INV1**, **INV2**, **UNI** series under each participant.  
- **What it does:**  
  - Detects **4D** vs **multiple 3D** layouts, handles **mismatched slice counts** by clipping to common length, computes the same denoised UNI, and writes a **new DICOM series** (fresh UIDs, safe metadata handling) to `MP2RAGE_UNIDEN/`.  
  - Also saves a **comparison PNG** (original vs denoised middle slice).  
- **Why this path:** yields a **DICOM series** suitable for PACS archiving or DICOM‑native post‑processing before conversion.  
- **Outputs:** `MP2RAGE_UNIDEN/denoised_*.dcm` + comparison PNG under the participant.

> **Parameter `beta`:** The default (`10000`) works well for typical MP2RAGE UNI; increase modestly if residual noise is visible, decrease if you see oversmoothing/contrast compression.

### 3) `BIDS.sh`
**Purpose:** move/rename the (possibly denoised) NIfTI+JSON files into a **valid BIDS** tree.  
**Key points:**  
- Adopt the **BIDS naming** for MP2RAGE (e.g., `inv-1`, `inv-2`, `UNIT1`/`UNI`, `T1map` where applicable).  
- Ensure crucial metadata (TR, TE, TI, flip angles, etc.) are in JSON sidecars.  
- If you denoised in **DICOM**, run `DCM_NiFTI.sh` on the **denoised DICOM series**, then push those NIfTIs through `BIDS.sh`.

### 4) `check_BIDS.sh`
**Purpose:** validate your dataset.  
**What to expect:**  
- Missing or malformed sidecars, wrong suffixes, or misspelled entities.  
- Session/subject ID mismatches.  
- Non‑compliant custom fields.  
**Fix, then re‑run** until you get a green result.

---

## 📁 Directory conventions

```
project_root/
  raw/                                # immutable DICOM exports (optionally renamed/reordered)
    sub-001/ MP2RAGE_... (INV1/INV2/UNI)
    sub-002/ ...
  converted/                          # DICOM→NIfTI output (if you convert early)
    sub-001/
  denoised/                           # optional staging area if you prefer (else keep alongside subject)
  bids/                               # final BIDS tree
    sub-001/
    sub-002/
  logs/                               # command logs, validator reports
```

You can also keep denoised outputs **with** the participant under `raw/sub-XXX/` (DICOM path) or `converted/sub-XXX/` (NIfTI path). The denoisers are designed to **skip** already processed participants/sets to avoid duplication.

---

## 🧪 What the MATLAB denoisers do (technical notes)

Both denoisers implement the same MP2RAGE UNI denoising formula with robust guardrails:

- Auto‑detect **4D** vs **multiple 3D** imagery.
- Gracefully handle **mismatched INV1/INV2/UNI counts** by clipping to the common number of slices/volumes.
- Skip a participant/set if **outputs already exist**.
- For DICOM: safely **clean metadata**, set new **UIDs**, **SeriesDescription** suffix, **SeriesNumber**, and **InstanceNumber**, and write a fresh DICOM series.
- Save **comparison figures** (and, for NIfTI, **metrics**: noise reduction %, correlation).

Tuning knobs you may touch:
- `beta` (denoising strength)
- `basepath` and `participants` loop
- NIfTI filename patterns (`*inv1*`, `*inv2*`, `*uni*`) if your converter uses different tokens

---

## ▶️ Example invocations

```bash
# 0) Optional normalisation
bash rename_reorder.sh /path/to/raw

# 1) Convert
bash DCM_NiFTI.sh /path/to/raw /path/to/converted

# 2A) NIfTI denoising (MATLAB, from converted)
matlab -batch "run('NoiseStrip_NiFTI.m')"

#     OR 2B) DICOM denoising (MATLAB, from raw)
matlab -batch 'run("NoiseStrip.m")'

# 3) BIDS structuring (point to denoised NIfTI if you denoised in DICOM)
bash BIDS.sh /path/to/converted /path/to/bids

# 4) Validate
bash check_BIDS.sh /path/to/bids > logs/bids_validator.txt
```

> If you denoised in DICOM (2B), be sure to run `DCM_NiFTI.sh` **on the denoised series** before `BIDS.sh`.

---

## 🛠️ Troubleshooting

- **“Missing MP2RAGE folders/files”**: confirm your INV1/INV2/UNI **names/patterns**. For NIfTI, adjust `inv1_pattern`, `inv2_pattern`, `uni_pattern` in the script.  
- **“Volume dimensions do not match”**: ensure INV1/INV2/UNI are coregistered and un‑altered. Mixed resolutions or partial coverage will be flagged.  
- **“Already processed — skipping”**: delete or rename existing outputs (`*_denoised.nii.gz`, `MP2RAGE_UNIDEN/`) if you want to re‑run.  
- **DICOM write errors**: the DICOM path strips problematic fields and regenerates UIDs; ensure you have write permission in `MP2RAGE_UNIDEN/`.  
- **Low contrast after denoise**: try reducing `beta` (e.g., 6000–8000). If residual noise persists, increase slightly (e.g., 12000–15000).  
- **BIDS validator fails**: check entity order (`sub-`, `ses-`, `acq-`, `run-`, `inv-`, `part-`), suffix naming, and JSON schema conformity.

---

## ✅ Good practices

- Treat `raw/` as **immutable**. Always write into `converted/`, `denoised/`, and `bids/` trees.  
- Keep **logs** of conversions, denoising params (`beta`), and validator outputs for provenance.  
- Use **consistent subject IDs** across the entire pipeline.  
- Re‑run `check_BIDS.sh` after any renaming or denoising changes.

---

## 📌 Summary — when to use exceptions

### 🧩 Additional exception — QSM DICOM metadata fixer

**Script:** `QSM_fix.m`

**When to use:**  
Some QSM datasets are exported in a **3D DICOM slice-by-slice format** with inconsistent or incomplete metadata. This often breaks NIfTI conversion tools (e.g. `dcm2niix`) because they can’t group slices into a single series.

**What it does:**  
- Detects **3D vs 4D QSM exports**:  
  - If single large 4D DICOM → skips (already fine).  
  - If multiple 3D slices → applies metadata fix.  
- Reads all slice headers, cleans problematic fields, and rewrites a consistent **“_FIXED” DICOM series**.  
- Ensures **same SeriesInstanceUID** across slices, consistent **SeriesDescription/SeriesNumber**, proper **slice positioning**, and regenerates valid UIDs.  
- Scales pixel data to safe 12-bit range if input is floating point.  
- Verifies output consistency after writing.

**Outputs:**  
- New folder `[original_name]_FIXED/` with corrected DICOM files.  
- Safe for direct NIfTI conversion (`dcm2niix` etc.) or later BIDS organisation.

**Summary decision rule:**  
- **If QSM DICOM conversion fails** or produces broken/misaligned NIfTIs → run `QSM_fix.m` first, then re-convert.  
- Otherwise, skip — the fixer is only needed for legacy/problematic 3D QSM exports.


- **Data are already NIfTI:** skip DICOM steps ⇒ use `NoiseStrip_NiFTI.m` ⇒ `BIDS.sh` ⇒ `check_BIDS.sh`.  
- **You need DICOM outputs for PACS:** denoise first with `NoiseStrip.m` ⇒ convert denoised DICOM ⇒ `BIDS.sh` ⇒ `check_BIDS.sh`.  
- **Odd DICOM exports (4D vs 3D, mismatched counts):** both denoisers handle this; prefer NIfTI path if your downstream is BIDS‑centric.  
- **Re‑runs:** existing outputs will be skipped—clear outputs if intentionally reprocessing.

---

### Maintainers
- L.K.L. Oestreich


