# Calibration & Neutral Baseline Specification

## 1. Overview
Accurate spatial tracking requires calibrating the user's natural resting head pose $(\psi_0, \theta_0, \phi_0)$ while seated comfortably facing their display.

## 2. Sampling Pipeline
1. **Window Duration:** $2.5\text{ seconds}$ at target frame rate ($30\text{ fps}$), accumulating $N \ge 45$ raw pose vectors $(\psi_k, \theta_k, \phi_k)$.
2. **Quality Gate:** If tracking confidence drops below $0.65$ on any frame, that frame is discarded. If fewer than 45 valid frames are captured within 4.0 seconds, the calibration aborts with error `INSUFFICIENT_DATA`.

## 3. Statistical Filtering: Median Absolute Deviation (MAD)
For each angular component $x \in \{\psi, \theta, \phi\}$:
1. Compute median:
   $$M = \operatorname{median}(\{x_i\}_{i=1}^N)$$
2. Compute Median Absolute Deviation:
   $$\text{MAD} = \operatorname{median}(\{|x_i - M|\}_{i=1}^N)$$
3. Compute normal-consistent dispersion scale:
   $$\hat{\sigma} = 1.4826 \times \text{MAD}$$
4. Filter outliers:
   $$\text{Inliers} = \{x_i \mid \lvert x_i - M\rvert \le 2.5 \cdot \hat{\sigma}\}$$
   If $\text{MAD} = 0$, all points equal to $M$ are inliers.

## 4. Stability Verification Gate
Before accepting the calibration:
1. Compute standard deviation of inliers:
   $$\sigma_{\text{inlier}} = \sqrt{\frac{1}{K}\sum_{j=1}^K (x_j - \bar{x}_{\text{inlier}})^2}$$
2. Stability Threshold: If $\sigma_{\text{inlier}} > 1.8^\circ$ on either yaw or pitch, reject calibration:
   `CALIBRATION_REJECTED_EXCESSIVE_MOTION`
   Prompt the user to remain still and retry.

## 5. Baseline Parameter Estimation
The final neutral baseline $(\psi_0, \theta_0, \phi_0)$ is computed as the $10\%$ trimmed mean (or Huber mean) of the inlier set.
All subsequent runtime calculations compute deltas relative to this baseline:
$$\Delta \psi = \psi - \psi_0, \quad \Delta \theta = \theta - \theta_0, \quad \Delta \phi = \phi - \phi_0$$
