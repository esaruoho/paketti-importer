# Paketti File Format Importer

The Import features of Paketti, my quality-of-life-tool for Renoise.

## Version 1.31 - Critical Fix: All Export Functions Verified

**ALL 38 export menu entries are now fully functional with complete implementations!**

- **Added:** PakettiOctaCycle.lua (OctaCycle generation for Octatrack)
- **Added:** PakettiITIExport.lua (Impulse Tracker Instrument export)
- **Added:** PakettiWTImport.lua (Wavetable export support)  
- **Updated:** PakettiIFFLoader.lua (complete version with all 9 export functions)
- **Added:** pitchBendDrumkitLoader() function in main.lua
- **Verified:** All 178 functions in 21 importer modules are properly integrated

## Version 1.30 - MAJOR UPDATE: Complete Export Integration

### NEW: 38 Export Menu Entries Added!
**ITI Export:**
- Export Instrument to ITI (Impulse Tracker Instrument)

**IFF/8SVX/16SV (Amiga Formats):**
- Load IFF Sample File
- Convert IFF ↔ WAV (bidirectional)
- Save Selected Sample as 8SVX (8-bit)
- Save Selected Sample as 16SV (16-bit)
- Batch Convert WAV/AIFF → 8SVX
- Batch Convert WAV/AIFF → 16SV  
- Batch Convert IFF/8SVX/16SV → WAV
- Batch Convert WAV → IFF

**Wavetable:**
- Export Wavetable (.WT)

**Complete Polyend PTI Suite (10 exporters):**
- Save Current Sample as PTI
- Export Subfolders as Melodic Slices
- Export Subfolders as Drum Slices
- Save Current as Drumkit (Mono/Stereo)
- Create 48 Slice Drumkit (Mono/Stereo)
- Melodic Slice Export (One-Shot)
- Melodic Slice Create Chain
- Melodic Slice Export Current

**Complete Digitakt Suite (4 exporters):**
- Export Sample Chain Dialog
- Quick Export (Mono)
- Quick Export (Stereo)
- Quick Export (Chain Mode)

**Complete Octatrack Suite (8 exporters):**
- Export (.WAV+.ot)
- Export (.ot only)
- Generate Drumkit (Smart Mono/Stereo)
- Generate Drumkit (Force Mono)
- Generate Drumkit (Play to End)
- Generate OctaCycle
- Quick OctaCycle (C, Oct 1-7)
- Export OctaCycle

### FIXED: AKAI S1000 Program Import
- Fixed "attempt to index local 'tab' (a string value)" error
- AKAI program files now load correctly with all sample mappings

## Version 1.21 Changes

### NEW: Digitakt Sample Chain Export
- **Full Digitakt/Digitakt 2 Support**: Export optimized sample chains for Elektron Digitakt hardware
- **Dual Export Modes**: Spaced (fixed slots) or Chain (concatenation)
- **Advanced Audio Processing**: Fade-out, TPDF dither, zero padding options
- **Auto-conversion**: Handles sample rate and bit depth conversion automatically

## Version 1.20 Changes

### MAJOR: Elektron Hardware Integration
- **Octatrack .ot Export/Import**: Full support for Elektron Octatrack .ot slice files
- **STRD/WORK Import**: Import Octatrack project banks with patterns, tracks, and trigs
- **Octatrack Drumkit Generation**: Create Octatrack-ready drumkits from multiple samples (Smart/Mono/Play-To-End modes)
- **Digitakt Sample Chain Export**: Export sample chains for Digitakt & Digitakt 2 (mono/stereo, spaced/chain modes)
- **Drag & Drop**: Supports dragging .ot, .strd, .work files directly into Renoise

## Version 1.10 Changes

### New Features
- **Preferences Dialog**: Access via **Main Menu → File → Paketti Formats → Paketti Formats Preferences...**
  - Toggle loading of default instrument template (12st_Pitchbend.xrni)
  - Toggle overwrite current vs. create new instrument
- **File Menu Integration**: All import/export/convert features accessible via **Main Menu → File → Paketti Formats**
- **SFZ Batch Converter**: Convert multiple SFZ files to XRNI with optional auto-load
- **Octatrack Integration**: Full .ot file import/export with slice data + drumkit generation + STRD/WORK project import
- **ITI Import**: Impulse Tracker Instrument support (includes IT214/IT215 decompression)
- **Raw Binary Import**: Load .exe, .dll, .bin, .sys, .dylib as 8-bit samples
- **Image to Waveform**: Convert PNG, BMP, JPG, JPEG, GIF to audio waveforms (Requires Renoise API 6.2+)

### Configuration

**Main Menu → File → Paketti Formats → Paketti Formats Preferences...**

- **Load Default Instrument**: Enable/disable loading the Paketti default instrument template (default: ON)
- **Overwrite Current Instrument**: Choose between creating new instruments or overwriting current (default: OFF)

## How to Use

### Method 1: Drag & Drop
Simply drag any supported file format from your file browser directly into Renoise.

### Method 2: File Menu
**Main Menu → File → Paketti Formats** provides menu entries for all supported formats:

**Import:**
- Import .ITI (Impulse Tracker Instrument)
- Import .REX (ReCycle V1)
- Import .RX2 (ReCycle V2)
- Import .SF2 (SoundFont 2)
- Import .PTI (Polyend Tracker Instrument)
- Import .IFF (Amiga IFF)
- Import .8SVX (Amiga 8-bit)
- Import .16SV (Amiga 16-bit)
- Import .P/.P1/.P3 (AKAI Program)
- Import .S/.S1/.S3 (AKAI Sample)
- Import Raw Binary as Sample
- Import Image as Waveform (API 6.2+)
- Import Samples from .MOD

**Export:**
- Export Current Sample as .PTI

**Convert:**
- Convert RX2 to PTI
- Batch Convert SFZ to XRNI (Save Only)
- Batch Convert SFZ to XRNI & Load

**Settings:**
- Paketti Formats Preferences...

# Supported Formats

## Importing

### Sample Formats
- .REX (ReCycle V1 Legacy format)
- .RX2 (ReCycle V2 format)
- .IFF (OctaMED, ProTracker, SoundTracker - 8SVX/16SV)
- .SF2 (Soundfont V2)
- .PTI (Polyend Tracker Instrument)
- .MOD (ProTracker modules - import all samples)
- .S, .S1, .S3 (AKAI S1000/S3000 sample files - **IMPORT ONLY**)
- Polyend device formats (Tracker, Play, Medusa)

### Instrument Formats
- .P, .P1, .P3 (AKAI S1000/S3000 program files - **IMPORT ONLY**)
- .ITI (Impulse Tracker Instrument)

### Raw Binary
- .EXE, .DLL, .BIN, .SYS, .DYLIB (8-bit raw import at 8363Hz)

### Image to Waveform (Requires Renoise API 6.2+)
- .PNG, .BMP, .JPG, .JPEG, .GIF (converts image data to waveforms)

### Octatrack (Elektron)
- **.OT** (Octatrack slice files with drag & drop support)
  - Import: Reads .ot metadata + applies slices to loaded .wav
  - Auto-loads corresponding .wav if found in same directory
  - Debug dialog shows complete .ot analysis (tempo, slices, metadata)
- **.STRD/.WORK** (Octatrack project banks)
  - Imports complete patterns with tracks and trigs
  - Auto-creates Renoise tracks and instruments
  - Preserves tempo, pattern length, and instrument assignments

## Exporting

**Menu: Main Menu → File → Paketti Export**

### ITI (Impulse Tracker)
- Export Instrument to ITI

### IFF/8SVX/16SV (Amiga)
- Load IFF Sample File
- Convert IFF to WAV / Convert WAV to IFF
- Save Selected Sample as 8SVX (8-bit) / 16SV (16-bit)
- Batch Convert WAV/AIFF to 8SVX / 16SV
- Batch Convert IFF/8SVX/16SV to WAV
- Batch Convert WAV to IFF

### Wavetable
- Export Wavetable (.WT)

### Polyend Tracker (PTI) - 10 Exporters
- Save Current Sample as PTI
- Export Subfolders as Melodic Slices / Drum Slices
- Save Current as Drumkit (Mono) / (Stereo)
- Create 48 Slice Drumkit (Mono) / (Stereo)
- Melodic Slice Export (One-Shot)
- Melodic Slice Create Chain
- Melodic Slice Export Current

### Digitakt - 4 Exporters
- Export Sample Chain (Dialog with all options)
- Quick Export (Mono/Stereo/Chain Mode)
- 48kHz, 16-bit optimization
- Spaced/Chain modes, Fade-out, TPDF dither

### Octatrack - 8 Exporters
- Export (.WAV+.ot) / (.ot only)
- Generate Drumkit (Smart Mono/Stereo, Force Mono, Play to End)
- Generate OctaCycle / Quick OctaCycle (C, Oct 1-7) / Export OctaCycle
- 44.1kHz, 16-bit, max 64 slices

## Converting

- **RX2 → PTI**: Convert ReCycle RX2 files to Polyend Tracker Instrument format
- **SFZ → XRNI (Batch)**: Convert multiple SFZ files to XRNI format with Paketti default instrument settings
  - **Save Only**: Converts and saves XRNI files to disk
  - **Save & Load**: Converts, saves, and loads all XRNI files into separate instrument slots

# Discord

- [Discord](https://discord.gg/Qex7k5j4wG)

# What is Paketti?

Please check out [http://github.com/esaruoho/paketti/](http://github.com/esaruoho/paketti/)

# Support

If you like this project, or Paketti, please consider the following:
- [Ko-Fi](https://ko-fi.com/esaruoho)
- [PayPal](https://www.paypal.com/paypalme/esaruoho)
- [GitHub Sponsors](https://github.com/sponsors/esaruoho?frequency=one-time&sponsor=esaruoho)
- [Gumroad](https://lackluster.gumroad.com/l/paketti)
- [Patreon](http://patreon.com/esaruoho)
- [Bandcamp](http://lackluster.bandcamp.com)
