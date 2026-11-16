# Movement & Spatial Coordinate Specification

## 1. Coordinate Systems & Sign Conventions

### 1.1 Camera vs Head Frame
In standard webcam view (before mirroring), looking towards the camera:
- $+X$: User's physical left
- $+Y$: Downwards towards chin
- $+Z$: Away from camera into the scene

After horizontal mirroring (selfie/mirror convention):
- $+X_{\text{cam}}$: User's physical right
- $+Y_{\text{cam}}$: Downwards
- $+Z_{\text{cam}}$: Forward depth

### 1.2 Euler Angles (Intrinsic Y-X-Z Convention)
- **Yaw ($\psi$):** Head rotation around vertical axis.
  - Turning head right: $\psi > 0$
  - Turning head left: $\psi < 0$
- **Pitch ($\theta$):** Head rotation around transverse horizontal axis.
  - Tilting head up: $\theta < 0$ (maps to screen $-Y$, upward cursor motion)
  - Tilting head down: $\theta > 0$ (maps to screen $+Y$, downward cursor motion)
- **Roll ($\phi$):** Head tilt around longitudinal axis (ear to shoulder).
  - Tilting right ear to right shoulder: $\phi > 0$

### 1.3 macOS Core Graphics Screen Coordinates
- Origin `(0, 0)` is at the top-left of the primary display.
- $+X_{\text{screen}}$ extends to the right.
- $+Y_{\text{screen}}$ extends downwards.

Sign mapping table:
| Physical Movement | Angular Delta | Screen Vector | Visual Result |
| :--- | :--- | :--- | :--- |
| Turn head Right | $\Delta \psi > 0$ | $+\Delta X$ | Cursor moves Right |
| Turn head Left | $\Delta \psi < 0$ | $-\Delta X$ | Cursor moves Left |
| Tilt head Up | $\Delta \theta < 0$ | $-\Delta Y$ | Cursor moves Up |
| Tilt head Down | $\Delta \theta > 0$ | $+\Delta Y$ | Cursor moves Down |

## 2. Roll-Decomposed Horizon Alignment
When a user naturally holds their head with a slight roll $\phi_0$, uncorrected horizontal sweeps produce diagonal drift. We rotate angular deltas into the user's horizon:
$$\begin{pmatrix} \Delta \psi_{\text{proj}} \\ \Delta \theta_{\text{proj}} \end{pmatrix} = \begin{pmatrix} \cos(-\phi_0) & -\sin(-\phi_0) \\ \sin(-\phi_0) & \cos(-\phi_0) \end{pmatrix} \begin{pmatrix} \Delta \psi \\ \Delta \theta \end{pmatrix}$$

## 3. Smooth Dead-Zone Function
To eliminate resting physiological micro-tremor without abrupt boundary discontinuities:
$$\Delta \alpha_{\text{dz}} = \begin{cases} 0 & \text{if } \lvert\Delta \alpha\rvert \le d \\ \operatorname{sign}(\Delta \alpha) \cdot \dfrac{(\lvert\Delta \alpha\rvert - d)^2}{\lvert\Delta \alpha\rvert - d + \epsilon} & \text{if } \lvert\Delta \alpha\rvert > d \end{cases}$$
where $\epsilon = 10^{-6}$.

## 4. Casiez One Euro (1€) Filter
Timestamp-driven velocity-adaptive low-pass filtering:
1. $\Delta t = t_k - t_{k-1}$ (using monotonic high-resolution clock; if $\Delta t \le 0$, fall back to $1/30\text{ s}$).
2. Raw velocity: $\dot{x}_k = (x_k - x_{k-1}) / \Delta t$
3. Filtered velocity:
   $$\alpha_d = \frac{1}{1 + \dfrac{1}{2\pi \cdot f_{c_d} \cdot \Delta t}}, \quad \hat{\dot{x}}_k = \alpha_d \dot{x}_k + (1 - \alpha_d) \hat{\dot{x}}_{k-1}$$
4. Dynamic cutoff frequency:
   $$f_c = f_{c_{\min}} + \beta \cdot \lvert\hat{\dot{x}}_k\rvert$$
5. Position filter smoothing factor:
   $$\alpha = \frac{1}{1 + \dfrac{1}{2\pi \cdot f_c \cdot \Delta t}}, \quad \hat{x}_k = \alpha x_k + (1 - \alpha) \hat{x}_{k-1}$$

Default parameters:
- $f_{c_{\min}} = 1.0\text{ Hz}$
- $\beta = 0.04$
- $f_{c_d} = 1.0\text{ Hz}$

## 5. Parallax Compensation & Translation Invariance
Pure rotation $\mathbf{R}$ from Levenberg-Marquardt `solvePnP` is mathematically independent of translation $\mathbf{t}$. For hybrid mappings incorporating projected nose tip displacement:
$$\psi_{\text{corr}} = \psi - k_{\text{parallax}} \cdot \operatorname{arctan2}(T_x, T_z)$$
$$\theta_{\text{corr}} = \theta - k_{\text{parallax}} \cdot \operatorname{arctan2}(T_y, T_z)$$
In a pure rotation model, $k_{\text{parallax}} = 0.0$. In hybrid position-assisted mode, $k_{\text{parallax}} = 0.65$ compensates for incidental camera perspective shifts.

## 6. Dual-Mode Mapping Engines
1. **Direct Absolute Precision Mode:**
   Normalized screen position:
   $$u_x = \frac{\Delta \psi_{\text{filtered}}}{2 \cdot \text{yaw\_range\_deg}} + 0.5$$
   $$u_y = \frac{\Delta \theta_{\text{filtered}}}{2 \cdot \text{pitch\_range\_deg}} + 0.5$$
   Clamped to $[0, 1]$ and mapped to display frame width and height.

2. **Hybrid Center-Absolute + Edge Auto-Pan Mode:**
   - Central $80\%$ region: direct 1:1 absolute mapping.
   - Outer $10\%$ border zone: continuous velocity auto-pan proportional to distance past the border threshold.
