# Real Size Previewer

A native macOS PDF viewer that displays each PDF page at the physical size it will have when printed.

The app combines three measurements:

1. the PDF crop box in PDF points (72 points per inch),
2. the intended printed width and height in millimetres, and
3. the current monitor's logical width and measured physical width.

AppKit then maps the calculated logical size to the display's backing pixels. This is important on Retina/HiDPI screens: multiplying the scale by 2 would make the preview physically incorrect, because macOS already performs that conversion.

## Requirements

- macOS 13 or newer
- Xcode 15+ or the matching Swift toolchain

## Build and run

For development:

```sh
swift run
```

To create a Finder-launchable application bundle:

```sh
chmod +x scripts/build_app.sh
./scripts/build_app.sh
open "build/Real Size Previewer.app"
```

The resulting app is local and unsigned. For distribution to other Macs, sign and notarize it with an Apple Developer certificate.

## Use

1. Open or drag a PDF into the window.
2. In **Display calibration**, enter the physical width of the lit display area. Measuring the width is more reliable than using the marketed diagonal. You can also enter the diagonal or use the size reported by the display hardware.
3. Enter the final printed PDF dimensions. Keep proportions locked for an exact resized page, or unlock them to fit the PDF proportionally inside a target sheet such as A4.
4. Keep preview zoom at **100% / Actual size** for a physically accurate view.
5. Compare the on-screen 10 cm ruler with a real ruler as a calibration check.

Calibration is stored separately for each connected display. Moving the window to another monitor switches to that monitor's logical resolution, Retina backing scale, and saved physical measurement.

The open PDF is monitored for changes on disk. Direct writes and atomic-save replacements are reloaded automatically while preserving the current page, preview zoom, visible page region, and chosen print sizing. The PDF panel shows when the latest automatic reload occurred. Trackpad and PDFKit gesture zoom changes are reflected in the toolbar percentage as a multiple of the calibrated actual size.

## Application icon

The editable vector artwork is stored in `Resources/AppIcon.svg`. The asset catalog contains the required macOS raster sizes, and `Resources/AppIcon.icns` is copied into release application bundles. After editing the SVG, regenerate the assets with:

```sh
./scripts/generate_icon.sh
```

Icon generation requires `rsvg-convert` from librsvg and Xcode's asset compiler.

## Tests

```sh
swift test
```

The tests cover PDF-point conversion, fit-to-sheet sizing, diagonal-to-width geometry, preview zoom, and the deliberate separation of logical points from Retina backing pixels.
