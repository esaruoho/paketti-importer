local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix
require "process_slicer"
require "utils"
require "importers/PakettiSF2Loader"
require "importers/PakettiREXLoader"
require "importers/PakettiRX2Loader"
require "importers/PakettiPTILoader"
require "importers/PakettiIFFLoader"
require "importers/s1000p"
require "importers/s1000s"
require "importers/PakettiPolyendSuite"
require "importers/PakettiPolyendMelodicSliceExport"
require "importers/PakettiPolyendSliceSwitcher"
require "importers/PakettiITIImport"
require "importers/PakettiRawImport"
require "importers/PakettiSFZBatchConverter"
require "importers/PakettiOTExport"
require "importers/PakettiOTSTRDImporter"
require "importers/PakettiOctaCycle"
require "importers/PakettiDigitakt"
require "importers/PakettiITIExport"
require "importers/PakettiWTImport"
if renoise.API_VERSION >= 6.2 then
  require "importers/PakettiImageToSample"
end
-- Keyhandler function for dialogs
function my_keyhandler_func(dialog, key)
  if key.modifiers == "" and key.name == "esc" then
    dialog:close()
    return key
  else
    return key
  end
end

-- PitchBend Drumkit Loader function
function pitchBendDrumkitLoader()
  local selected_sample_filenames = renoise.app():prompt_for_multiple_filenames_to_read({"*.wav", "*.aif", "*.flac", "*.mp3", "*.aiff"}, "Paketti PitchBend Drumkit Sample Loader")
  if #selected_sample_filenames == 0 then
    renoise.app():show_status("No files selected.")
    return
  end
  
  local song=renoise.song()
  local current_instrument_index = song.selected_instrument_index
  local current_instrument = song:instrument(current_instrument_index)
  
  if #current_instrument.samples > 0 or current_instrument.plugin_properties.plugin_loaded then
    song:insert_instrument_at(current_instrument_index + 1)
    song.selected_instrument_index = current_instrument_index + 1
  end
  
  current_instrument_index = song.selected_instrument_index
  current_instrument = song:instrument(current_instrument_index)
  
  local drumkit_path = renoise.tool().bundle_path .. "12st_Pitchbend_Drumkit_C0.xrni"
  renoise.app():load_instrument(drumkit_path)
  
  current_instrument_index = song.selected_instrument_index
  current_instrument = song:instrument(current_instrument_index)
  
  local instrument_slot_hex = string.format("%02X", current_instrument_index - 1)
  local instrument_name_prefix = instrument_slot_hex .. "_Drumkit"
  
  local max_samples = 120
  local num_samples_to_load = math.min(#selected_sample_filenames, max_samples)
  
  local selected_sample_filename = selected_sample_filenames[1]
  local sample = renoise.song().selected_instrument.samples[1]
  local sample_buffer = sample.sample_buffer
  local samplefilename = selected_sample_filename:match("^.+[/\\](.+)$")
  
  current_instrument.name = instrument_name_prefix
  sample.name = samplefilename
  
  if sample_buffer:load_from(selected_sample_filename) then
    renoise.app():show_status("Sample " .. selected_sample_filename .. " loaded successfully.")
  else
    renoise.app():show_status("Failed to load the sample.")
  end
  
  for i = 2, num_samples_to_load do
    selected_sample_filename = selected_sample_filenames[i]
    if #current_instrument.samples < i then
      current_instrument:insert_sample_at(i)
    end
    sample = current_instrument.samples[i]
    sample_buffer = sample.sample_buffer
    samplefilename = selected_sample_filename:match("^.+[/\\](.+)$")
    sample.name = (samplefilename)
    if sample_buffer:load_from(selected_sample_filename) then
      renoise.app():show_status("Sample " .. selected_sample_filename .. " loaded successfully.")
    else
      renoise.app():show_status("Failed to load the sample.")
    end
  end
  
  if #selected_sample_filenames > max_samples then
    local not_loaded_count = #selected_sample_filenames - max_samples
    renoise.app():show_status("Maximum Drumkit Zones is 120 - was not able to load " .. not_loaded_count .. " samples.")
  end
end

-- Paketti preferences
preferences = renoise.Document.create("ScriptingToolPreferences") {
  pakettiOverwriteCurrent = false,
  pakettiREXBundlePath = "." .. separator .. "rx2",
  pakettiLoadDefaultInstrument = true,  -- Set to false to skip loading default instrument template
  
  -- Polyend Tracker preferences
  PolyendRoot = "",
  PolyendLocalPath = "",
  PolyendPTISavePath = "",
  PolyendWAVSavePath = "",
  PolyendUseSavePaths = false,
  PolyendLocalBackupPath = "",
  PolyendUseLocalBackup = false,
  pakettiPolyendPTISavePath = "",
  pakettiPolyendSavePaths = false,
  
  -- Sample loader preferences
  pakettiLoaderInterpolation = renoise.Sample.INTERPOLATE_LINEAR,
  pakettiLoaderOverSampling = false,
  pakettiLoaderAutofade = false,
  pakettiLoaderAutoseek = true,
  pakettiLoaderLoopMode = renoise.Sample.LOOP_MODE_OFF,
  pakettiLoaderOneshot = false,
  pakettiLoaderNNA = renoise.Sample.NEW_NOTE_ACTION_NOTE_OFF,
  pakettiLoaderLoopExit = false,
  pakettiLoaderDontCreateAutomationDevice = true,
}
renoise.tool().preferences = preferences

print ("Paketti File Format Import tool has loaded")

local bit = require("bit")

function loadnative(effect, name, preset_path)
  local checkline=nil
  local s=renoise.song()
  local w=renoise.app().window

  -- Define blacklists for different track types
  local master_blacklist={"Audio/Effects/Native/*Key Tracker", "Audio/Effects/Native/*Velocity Tracker", "Audio/Effects/Native/#Send", "Audio/Effects/Native/#Multiband Send", "Audio/Effects/Native/#Sidechain"}
  local send_blacklist={"Audio/Effects/Native/*Key Tracker", "Audio/Effects/Native/*Velocity Tracker"}
  local group_blacklist={"Audio/Effects/Native/*Key Tracker", "Audio/Effects/Native/*Velocity Tracker"}
  local samplefx_blacklist={"Audio/Effects/Native/#ReWire Input", "Audio/Effects/Native/*Instr. Macros", "Audio/Effects/Native/*Instr. MIDI Control", "Audio/Effects/Native/*Instr. Automation"}

  -- Helper function to extract device name from the effect string
  local function get_device_name(effect)
    return effect:match("([^/]+)$")
  end

  -- Helper function to check if a device is in the blacklist
  local function is_blacklisted(effect, blacklist)
    for _, blacklisted in ipairs(blacklist) do
      if effect == blacklisted then
        return true
      end
    end
    return false
  end

  if w.active_middle_frame == 6 then
    w.active_middle_frame = 7
  end

  if w.active_middle_frame == 7 then
    local chain = s.selected_sample_device_chain
    local chain_index = s.selected_sample_device_chain_index

    if chain == nil or chain_index == 0 then
      s.selected_instrument:insert_sample_device_chain_at(1)
      chain = s.selected_sample_device_chain
      chain_index = 1
    end

    if chain then
      local sample_devices = chain.devices
        -- Load at start (after input device if present)
        checkline = (table.count(sample_devices)) < 2 and 2 or (sample_devices[2] and sample_devices[2].name == "#Line Input" and 3 or 2)
      checkline = math.min(checkline, #sample_devices + 1)


      if is_blacklisted(effect, samplefx_blacklist) then
        renoise.app():show_status("The device " .. get_device_name(effect) .. " cannot be added to a Sample FX chain.")
        return
      end

      -- Adjust checkline for #Send and #Multiband Send devices
      local device_name = get_device_name(effect)
      if device_name == "#Send" or device_name == "#Multiband Send" then
        checkline = #sample_devices + 1
      end

      chain:insert_device_at(effect, checkline)
      sample_devices = chain.devices

      if sample_devices[checkline] then
        local device = sample_devices[checkline]
        if device.name == "Maximizer" then device.parameters[1].show_in_mixer = true end

        if device.name == "Mixer EQ" then 
          device.active_preset_data = read_file("Presets/PakettiMixerEQ.xml")
        end

        if device.name == "EQ 10" then 
          device.active_preset_data = read_file("Presets/PakettiEQ10.xml")
        end


        if device.name == "DC Offset" then device.parameters[2].value = 1 end
        if device.name == "#Multiband Send" then 
          device.parameters[1].show_in_mixer = false
          device.parameters[3].show_in_mixer = false
          device.parameters[5].show_in_mixer = false 
          device.active_preset_data = read_file("Presets/PakettiMultiSend.xml")
        end
        if device.name == "#Line Input" then device.parameters[2].show_in_mixer = true end
        if device.name == "#Send" then 
          device.parameters[2].show_in_mixer = false
          device.active_preset_data = read_file("Presets/PakettiSend.xml")
        end
        -- Add preset loading if path is provided
        if preset_path then
          local preset_data = read_file(preset_path)
          if preset_data then
            device.active_preset_data = preset_data
          else
            renoise.app():show_status("Failed to load preset from: " .. preset_path)
          end
        end
        renoise.song().selected_sample_device_index = checkline
        if name ~= nil then
          sample_devices[checkline].display_name = name 
        end
      end
    else
      renoise.app():show_status("No sample selected.")
    end

  else
    local sdevices = s.selected_track.devices
      checkline = (table.count(sdevices)) < 2 and 2 or (sdevices[2] and sdevices[2].name == "#Line Input" and 3 or 2)
    checkline = math.min(checkline, #sdevices + 1)
    
    w.lower_frame_is_visible = true
    w.active_lower_frame = 1

    local track_type = renoise.song().selected_track.type
    local device_name = get_device_name(effect)

    if track_type == 2 and is_blacklisted(effect, master_blacklist) then
      renoise.app():show_status("The device " .. device_name .. " cannot be added to a Master track.")
      return
    elseif track_type == 3 and is_blacklisted(effect, send_blacklist) then
      renoise.app():show_status("The device " .. device_name .. " cannot be added to a Send track.")
      return
    elseif track_type == 4 and is_blacklisted(effect, group_blacklist) then
      renoise.app():show_status("The device " .. device_name .. " cannot be added to a Group track.")
      return
    end

    -- Adjust checkline for #Send and #Multiband Send devices
    if device_name == "#Send" or device_name == "#Multiband Send" then
      checkline = #sdevices + 1
    end

    s.selected_track:insert_device_at(effect, checkline)
    s.selected_device_index = checkline
    sdevices = s.selected_track.devices

    if sdevices[checkline] then
      local device = sdevices[checkline]
      if device.name == "DC Offset" then device.parameters[2].value = 1 end
      if device.name == "Maximizer" then device.parameters[1].show_in_mixer = true end
      if device.name == "#Multiband Send" then 
        device.parameters[1].show_in_mixer = false
        device.parameters[3].show_in_mixer = false
        device.parameters[5].show_in_mixer = false 
      end
      if device.name == "#Line Input" then device.parameters[2].show_in_mixer = true end
      if device.name == "Mixer EQ" then 
        device.active_preset_data = read_file("Presets/PakettiMixerEQ.xml")
      end
      if device.name == "EQ 10" then 
        device.active_preset_data = read_file("Presets/PakettiEQ10.xml")
      end

      if device.name == "#Send" then 
        device.parameters[2].show_in_mixer = false
      end
      -- Add preset loading if path is provided
      if preset_path then
        local preset_data = read_file(preset_path)
        if preset_data then
          device.active_preset_data = preset_data
        else
          renoise.app():show_status("Failed to load preset from: " .. preset_path)
        end
      end
      if name ~= nil then
        sdevices[checkline].display_name = name 
      end
    end
  end
end

-- Basic sample normalization function (called by PakettiPolyendSuite as fallback)
function normalize_selected_sample()
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample to normalize")
    return
  end
  
  local sbuf = sample.sample_buffer
  local peak = 0
  
  -- Find peak value across all channels
  sbuf:prepare_sample_data_changes()
  for channel = 1, sbuf.number_of_channels do
    for frame = 1, sbuf.number_of_frames do
      local value = math.abs(sbuf:sample_data(channel, frame))
      if value > peak then
        peak = value
      end
    end
  end
  
  -- Normalize if peak is not zero or already at 1.0
  if peak > 0 and peak < 1.0 then
    local scale = 1.0 / peak
    for channel = 1, sbuf.number_of_channels do
      for frame = 1, sbuf.number_of_frames do
        local value = sbuf:sample_data(channel, frame)
        sbuf:set_sample_data(channel, frame, value * scale)
      end
    end
    renoise.app():show_status("Sample normalized")
  else
    renoise.app():show_status("Sample already at peak or silent")
  end
  
  sbuf:finalize_sample_data_changes()
end

function pakettiPreferencesDefaultInstrumentLoader()
  local defaultInstrument = "12st_Pitchbend.xrni"
  
  -- Function to check if a file exists
  local function file_exists(file)
    local f = io.open(file, "r")
    if f then f:close() end
    return f ~= nil
  end

  print("Loading instrument from path: " .. defaultInstrument)
  renoise.app():load_instrument(defaultInstrument)
end

-- Remove any existing hooks first
if renoise.tool():has_file_import_hook("instrument", {"p", "P1", "P3"}) then
  renoise.tool():remove_file_import_hook("instrument", {"p", "P1", "P3"})
end

if renoise.tool():has_file_import_hook("sample", {"s", "S1", "S3"}) then
  renoise.tool():remove_file_import_hook("sample", {"s", "S1", "S3"})
end

if renoise.tool():has_file_import_hook("sample", {"sf2"}) then
  renoise.tool():remove_file_import_hook("sample", {"sf2"})
end

if renoise.tool():has_file_import_hook("sample", {"rex"}) then
  renoise.tool():remove_file_import_hook("sample", {"rex"})
end

if renoise.tool():has_file_import_hook("sample", {"rx2"}) then
  renoise.tool():remove_file_import_hook("sample", {"rx2"})
end

if renoise.tool():has_file_import_hook("sample", {"pti"}) then
  renoise.tool():remove_file_import_hook("sample", {"pti"})
end

if renoise.tool():has_file_import_hook("instrument", {"iti"}) then
  renoise.tool():remove_file_import_hook("instrument", {"iti"})
end

if renoise.tool():has_file_import_hook("sample", {"exe","dll","bin","sys","dylib"}) then
  renoise.tool():remove_file_import_hook("sample", {"exe","dll","bin","sys","dylib"})
end

if renoise.API_VERSION >= 6.2 then
  if renoise.tool():has_file_import_hook("sample", {"png", "bmp", "jpg", "jpeg", "gif"}) then
    renoise.tool():remove_file_import_hook("sample", {"png", "bmp", "jpg", "jpeg", "gif"})
  end
end

-- Register all hooks directly
-- AKAI S1000/S3000 Program files
renoise.tool():add_file_import_hook({
  category = "instrument",
  extensions = { "p", "P1", "P3" },
  invoke = s1000_loadinstrument
})

-- AKAI S1000/S3000 Sample files
renoise.tool():add_file_import_hook({
  category = "sample",
  extensions = { "s", "S1", "S3" },
  invoke = s1000_loadsample
})

-- SF2 files
renoise.tool():add_file_import_hook({
  category = "sample",
  extensions = { "sf2" },
  invoke = sf2_loadsample
})

-- REX files
renoise.tool():add_file_import_hook({
  category = "sample",
  extensions = { "rex" },
  invoke = rex_loadsample
})

-- RX2 files
renoise.tool():add_file_import_hook({
  category = "sample",
  extensions = { "rx2" },
  invoke = rx2_loadsample
})

-- PTI files
renoise.tool():add_file_import_hook({
  category = "sample",
  extensions = { "pti" },
  invoke = pti_loadsample
})

print("Paketti File Format Import tool: All import hooks registered")

-- Preferences Dialog
function show_paketti_preferences_dialog()
  local vb = renoise.ViewBuilder()
  local dialog = nil
  
  local dialog_content = vb:column {
    
    vb:row {
      vb:checkbox {
        value = preferences.pakettiLoadDefaultInstrument.value,
        notifier = function(value)
          preferences.pakettiLoadDefaultInstrument.value = value
          preferences:save_as("preferences.xml")
          print("pakettiLoadDefaultInstrument set to:", value)
        end
      },
      vb:text {
        text = "Load Default Instrument (12st_Pitchbend.xrni)"
      }
    },
    
    vb:row {
      vb:checkbox {
        value = preferences.pakettiOverwriteCurrent.value,
        notifier = function(value)
          preferences.pakettiOverwriteCurrent.value = value
          preferences:save_as("preferences.xml")
          print("pakettiOverwriteCurrent set to:", value)
        end
      },
      vb:text {
        text = "Overwrite Current Instrument (instead of creating new)"
      }
    },
    
    vb:space { height = 10 },
    
    vb:button {
      text = "Close",
      width = 80,
      notifier = function()
        if dialog and dialog.visible then
          dialog:close()
        end
      end
    }
  }
  
  dialog = renoise.app():show_custom_dialog("Paketti Importer Preferences", dialog_content)
end

-- Add menu entry for preferences in File menu with other Paketti Formats
renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Paketti Formats Preferences...",
  invoke = show_paketti_preferences_dialog
}

-- File menu entries for all import formats
renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Import .ITI (Impulse Tracker Instrument)...",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.iti"}, "Select ITI to import")
    if f and f ~= "" then iti_loadsample(f) end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Import .REX (ReCycle V1)...",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.rex"}, "Select REX to import")
    if f and f ~= "" then rex_loadsample(f) end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Import .RX2 (ReCycle V2)...",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.rx2"}, "Select RX2 to import")
    if f and f ~= "" then rx2_loadsample(f) end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Import .SF2 (SoundFont 2)...",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.sf2"}, "Select SF2 to import")
    if f and f ~= "" then sf2_loadsample(f) end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Import .PTI (Polyend Tracker Instrument)...",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.pti"}, "Select PTI to import")
    if f and f ~= "" then pti_loadsample(f) end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Import .IFF (Amiga IFF)...",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.iff"}, "Select IFF to import")
    if f and f ~= "" then loadIFFSample(f) end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Import .8SVX (Amiga 8-bit)...",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.8svx"}, "Select 8SVX to import")
    if f and f ~= "" then loadIFFSample(f) end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Import .16SV (Amiga 16-bit)...",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.16sv"}, "Select 16SV to import")
    if f and f ~= "" then loadIFFSample(f) end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Import .P/.P1/.P3 (AKAI Program)...",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.p","*.P1","*.P3"}, "Select AKAI Program to import")
    if f and f ~= "" then s1000_loadinstrument(f) end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Import .S/.S1/.S3 (AKAI Sample)...",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.s","*.S1","*.S3"}, "Select AKAI Sample to import")
    if f and f ~= "" then s1000_loadsample(f) end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Import Raw Binary as Sample...",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.exe","*.dll","*.bin","*.sys","*.dylib"}, "Select Binary to import as 8-bit sample")
    if f and f ~= "" then pakettiLoadExeAsSample(f) end
  end
}

if renoise.API_VERSION >= 6.2 then
  renoise.tool():add_menu_entry {
    name = "Main Menu:File:Paketti Formats:Import Image as Waveform...",
    invoke = function()
      local f = renoise.app():prompt_for_filename_to_read({"*.png","*.bmp","*.jpg","*.jpeg","*.gif"}, "Select Image to convert to waveform")
      if f and f ~= "" then pakettiImageToSample(f) end
    end
  }
end

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Import Samples from .MOD...",
  invoke = function()
    load_samples_from_mod()
  end
}

-- ============================================
-- EXPORT MENU ENTRIES
-- ============================================

-- ITI Export
renoise.tool():add_menu_entry{name = "Main Menu:File:Paketti Formats:Export:Export Instrument to ITI...",invoke = function() pakettiITIExportDialog() end}

-- IFF/8SVX/16SV Export and Conversion
renoise.tool():add_menu_entry{name = "--Main Menu:File:Paketti Formats:Export:Load IFF Sample File...",invoke = loadIFFSampleFromDialog}
renoise.tool():add_menu_entry{name = "Main Menu:File:Paketti Formats:Export:Convert IFF to WAV...",invoke = convertIFFToWAV}
renoise.tool():add_menu_entry{name = "Main Menu:File:Paketti Formats:Export:Convert WAV to IFF...",invoke = convertWAVToIFF}
renoise.tool():add_menu_entry{name = "--Main Menu:File:Paketti Formats:Export:Save Selected Sample as 8SVX...",invoke = saveCurrentSampleAs8SVX}
renoise.tool():add_menu_entry{name = "Main Menu:File:Paketti Formats:Export:Save Selected Sample as 16SV...",invoke = saveCurrentSampleAs16SV}
renoise.tool():add_menu_entry{name = "--Main Menu:File:Paketti Formats:Export:Batch Convert WAV/AIFF to 8SVX...",invoke = batchConvertToIFF}
renoise.tool():add_menu_entry{name = "Main Menu:File:Paketti Formats:Export:Batch Convert WAV/AIFF to 16SV...",invoke = batchConvertTo16SV}
renoise.tool():add_menu_entry{name = "Main Menu:File:Paketti Formats:Export:Batch Convert IFF/8SVX/16SV to WAV...",invoke = batchConvertIFFToWAV}
renoise.tool():add_menu_entry{name = "Main Menu:File:Paketti Formats:Export:Batch Convert WAV to IFF...",invoke = batchConvertWAVToIFF}

-- Wavetable Export
renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti Formats:Export:Export Wavetable (.WT)...", invoke = paketti_export_wavetable}

-- Polyend PTI Export
renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti Formats:Export:Polyend (PTI) Save Current Sample as...", invoke = pti_savesample}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Polyend (PTI) Export Subfolders as Melodic Slices...", invoke = PakettiExportSubfoldersAsMelodicSlices}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Polyend (PTI) Export Subfolders as Drum Slices...", invoke = PakettiExportSubfoldersAsDrumSlices}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Polyend (PTI) Save Current as Drumkit (Mono)...", invoke=function() save_pti_as_drumkit_mono(false) end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Polyend (PTI) Save Current as Drumkit (Stereo)...", invoke=function() save_pti_as_drumkit_stereo(false) end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Polyend (PTI) Create 48 Slice Drumkit (Mono)...", invoke=function() pitchBendDrumkitLoader() save_pti_as_drumkit_mono(false) end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Polyend (PTI) Create 48 Slice Drumkit (Stereo)...", invoke=function() pitchBendDrumkitLoader() save_pti_as_drumkit_stereo(false) end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Polyend (PTI) Melodic Slice Export (One-Shot)...", invoke=PakettiMelodicSliceExport}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Polyend (PTI) Melodic Slice Create Chain...", invoke=PakettiMelodicSliceCreateChain}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Polyend (PTI) Melodic Slice Export Current...", invoke=PakettiMelodicSliceExportCurrent}

-- Digitakt Export
renoise.tool():add_menu_entry{name = "--Main Menu:File:Paketti Formats:Export:Digitakt Export Sample Chain...", invoke = PakettiDigitaktDialog}
renoise.tool():add_menu_entry{name = "Main Menu:File:Paketti Formats:Export:Digitakt Quick Export (Mono)...", invoke = PakettiDigitaktExportMono}
renoise.tool():add_menu_entry{name = "Main Menu:File:Paketti Formats:Export:Digitakt Quick Export (Stereo)...", invoke = PakettiDigitaktExportStereo}
renoise.tool():add_menu_entry{name = "Main Menu:File:Paketti Formats:Export:Digitakt Quick Export (Chain Mode)...", invoke = PakettiDigitaktExportChain}

-- Octatrack Export
renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti Formats:Export:Octatrack Export (.WAV+.ot)...", invoke=function() PakettiOTExport() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Octatrack Export (.ot only)...", invoke=function() PakettiOTExportOtOnly() end}
renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti Formats:Export:Octatrack Generate Drumkit (Smart Mono/Stereo)...", invoke=function() PakettiOTDrumkitSmart() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Octatrack Generate Drumkit (Force Mono)...", invoke=function() PakettiOTDrumkitMono() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Octatrack Generate Drumkit (Play to End)...", invoke=function() PakettiOTDrumkitPlayToEnd() end}
renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti Formats:Export:Octatrack Generate OctaCycle...", invoke=function() PakettiOctaCycle() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Octatrack Quick OctaCycle (C, Oct 1-7)...", invoke=function() PakettiOctaCycleQuick() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Formats:Export:Octatrack Export OctaCycle...", invoke=function() PakettiOctaCycleExport() end}

-- ============================================
-- CONVERSION MENU ENTRIES
-- ============================================

renoise.tool():add_menu_entry {
  name = "--Main Menu:File:Paketti Formats:Convert RX2 to PTI...",
  invoke = rx2_to_pti_convert
}

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Batch Convert SFZ to XRNI (Save Only)...",
  invoke = PakettiBatchSFZToXRNI
}

renoise.tool():add_menu_entry {
  name = "Main Menu:File:Paketti Formats:Batch Convert SFZ to XRNI & Load...",
  invoke = function() PakettiBatchSFZToXRNI(true) end
}