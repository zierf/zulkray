# Zulkray

Project based on the series [Ray Tracing in One Weekend](https://raytracing.github.io/) ([GitHub](https://github.com/RayTracing/raytracing.github.io)),
written in Zig and inspired by [kristRTX](https://github.com/kristoff-it/kristRTX//).

Rendering may be done with _Vulkan_ in the future.

## Build and Run

```SH
$> zig version
0.14.1

$> zig build run -Doptimize=ReleaseSafe
```

Create a [Portable Pixmap](https://en.wikipedia.org/wiki/Netpbm#File_formats) `image.ppm`.

```SH
zig build run -Doptimize=ReleaseSafe > image.ppm
```

## Preview Image in VS Code

Use the plugin [PBM/PPM/PGM Viewer for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ngtystr.ppm-pgm-viewer-for-vscode)
to open the _Pixmap Image_ in an extra editor panel.
It's image view refreshes while writing the rendered pixels into the file.
