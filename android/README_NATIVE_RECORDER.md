# Native recorder integration

The Flutter UI intentionally separates recorder controls from the capture engine.

For a production Android recorder:
1. Request MediaProjection permission.
2. Capture the display using VirtualDisplay.
3. Feed frames into MediaCodec H.264/HEVC.
4. Use the selected width/height and frame rate when creating the encoder.
5. Mux encoded video with MediaMuxer.
6. Run capture in a foreground service for long recordings.
7. Store the MP4 in app media storage.
8. Optionally upload the finished file to Firebase Storage.

This is the correct architecture for reliable 60 FPS/1080p capture and background/foreground optimization. A generic Flutter widget alone cannot guarantee those targets across Android devices.
