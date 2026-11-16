# Landmark Mapping Specification: MediaPipe vs Apple Vision

## 1. Overview & Rigid Upper Craniofacial Anchor Set
To guarantee complete immunity against speech deformation (jaw and lip movement) and occlusion from over-ear headphones (e.g. JBL Live 770NC covering ears and temples), HeadMotion Mouse anchors exclusively to the **Rigid Upper Craniofacial Triad**.

Lower facial landmarks (menton, gnathion, cheilion, jawline gonion) are strictly omitted from 3D pose estimation.

## 2. Canonical 3D Metric Model (mm)
Origin is set at the Pronasale (nose tip) or midpoint between inner canthi:
- **Pronasale (Nose Tip):** `[0.0, 0.0, 0.0]`
- **Nasion / Glabella (Between Eyebrows):** `[0.0, 38.0, -12.0]`
- **Left Endocanthion (Inner Canthus):** `[-22.0, 26.0, -28.0]`
- **Right Endocanthion (Inner Canthus):** `[22.0, 26.0, -28.0]`
- **Left Exocanthion (Outer Canthus):** `[-55.0, 28.0, -42.0]`
- **Right Exocanthion (Outer Canthus):** `[55.0, 28.0, -42.0]`
- **Left Supraorbital (Mid-Eyebrow):** `[-38.0, 48.0, -25.0]`
- **Right Supraorbital (Mid-Eyebrow):** `[38.0, 48.0, -25.0]`

## 3. MediaPipe Face Landmarker Indices (478-point model)
| Anatomical Landmark | MediaPipe Index | Role |
| :--- | :--- | :--- |
| Pronasale (Nose Tip) | `1` | Primary translational & rotational anchor |
| Nasion / Glabella | `168` | Vertical axis anchor (pitch baseline) |
| Left Endocanthion | `133` | Horizontal eye baseline (roll/yaw) |
| Right Endocanthion | `362` | Horizontal eye baseline (roll/yaw) |
| Left Exocanthion | `33` | Lateral face horizon |
| Right Exocanthion | `263` | Lateral face horizon |
| Left Supraorbital | `105` | Cranial rigid frame validation |
| Right Supraorbital | `334` | Cranial rigid frame validation |

### MediaPipe Eyelid Landmarks for Eye Aspect Ratio (EAR)
EAR computation follows the Soukupová & Čech formulation:
$$\text{EAR} = \frac{\lVert p_2 - p_6\rVert + \lVert p_3 - p_5\rVert}{2\,\lVert p_1 - p_4\rVert}$$

- **Left Eye Indices:**
  - $p_1$: `33` (outer corner)
  - $p_2$: `160` (top outer)
  - $p_3$: `158` (top inner)
  - $p_4$: `133` (inner corner)
  - $p_5$: `153` (bottom inner)
  - $p_6$: `144` (bottom outer)
- **Right Eye Indices:**
  - $p_1$: `362` (inner corner)
  - $p_2$: `385` (top inner)
  - $p_3$: `387` (top outer)
  - $p_4$: `263` (outer corner)
  - $p_5$: `373` (bottom outer)
  - $p_6$: `380` (bottom inner)

## 4. Apple Vision Framework Landmarks (`VNFaceObservation`)
In macOS native `Vision.framework`, `VNFaceObservation` provides:
1. `yaw`, `pitch`, `roll` properties directly computed by Apple's on-device neural network (used as high-speed prior).
2. `VNFaceLandmarks2D` regions:
   - `nose`: `normalizedPoints` (tip at index `0` or lowest y)
   - `noseCrest`: top-most point corresponds to Nasion
   - `leftEye`: `normalizedPoints` (first and last points for canthi)
   - `rightEye`: `normalizedPoints` (first and last points for canthi)
   - `leftEyebrow`: `normalizedPoints`
   - `rightEyebrow`: `normalizedPoints`

The Swift `CraniofacialPoseEstimator` combines the coarse `VNFaceObservation` orientation prior with upper-craniofacial geometric alignment in `simd`.
