# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-05-07

### Added
- **9 new platforms** alongside Apple II 40/80-col: Commodore PET, Commodore 64, Commodore 128 (80-col), VIC-20, Atari 8-bit, Atari ST, ZX Spectrum, Amiga, MS-DOS
- **Per-platform colour models** — phosphor radio (Apple II, PET) or full hardware-palette swatch picker (C64, C128, VIC-20, Atari 8-bit, ZX Spectrum, Amiga, Atari ST, MS-DOS) with independent foreground/background selection
- **Per-platform colour memory** — switching platforms restores the colours you last picked for each
- **Live crop tool** — draggable, resizable selection box with locked aspect ratio, rule-of-thirds grid, pinch-zoom, two-finger trackpad pan, mouse-wheel zoom; the converter re-runs as you drag
- **Character picker popover** — every glyph in the current platform's font in a scrollable grid; click to add to a custom ramp, click again to remove
- **PNG export** at 1×, 2×, or 4× the platform's native resolution
- **Bundled fonts:** Pet Me 64, Pet Me 2X, Pet Me 128 2Y, Perfect DOS VGA 437, EightBit Atari, ZX Spectrum, Amiga Topaz, Atari ST 8x16 System Font
- New character ramps: PETSCII Blocks, PETSCII Symbols, CP437 Blocks
- Show 1977 Window and 1977 Help (⌘?) menu commands

### Changed
- Custom ramp text field and preset preview now render in the **current platform's font** (was system monospaced) — Mousetext, PETSCII, block, and box-drawing glyphs render correctly
- Custom-ramp characters that the new platform's font lacks are silently pruned on platform switch (no more "?" boxes)
- Glyph horizontal scaling fix for non-native row counts (e.g. 48 rows on Apple II 40-col): characters now fill their cell width instead of leaving alternating empty stripes

### Fixed
- C64 / MS-DOS fonts not registering at runtime — registration now happens programmatically via `CTFontManagerRegisterFontsForURL` for both `.ttf` and `.otf`
- VIC-20 squeezed horizontally — now uses `Pet Me 2X` for correct double-width pixel aspect (352 × 184)
- Atari ST 3.2 : 1 ultrawide preview — replaced square 8×8 font with a true 8×16 system font for the correct 1.6 : 1 aspect

## [1.0.0] - 2026-05-02

### Added
- Image-to-Apple II ASCII art conversion in 40-column and 80-column modes
- 24-row (one screen) and 48-row (two screens) output sizes
- Four built-in character ramps — Apple II Classic, Standard ASCII, Simple, Dense — plus a custom ramp text field
- Brightness and contrast sliders with live preview (debounced 150 ms)
- Invert toggle for dark-on-light vs light-on-dark output
- Horizontal and vertical flip buttons
- Phosphor screen preview in green (#33FF00), amber (#FFB000), or white
- Authentic Apple II fonts bundled — PrintChar21 (40-col) and PRNumber3 (80-col) from [kreativekorp](https://www.kreativekorp.com/software/fonts/apple2/)
- Apple II screen aspect ratio preserved (280 × 192 display, BT.709 perceptual luminance sampling)
- Drag-and-drop image import (PNG, JPEG, TIFF, GIF, BMP, HEIC)
- Open Image file picker (⌘O)
- Copy ASCII art to clipboard (⇧⌘C)
- Export to Apple II text (`.txt` with CR / 0x0D line endings, 7-bit ASCII)
- Export to Mac text (`.txt` with LF line endings, UTF-8)
- Export to Applesoft BASIC (`.bas` PRINT program, auto-inserts `PR#3` for 80-col)
- App sandbox enabled with user-selected files read/write entitlement
