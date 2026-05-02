# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
