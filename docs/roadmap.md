# Product Roadmap & Future Capabilities

## Phase 1 (Completed)
- [x] Rigid Upper Craniofacial Triad 3D pose tracking (Speech & JBL Live 770NC immunity).
- [x] Casiez 1€ filter and smooth continuous dead-zone transfer function.
- [x] Roll-decomposed horizon alignment.
- [x] Multi-frame MAD neutral pose calibrator.
- [x] Dwell clicking with live spatial radial progress HUD.
- [x] Target magnetism via macOS Accessibility API (`AXUIElement`).
- [x] Face-loss safety freeze and physical mouse override detection.
- [x] Python reference prototype and native Swift 6 macOS application (`HeadMotionMouse.app`).
- [x] 100% deterministic test vector parity.

## Phase 2 (Completed Extensions)
- [x] **Drag-and-Drop Mode:** Dwell or gesture toggle with live HUD "DRAG" badge and macOS `leftMouseDragged` event injection.
- [x] **Audible Confirmation Feedback:** Native macOS audio clicks (`NSSound` Tink / Pop) for tactile confirmation on clicks and state changes.
- [x] **Smoothing Profile Presets:** One-click presets ("Balanced", "Precision / CAD", "Responsive / Fast", and "Accessibility / High-Tremor") with automatic 1€ filter parameter scaling.
- [x] **Mouth-Open / Jaw-Drop Secondary Action:** Orthogonal facial expression trigger operating independently of the Upper Craniofacial Triad (speech & headphone immune).
- [x] **Swift 6 Strict Concurrency Compliance:** Clean zero-warning build across actors and closures.

## Phase 3 (Future Capabilities)
- [ ] **Multi-Display Edge Hopping:** Rapid double-glance or hotkey gesture to instantly transition cursor across multi-monitor setups.
- [ ] **Adaptive Velocity Profiles:** Context-aware sensitivity switching (e.g., precision snapping in CAD vs high-speed sweeping in web browsers).
- [ ] **Apple Silicon Neural Engine (ANE) CoreML Custom Pipeline:** Quantized FP16 CoreML pipeline for sub-millisecond inference on M-series chips.
