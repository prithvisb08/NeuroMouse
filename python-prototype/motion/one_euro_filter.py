"""
Casiez One Euro (1€) Filter.
Real-time velocity-adaptive low-pass filter specifically designed for noisy human input signals.
Dynamically balances jitter reduction at low velocities with low latency during rapid movements.
Reference: Géry Casiez, Nicolas Roussel, Daniel Vogel (CHI 2012).
"""

import math
from typing import Optional, Tuple


class OneEuroFilter:
    """
    Precision 1D Casiez One Euro Filter with timestamp-driven adaptive smoothing.
    """

    def __init__(
        self,
        min_cutoff: float = 1.0,
        beta: float = 0.04,
        d_cutoff: float = 1.0,
    ) -> None:
        """
        Args:
            min_cutoff: Minimum cutoff frequency (Hz) at zero velocity. Higher suppresses jitter.
            beta: Velocity adaptation coefficient. Higher reduces lag on quick movement.
            d_cutoff: Cutoff frequency (Hz) for the derivative filter.
        """
        self.min_cutoff = float(min_cutoff)
        self.beta = float(beta)
        self.d_cutoff = float(d_cutoff)

        self._x_prev: Optional[float] = None
        self._dx_prev: float = 0.0
        self._t_prev: Optional[float] = None

    def _smoothing_factor(self, cutoff: float, dt: float) -> float:
        """Computes alpha smoothing coefficient given cutoff frequency and delta time."""
        tau = 1.0 / (2.0 * math.pi * cutoff)
        return 1.0 / (1.0 + tau / dt)

    def filter(self, x: float, timestamp: float) -> float:
        """
        Filters a new incoming scalar observation with monotonic timestamp.

        Args:
            x: Raw input value.
            timestamp: Monotonic time in seconds (e.g. time.monotonic()).

        Returns:
            Filtered output value.
        """
        if self._t_prev is None or self._x_prev is None:
            self._x_prev = float(x)
            self._dx_prev = 0.0
            self._t_prev = float(timestamp)
            return float(x)

        dt = float(timestamp - self._t_prev)
        if dt <= 0.0:
            dt = 1.0 / 30.0

        # Estimate and filter the velocity derivative
        raw_dx = (float(x) - self._x_prev) / dt
        alpha_d = self._smoothing_factor(self.d_cutoff, dt)
        filtered_dx = alpha_d * raw_dx + (1.0 - alpha_d) * self._dx_prev

        # Compute dynamic cutoff based on filtered velocity
        cutoff = self.min_cutoff + self.beta * abs(filtered_dx)
        alpha = self._smoothing_factor(cutoff, dt)

        # Filter the position
        filtered_x = alpha * float(x) + (1.0 - alpha) * self._x_prev

        # Update historical state
        self._x_prev = filtered_x
        self._dx_prev = filtered_dx
        self._t_prev = float(timestamp)

        return filtered_x

    def reset(self) -> None:
        """Resets the internal state of the filter."""
        self._x_prev = None
        self._dx_prev = 0.0
        self._t_prev = None

    @property
    def current_cutoff(self) -> float:
        """Returns the last computed dynamic cutoff frequency in Hz."""
        return self.min_cutoff + self.beta * abs(self._dx_prev)


class OneEuroFilter2D:
    """Convenience wrapper for independent 2D (x, y) filtering."""

    def __init__(
        self,
        min_cutoff: float = 1.0,
        beta: float = 0.04,
        d_cutoff: float = 1.0,
    ) -> None:
        self.fx = OneEuroFilter(min_cutoff, beta, d_cutoff)
        self.fy = OneEuroFilter(min_cutoff, beta, d_cutoff)

    def filter(self, x: float, y: float, timestamp: float) -> Tuple[float, float]:
        return (self.fx.filter(x, timestamp), self.fy.filter(y, timestamp))

    def reset(self) -> None:
        self.fx.reset()
        self.fy.reset()
