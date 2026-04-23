# Vision Pose Plugin for OBS

A high-performance OBS plugin for macOS Apple Silicon that utilizes Apple's native **Vision framework** to detect human pose landmarks in real-time. Landmark data is broadcasted via WebSockets for use in overlays, diagnostic UIs, and interactive installations within the mediaWarp ecosystem.

## Features

- **Native Vision Integration**: Leverages Apple's hardware-accelerated Vision framework for low-latency pose detection.
- **Apple Silicon Optimized**: Built specifically for M-series chips to maximize performance and efficiency.
- **Real-time Data Streaming**: Transmits landmark coordinates (JSON) via a centralized WebSocket bridge.
- **Low Overhead**: Efficient frame capturing and processing to maintain high OBS frame rates.
- **Seamless mediaWarp Integration**: Compatible with `media-warp-transmit` signal protocols.

## Installation

### Prerequisites

- **macOS**: 12.0 or newer (Apple Silicon required).
- **OBS Studio**: 30.0 or newer.

### Standard Installation

1. Download the latest release from the [GitHub Releases](https://github.com/your-repo/vision-pose-plugin/releases) page.
2. Extract the `vision-pose-plugin.plugin` bundle.
3. Copy the bundle to your OBS plugins directory:
   `~/Library/Application Support/obs-studio/plugins/`

## Usage

1. Open OBS Studio.
2. Add a **Video Capture Device** or select an existing video source.
3. Right-click the source and select **Filters**.
4. Add the **Vision Pose Detector** filter.
5. (Optional) Configure the WebSocket identifier in the filter settings to match your overlay's expected type.

## Technical Architecture

The plugin is structured as a standard OBS video filter:

- **Capture**: Intercepts video frames directly from the OBS source pipeline.
- **Processing**: Scales and converts frames to a format suitable for the `VNDetectHumanBodyPoseRequest`.
- **Inference**: Executes the Vision request on the GPU/Neural Engine.
- **Transmission**: Formats the resulting landmarks into JSON and triggers the `media_warp_transmit` signal to the WebSocket bridge.

## Development

### Build Requirements

- Xcode 15+
- CMake 3.28+
- ccache (optional, for faster builds)

### Building Locally

```zsh
# Configure using the macOS preset
cmake --preset macos

# Build the plugin
cmake --build --preset macos
```

The build artifact will be located in `build/macos/vision-pose-plugin.plugin`.

### CI/CD

This project uses GitHub Actions for automated builds. The pipeline ensures:
- Strict `arm64` architectural compliance.
- Automated dependency management for `libobs` and `Qt6`.
- Production-ready bundling and packaging.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Developed as part of the **mediaWarp** suite for Advanced Agentic Coding and real-time media manipulation.
