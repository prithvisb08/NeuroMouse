# Privacy & Hardware Agnostic Architecture

## 1. Zero-Network Runtime Guarantee
HeadMotion Mouse operates with strict, uncompromising privacy constraints:
- **Zero Cloud Inference:** 100% of computer vision processing occurs on-device in local system RAM.
- **Zero Telemetry or Phone-Home:** No analytics, crash reports, or telemetry payloads are transmitted across the network.
- **Zero Disk Persistence of Images:** Video frames captured by the FaceTime webcam are processed as transient `CVPixelBuffer` / in-memory NumPy arrays and discarded immediately upon pose calculation. No face imagery, video recordings, or facial scans are ever written to disk.
- **Zero Biometric Identity Storage:** The system computes relative 3D craniofacial orientation angles $(\psi, \theta, \phi)$. It never computes facial identity embeddings, face recognition hashes, or biometric identifiers.

## 2. Model Asset Handling & Offline Integrity
- **Native macOS Application (`macos-app/`):**
  Uses Apple's native `Vision.framework` (`VNFaceObservation` and `VNDetectFaceLandmarksRequest`). These models are pre-installed by macOS on the Neural Engine / GPU and execute 100% offline with zero downloads.
- **Python Reference Prototype (`python-prototype/`):**
  Requires the Google MediaPipe Face Landmarker bundle (`face_landmarker.task`). To guarantee the zero-network runtime constraint, the model asset is vendored directly into the repository at `python-prototype/models/face_landmarker.task` (or fetched once during `./scripts/setup.sh` with pinned SHA-256 checksum `64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff`). At runtime, it loads strictly from local disk.

## 3. Privacy Shutter Mode
Users can toggle Privacy Shutter Mode at any time (via hotkey `P` or the Dashboard button):
- The live video preview feed is completely blacked out.
- Underlying mathematical craniofacial tracking continues uninterrupted.

## 4. Headphone & Hardware Agnosticism
- **Over-Ear Headphone Immunity (JBL Live 770NC):**
  Users often wear standard over-ear consumer headphones during desk work. HeadMotion Mouse anchors exclusively to the **Rigid Upper Craniofacial Triad** (nasion, nose bridge, eye canthi, forehead), which are completely visible even when large over-ear cups cover the ears and temples.
- **Zero IMU Dependency:**
  The system requires no external inertial measurement units, no Arduino/ESP32, no Bluetooth sensors, and does not require AirPods `CMHeadphoneMotionManager` APIs.
