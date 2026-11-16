# Gesture Recognition Specification

## 1. Dwell Click (Primary Hands-Free Click)
Dwell clicking enables intentional mouse clicks without muscle strain:

### 1.1 State Machine
1. **IDLE:** Cursor moving or waiting for stabilization.
2. **DWELLING:** Cursor remains within circular radius $R_{\text{dwell}} = 18.0\text{ px}$. A live radial progress ring renders around cursor position $(x_{\text{anchor}}, y_{\text{anchor}})$.
   $$\text{Progress}(t) = \min\left(1.0, \frac{t - t_{\text{start}}}{T_{\text{dwell}}}\right), \quad T_{\text{dwell}} = 800\text{ ms}$$
3. **TRIGGERED:** When $\text{Progress}(t) = 1.0$, emit `CGEvent` mouse click (Left Click by default, or Right Click if secondary mode is armed).
4. **COOLDOWN:** Post-click refractory period $T_{\text{cooldown}} = 1000\text{ ms}$. No new dwell can initiate.
5. **RE-ARMING:** After cooldown, the cursor must travel at least $D_{\text{rearm}} = 25.0\text{ px}$ from $(x_{\text{anchor}}, y_{\text{anchor}})$ before a new dwell countdown is permitted.

### 1.2 Cancellation Rules
- If $\sqrt{(x_t - x_{\text{anchor}})^2 + (y_t - y_{\text{anchor}})^2} > R_{\text{dwell}}$, immediately abort timer, dismiss HUD, and return to **IDLE**.
- On face loss or low confidence ($< 0.65$), instantly abort timer and reset state.

## 2. Intentional Blink Click (EAR-Based)
### 2.1 Eye Aspect Ratio (EAR)
Computed independently for left and right eyes:
$$\text{EAR} = \frac{\lVert p_2 - p_6\rVert + \lVert p_3 - p_5\rVert}{2\,\lVert p_1 - p_4\rVert}$$
Blink closure is declared when $\text{EAR} < \text{EAR}_{\text{threshold}}$ (calibrated baseline $\times 0.65$, typically $\approx 0.18$).

### 2.2 Temporal Classification Windows
- **$t < 80\text{ ms}$:** Sensor noise / micro-twitch (ignored).
- **$80\text{ ms} \le t \le 200\text{ ms}$:** Involuntary spontaneous blink (ignored).
- **$200\text{ ms} < t < 280\text{ ms}$:** Intentional safety dead-band (no action).
- **$280\text{ ms} \le t \le 650\text{ ms}$:** Deliberate Intentional Blink Click (triggers Left Click on eye open).
- **$t > 800\text{ ms}$:** Restful closure, fatigue, or looking down (ignored; no click).

### 2.3 Double-Blink for Secondary Click
If a second deliberate blink arrives within $400\text{ ms}$ of the first, upgrade event to **Right Click**.

## 3. Nod Gesture & Pitch Zone Scrolling
### 3.1 Nod Gesture
- Detected when pitch drops by $\ge 4.5^\circ$ and rebounds to neutral within a $450\text{ ms}$ temporal window.
- Lateral yaw stability requirement: $|\Delta \psi| < 2.0^\circ$ throughout the motion.
- Mutually exclusive with Dwell: actively suppressed if a dwell countdown is in progress.

### 3.2 Continuous Pitch-Tilt Scrolling
- When pitch exceeds $\pm 8.0^\circ$ beyond the dead zone and holds for $\ge 300\text{ ms}$, enter scroll mode:
  $$V_{\text{scroll}} = \operatorname{sign}(\theta) \cdot k_{\text{scroll}} \cdot (|\theta| - \theta_{\text{threshold}})^{1.4}$$
- Visual scroll HUD chevron indicates direction and scrolling intensity.
