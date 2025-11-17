# Paketti Formats

Import and export tools for Renoise - hardware sampler integration and vintage format support.

**Version 1.354 - First Official Release**

## Import Features

### Hardware Samplers
- **AKAI S1000/S3000**: Programs (.p, .P1, .P3) and Samples (.s, .S1, .S3)
- **Elektron Octatrack**: .ot slice files, .strd/.work project banks
- **Polyend Tracker**: .pti instrument files

### Sample Formats
- **REX/RX2**: ReCycle V1 and V2 with automatic slice detection
- **SF2**: SoundFont 2 with multi-sample support
- **IFF/8SVX/16SV**: Amiga formats with automatic conversion
- **ITI**: Impulse Tracker Instruments (IT214/IT215 decompression)
- **MOD**: ProTracker modules (extracts all samples)
- **SFZ**: Multi-file instrument definitions

### Special Import
- **Raw Binary**: .exe, .dll, .bin, .sys, .dylib as 8-bit samples @ 8363Hz
- **Images to Waveform**: .png, .bmp, .jpg, .jpeg, .gif (Requires Renoise API 6.2+)
- **Wavetables**: .wt format

## Export Features

### Hardware Export
- **Elektron Octatrack**:
  - .ot slice files with .wav
  - Drumkit generators (Smart/Mono/Play-to-End)
  - OctaCycle generator (multi-octave single-cycle waveforms)
- **Elektron Digitakt**:
  - Sample chain export (mono/stereo)
  - Digitakt 1 & 2 support
- **Polyend Tracker**:
  - .pti instrument export
  - Drumkit export (mono/stereo)
  - 48-slice drumkit generator
  - Melodic slice export
  - Drum slice export

### Format Export
- **ITI**: Impulse Tracker Instruments
- **IFF/8SVX/16SV**: Amiga formats
- **Wavetables**: .wt format

### Batch Conversions
- WAV/AIFF ↔ IFF/8SVX/16SV
- SFZ → XRNI (with auto-load option)

## How to Use

### Drag & Drop
Simply drag supported files into Renoise - they'll be automatically imported as instruments with proper sample mappings and keyboard zones.

### File Menu
All features are accessible via:
- **Import**: Main Menu → File → Paketti Formats → Import [Format]
- **Export**: Main Menu → File → Paketti Formats → Export → [Destination]
- **Convert**: Main Menu → File → Paketti Formats → Convert [Format]

### Preferences
Configure default behavior at: **Main Menu → File → Paketti Formats → Paketti Formats Preferences**

Options:
- Load default instrument template (12st_Pitchbend.xrni)
- Overwrite current instrument vs. create new

## Requirements

- Renoise 3.4.0 or later (API version 6+)
- Image import requires Renoise API 6.2+
- RX2 import requires bundled decoder (included)

## Support

If you find this tool useful:
- [Ko-Fi](https://ko-fi.com/esaruoho)
- [BuyMeACoffee](https://buymeacoffee.com/esaruoho)
- [PayPal](https://www.paypal.me/esaruoho)
- [GitHub Sponsors](https://github.com/sponsors/esaruoho)
- [Patreon](http://patreon.com/esaruoho)
- [Bandcamp](http://lackluster.bandcamp.com/)

## Credits

Created by Lackluster (esaruoho)  
Based on Paketti quality-of-life tool for Renoise

Special thanks to the Renoise community and hardware sampler enthusiasts who helped reverse-engineer these formats.
