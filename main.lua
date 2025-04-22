require "importers/PakettiSF2Loader"
require "importers/PakettiREXLoader"
require "importers/PakettiRX2Loader"
require "importers/PakettiPTILoader"

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



local function get_clean_filename(filepath)
  local filename = filepath:match("[^/\\]+$")
  if filename then return filename:gsub("%.pti$", "") end
  return "PTI Sample"
end

local function read_uint16_le(data, offset)
  return string.byte(data, offset + 1) + string.byte(data, offset + 2) * 256
end

local function read_uint32_le(data, offset)
  return string.byte(data, offset + 1) +
         string.byte(data, offset + 2) * 256 +
         string.byte(data, offset + 3) * 65536 +
         string.byte(data, offset + 4) * 16777216
end

local function pti_loadsample(filepath)
  local file = io.open(filepath, "rb")
  if not file then
    renoise.app():show_error("Cannot open file: " .. filepath)
    return
  end

  print("------------")
  print(string.format("-- PTI: Import filename: %s", filepath))

  local header = file:read(392)
  local sample_length = read_uint32_le(header, 60)
  local pcm_data = file:read("*a")
  file:close()

  -- Initialize with Paketti default instrument
  renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
  renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1

  pakettiPreferencesDefaultInstrumentLoader()
  local smp = renoise.song().selected_instrument.samples[1]

  -- Set names for instrument, sample, and related components immediately after creation
  local clean_name = get_clean_filename(filepath)
  renoise.song().selected_instrument.name = clean_name
  smp.name = clean_name
  renoise.song().instruments[renoise.song().selected_instrument_index].sample_modulation_sets[1].name = clean_name
  renoise.song().instruments[renoise.song().selected_instrument_index].sample_device_chains[1].name = clean_name

  -- Create and fill sample buffer in the first slot
  smp.sample_buffer:create_sample_data(44100, 16, 1, sample_length)
  local buffer = smp.sample_buffer
  
  -- Read number of valid slices from offset 376
  local slice_count = string.byte(header, 377) -- Lua strings are 1-indexed
  
  -- Print format information with slice count
  print(string.format("-- Format: %s, %dHz, %d-bit, %d frames, sliceCount = %d", 
    "Mono", 44100, 16, sample_length, slice_count))

  buffer:prepare_sample_data_changes()

  for i = 1, sample_length do
    local byte_offset = (i - 1) * 2 + 1
    local lo = pcm_data:byte(byte_offset) or 0
    local hi = pcm_data:byte(byte_offset + 1) or 0
    local sample = bit.bor(bit.lshift(hi, 8), lo)
    if sample >= 32768 then sample = sample - 65536 end
    buffer:set_sample_data(1, i, sample / 32768)
  end

  buffer:finalize_sample_data_changes()

  -- Read loop data
  local loop_mode_byte = string.byte(header, 77) -- offset 76 in 1-based Lua
  local loop_start_raw = read_uint16_le(header, 80)
  local loop_end_raw = read_uint16_le(header, 82)

  local loop_mode_names = {
    [0] = "OFF",
    [1] = "Forward",
    [2] = "Reverse",
    [3] = "PingPong"
  }

  -- Convert to sample frames (PTI spec defines range as 1-65534)
  -- We need to map from 1-65534 to 1-sample_length
  local function map_loop_point(value, sample_len)
    -- Ensure value is in valid range
    value = math.max(1, math.min(value, 65534))
    -- Map from 1-65534 to 1-sample_length
    return math.max(1, math.min(math.floor(((value - 1) / 65533) * (sample_len - 1)) + 1, sample_len))
  end

  local loop_start_frame = map_loop_point(loop_start_raw, sample_length)
  local loop_end_frame = map_loop_point(loop_end_raw, sample_length)

  -- Ensure end is after start and within sample bounds
  loop_end_frame = math.max(loop_start_frame + 1, math.min(loop_end_frame, sample_length))

  -- Calculate loop length
  local loop_length = loop_end_frame - loop_start_frame

  -- Set loop mode
  local loop_modes = {
    [0] = renoise.Sample.LOOP_MODE_OFF,
    [1] = renoise.Sample.LOOP_MODE_FORWARD,
    [2] = renoise.Sample.LOOP_MODE_REVERSE,
    [3] = renoise.Sample.LOOP_MODE_PING_PONG
  }

  smp.loop_mode = loop_modes[loop_mode_byte] or renoise.Sample.LOOP_MODE_OFF
  smp.loop_start = loop_start_frame
  smp.loop_end = loop_end_frame

  -- Print loop information (ensure we show OFF for mode 0)
  print(string.format("-- Loopmode: %s, Start: %d, End: %d, Looplength: %d", 
    loop_mode_names[loop_mode_byte] or "OFF",
    loop_start_frame,
    loop_end_frame,
    loop_length))
 
  -- Wavetable detection
  local is_wavetable = string.byte(header, 21) -- offset 20 in 1-based Lua
  local wavetable_window = read_uint16_le(header, 64)
  local wavetable_total_positions = read_uint16_le(header, 68)
  local wavetable_position = read_uint16_le(header, 88)

  if is_wavetable == 1 then
    print(string.format("-- Wavetable Mode: TRUE, Window: %d, Total Positions: %d, Position: %d (%.2f%%)", 
      wavetable_window,
      wavetable_total_positions,
      wavetable_position,
      (wavetable_total_positions > 0) and (wavetable_position / wavetable_total_positions * 100) or 0))

    -- Calculate wavetable loop points
    local loop_start = wavetable_position * wavetable_window
    local loop_end = loop_start + wavetable_window

    -- Clamp to sample bounds
    loop_start = math.max(1, math.min(loop_start, sample_length - wavetable_window))
    loop_end = loop_start + wavetable_window

    print(string.format("-- Original Wavetable Loop: Start = %d, End = %d (Position %03d of %d)", 
      loop_start, loop_end, wavetable_position, wavetable_total_positions))

    -- Store the original PCM data and buffer data
    local original_pcm_data = pcm_data
    local original_sample_length = sample_length

    -- First slot: Create the full wavetable
    smp.sample_buffer:create_sample_data(44100, 16, 1, original_sample_length)
    local wavetable_buffer = smp.sample_buffer
    wavetable_buffer:prepare_sample_data_changes()

    -- Copy the complete data to the wavetable slot
    for i = 1, original_sample_length do
      local byte_offset = (i - 1) * 2 + 1
      local lo = string.byte(original_pcm_data, byte_offset) or 0
      local hi = string.byte(original_pcm_data, byte_offset + 1) or 0
      local sample = bit.bor(bit.lshift(hi, 8), lo)
      if sample >= 32768 then sample = sample - 65536 end
      wavetable_buffer:set_sample_data(1, i, sample / 32768)
    end

    wavetable_buffer:finalize_sample_data_changes()
    
    -- Set properties for the wavetable slot
    smp.name = clean_name .. " (Wavetable)"
    smp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    smp.loop_start = loop_start
    smp.loop_end = loop_end
    smp.volume = 1.0
    smp.sample_mapping.note_range = {0, 119}
    -- Set velocity to 0 for the full wavetable
    smp.sample_mapping.velocity_range = {0, 0}

    -- Clear any existing samples except the first one (wavetable)
    local current_instrument = renoise.song().selected_instrument
    while #current_instrument.samples > 1 do
      current_instrument:delete_sample_at(#current_instrument.samples)
    end

    -- Create a sample slot for each position starting from slot 2
    for pos = 0, wavetable_total_positions - 1 do
      local pos_start = pos * wavetable_window
      
      -- Create new sample slot
      local new_sample = current_instrument:insert_sample_at(pos + 2) -- Start from slot 2
      -- Create and fill the buffer for this position
      new_sample.sample_buffer:create_sample_data(44100, 16, 1, wavetable_window)
      local new_buffer = new_sample.sample_buffer
      new_buffer:prepare_sample_data_changes()
      
      -- Copy the window data for this position
      for i = 1, wavetable_window do
        -- Calculate byte offset in the original PCM data
        local byte_offset = ((pos_start + i - 1) * 2) + 1
        
        -- Read the bytes and convert to sample value
        local lo = string.byte(original_pcm_data, byte_offset) or 0
        local hi = string.byte(original_pcm_data, byte_offset + 1) or 0
        local sample = bit.bor(bit.lshift(hi, 8), lo)
        
        -- Convert from signed 16-bit to float
        if sample >= 32768 then 
          sample = sample - 65536 
        end
        
        -- Set the sample data (-1.0 to 1.0 range)
        new_buffer:set_sample_data(1, i, sample / 32768)
      end
      
      new_buffer:finalize_sample_data_changes()
      
      -- Print first sample value for debugging
      local first_val = new_buffer:sample_data(1, 1)
      print(string.format("-- Position %03d first sample value: %.6f", pos, first_val))

      -- Set sample properties
      new_sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
      new_sample.loop_start = 1
      new_sample.loop_end = wavetable_window
      
      -- Set name to indicate position with 3-digit format
      new_sample.name = string.format("%s (Pos %03d)", clean_name, pos)

      -- Set volume to 1 for all samples
      new_sample.volume = 1.0

      -- All samples get full key range C-0 to B-9
      new_sample.sample_mapping.note_range = {0, 119} -- C-0 to B-9

      -- Control visibility through velocity mapping
      if pos == wavetable_position then
        -- Selected position gets full velocity range
        new_sample.sample_mapping.velocity_range = {0, 127}
        print(string.format("-- Setting full velocity range for position %03d", pos))
      else
        -- Other positions get zero velocity
        new_sample.sample_mapping.velocity_range = {0, 0}
      end
    end

    print(string.format("-- Created wavetable with %d positions, window size %d", 
      wavetable_total_positions, wavetable_window))
  else
    print("-- Wavetable Mode: FALSE")
  end

  -- Process only actual slices
  local slice_frames = {}
  for i = 0, slice_count - 1 do
    local offset = 280 + i * 2
    local raw_value = read_uint16_le(header, offset)
    if raw_value >= 0 and raw_value <= 65535 then
      local frame = math.floor((raw_value / 65535) * sample_length)
      table.insert(slice_frames, frame)
    end
  end

  table.sort(slice_frames)

  -- Detect audio content length
  local abs_threshold = 0.001
  local function find_trim_range()
    local nonzero_found = false
    local first, last = 1, sample_length
    for i = 1, sample_length do
      local val = math.abs(buffer:sample_data(1, i))
      if not nonzero_found and val > abs_threshold then
        first = i
        nonzero_found = true
      end
      if val > abs_threshold then
        last = i
      end
    end
    return first, last
  end

  local _, last_content_frame = find_trim_range()
  local keep_ratio = last_content_frame / sample_length

  if math.abs(keep_ratio - 0.5) < 0.01 then
    print(string.format("-- Detected 50%% silence: trimming to %d frames", last_content_frame))

    -- Rescale slice markers
    local rescaled_slices = {}
    for _, old_frame in ipairs(slice_frames) do
      local new_frame = math.floor((old_frame / sample_length) * last_content_frame)
      table.insert(rescaled_slices, new_frame)
    end

    -- Trim sample buffer by recreating it
    local trimmed_length = last_content_frame
    local old_data = {}

    for i = 1, trimmed_length do
      old_data[i] = buffer:sample_data(1, i)
    end

    -- Recreate the buffer with only the trimmed content
    smp.sample_buffer:create_sample_data(44100, 16, 1, trimmed_length)
    buffer = smp.sample_buffer
    buffer:prepare_sample_data_changes()

    for i = 1, trimmed_length do
      buffer:set_sample_data(1, i, old_data[i])
    end

    buffer:finalize_sample_data_changes()
    sample_length = trimmed_length -- update for future use

    -- Apply rescaled slices
    for i, frame in ipairs(rescaled_slices) do
      print(string.format("-- Slice %02d at frame: %d", i, frame))
      smp:insert_slice_marker(frame + 1)
    end

    -- Enable oversampling for all slices
    for i = 1, #smp.slice_markers do
      local slice_sample = renoise.song().selected_instrument.samples[i+1]
      if slice_sample then
        slice_sample.oversample_enabled = true
      end
    end

  else
    -- Apply original slices
    if #slice_frames > 0 then
      for i, frame in ipairs(slice_frames) do
        print(string.format("-- Slice %02d at frame: %d", i, frame))
        smp:insert_slice_marker(frame + 1)
      end    
      -- Enable oversampling for all slices
      for i = 1, #smp.slice_markers do
        local slice_sample = renoise.song().selected_instrument.samples[i+1]
        if slice_sample then
          slice_sample.oversample_enabled = true
        end
      end
    end
  end

  -- Apply base settings
  smp.autofade = true
  smp.autoseek = false
  smp.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  smp.oversample_enabled = true
  smp.oneshot = false
  smp.loop_release = false

  -- Show status message
  local total_slices = #renoise.song().selected_instrument.samples[1].slice_markers
  if total_slices > 0 then
    renoise.app():show_status(string.format("PTI imported with %d slice markers", total_slices))
  else
    renoise.app():show_status("PTI imported successfully")
  end

  -- Add Instr Macro device
  if renoise.song().selected_track.type == 2 then 
    renoise.app():show_status("*Instr. Macro Device will not be added to the Master track.") 
  else
    loadnative("Audio/Effects/Native/*Instr. Macros") 
    local macro_device = renoise.song().selected_track:device(2)
    macro_device.display_name = string.format("%02X", renoise.song().selected_instrument_index - 1) .. " " .. clean_name
    renoise.song().selected_track.devices[2].is_maximized = false
  end
end

local pti_integration = {
  category = "sample",
  extensions = { "pti" },
  invoke = pti_loadsample
}

if not renoise.tool():has_file_import_hook("sample", { "pti" }) then
  renoise.tool():add_file_import_hook(pti_integration)
end



local _DEBUG = true
local function dprint(...) if _DEBUG then print("REX Debug:", ...) end end

local function get_clean_filename(filepath)
  local filename = filepath:match("[^/\\]+$")
  if filename then return filename:gsub("%.rex$", "") end
  return "REX Sample"
end

local function read_dword(data, pos)
  local b1, b2, b3, b4 = data:byte(pos, pos + 3)
  return (b1 * 16777216) + (b2 * 65536) + (b3 * 256) + b4
end

function rex_loadsample(filename)
  dprint("Starting REX import for file:", filename)
  
  local song = renoise.song()
  
  -- Define constants
  local header_len = 256  -- Length of each header in frames
  
  -- Initialize with Paketti default instrument
  renoise.song():insert_instrument_at(renoise.song().selected_instrument_index+1)
  renoise.song().selected_instrument_index = renoise.song().selected_instrument_index+1

  pakettiPreferencesDefaultInstrumentLoader()
  local smp = song.selected_sample
  dprint("Using Paketti default instrument configuration")
  
  -- Create temporary AIFF file
  local aiff_copy = os.tmpname() .. ".aiff"
  dprint("Created temporary file:", aiff_copy)
  
  local f_in = io.open(filename, "rb")
  if not f_in then
    dprint("ERROR: Cannot open source file")
    renoise.app():show_status("REX Import Error: Cannot open source file.")
    return false
  end
  dprint("Opened source file successfully")

  local f_out = io.open(aiff_copy, "wb")
  if not f_out then
    dprint("ERROR: Cannot create temp file")
    f_in:close()
    renoise.app():show_status("REX Import Error: Cannot create temp file.")
    return false
  end
  dprint("Created temporary file successfully")

  local data = f_in:read("*a")
  dprint("Read source file, size:", #data, "bytes")
  f_out:write(data)
  f_in:close()
  f_out:close()
  dprint("Wrote temporary file")

  -- Try to load the sample and verify it has data
  dprint("Attempting to load sample from temporary file")
  local load_success = pcall(function() 
    smp.sample_buffer:load_from(aiff_copy)
  end)
  
  if not load_success then
    dprint("ERROR: Failed to load sample")
    renoise.app():show_status("REX Import Error: Failed to load sample.")
    os.remove(aiff_copy)
    return false
  end
  
  if not smp.sample_buffer.has_sample_data then
    dprint("ERROR: No audio data loaded")
    renoise.app():show_status("REX Import Error: No audio data loaded.")
    os.remove(aiff_copy)
    return false
  end
  dprint("Sample loaded successfully")

  -- Verify sample buffer properties are accessible
  local buf = smp.sample_buffer
  if not buf or not buf.has_sample_data then
    dprint("ERROR: Invalid sample buffer")
    renoise.app():show_status("REX Import Error: Invalid sample buffer.")
    os.remove(aiff_copy)
    return false
  end
  dprint("Sample buffer is valid")

  -- Safe access of sample buffer after validation
  local ch = buf.number_of_channels
  local frames = buf.number_of_frames
  dprint("Sample properties - Channels:", ch, "Frames:", frames)
  
  if ch <= 0 or frames <= 0 then
    dprint("ERROR: Invalid sample dimensions")
    renoise.app():show_status("REX Import Error: Invalid sample data dimensions.")
    os.remove(aiff_copy)
    return false
  end

  local rex_start = data:find("REX ", 1, true)
  if not rex_start then
    dprint("ERROR: REX chunk not found in file")
    renoise.app():show_status("REX chunk not found")
    os.remove(aiff_copy)
    return true
  end
  dprint("Found REX chunk at offset:", rex_start)

  local header_offset = rex_start + 1032
  local slice_offsets = {}
  local seen = {}
  for i = 1, 256 do
    if header_offset + 3 > #data then break end
    local offs = read_dword(data, header_offset)
    if offs == 0 or seen[offs] then break end
    table.insert(slice_offsets, offs)
    seen[offs] = true
    header_offset = header_offset + 12
  end
  dprint("Found", #slice_offsets, "slice offsets")

  if #slice_offsets == 0 then
    dprint("ERROR: No slice offsets found")
    renoise.app():show_status("REX contained no slice offsets.")
    os.remove(aiff_copy)
    return false
  end

  -- Calculate total frames including headers
  local total_headers = #slice_offsets
  local total_header_frames = total_headers * header_len
  local actual_frames = frames + total_header_frames
  dprint(string.format("Actual audio length calculation: visible frames %d + (%d headers * %d frames) = %d total frames", 
    frames, total_headers, header_len, actual_frames))

  -- Copy sample data to memory, accounting for full length including headers
  dprint("Copying sample data to memory")
  local original = {}
  for c = 1, ch do
    original[c] = {}
    for i = 1, actual_frames do
      if i <= frames then  -- Only copy actual data we have
        original[c][i] = buf:sample_data(c, i)
      end
    end
  end
  dprint("Sample data copied successfully")

  -- Remove headers in reverse
  dprint("Processing slice headers")
  -- Sort in ascending order to process sequentially
  table.sort(slice_offsets)
  
  dprint("Original slice positions:", table.concat(slice_offsets, ", "))
  
  -- Now copy the data, removing headers
  local new_pos = 1  -- Where we're writing to
  local read_pos = 1  -- Where we're reading from
  local header_count = 0
  local total_removed = 0
  
  -- Create a new buffer for the processed data
  local processed = {}
  for c = 1, ch do
    processed[c] = {}
  end
  
  -- Process each slice
  for i = 1, #slice_offsets do
    local slice_pos = slice_offsets[i]
    local next_slice = (i < #slice_offsets) and slice_offsets[i+1] or frames
    
    -- The header ends exactly at slice position (inclusive)
    local header_start = slice_pos - header_len + 1
    
    -- If this is the first slice, copy everything up to the first header
    if i == 1 then
      for pos = 1, header_start-1 do
        for c = 1, ch do
          processed[c][new_pos] = original[c][pos]
        end
        new_pos = new_pos + 1
      end
    end
    
    -- Skip the header and report
    dprint(string.format("Removing header at position %d-%d (%d frames header detected ending at slice at %d - slice position becomes %d)", 
      header_start, slice_pos, header_len, slice_pos, new_pos))
    
    -- Copy the slice data
    -- For the last slice, copy all remaining data
    -- For other slices, copy until just before the next header
    local copy_end
    if i == #slice_offsets then
      copy_end = frames  -- Copy all the way to the end for last slice
      dprint(string.format("Last slice: copying all remaining data from %d to %d", slice_pos + 1, copy_end))
    else
      copy_end = slice_offsets[i+1] - header_len
      dprint(string.format("Slice %d: copying data from %d to %d", i, slice_pos + 1, copy_end))
    end
    
    for pos = slice_pos + 1, copy_end do
      if pos <= frames then  -- Make sure we don't read past the end
        for c = 1, ch do
          processed[c][new_pos] = original[c][pos]
        end
        new_pos = new_pos + 1
      end
    end
    
    total_removed = total_removed + header_len
  end
  
  -- Calculate new frame count
  local new_frames = new_pos - 1  -- Since new_pos is the next write position
  dprint(string.format("Processed %d headers, removed total of %d frames (%d frames per header), new length is %d frames", 
    #slice_offsets, total_removed, header_len, new_frames))

  -- Create new sample without headers
  dprint("Creating new sample without headers")
  local new_sample_index = #song.selected_instrument.samples + 1
  song.selected_instrument:insert_sample_at(new_sample_index)
  local new_smp = song.selected_instrument:sample(new_sample_index)
  
  -- Create the sample buffer with correct size
  local create_success = pcall(function()
    new_smp.sample_buffer:create_sample_data(buf.sample_rate, 16, ch, new_frames)
  end)

  if not create_success then
    dprint("ERROR: Failed to create new sample buffer")
    renoise.app():show_status("REX Import Error: Failed to create new sample buffer.")
    os.remove(aiff_copy)
    return false
  end

  -- Copy processed data to new buffer
  local new_buf = new_smp.sample_buffer
  if not new_buf or not new_buf.has_sample_data then
    dprint("ERROR: New sample buffer is invalid")
    renoise.app():show_status("REX Import Error: New sample buffer is invalid.")
    os.remove(aiff_copy)
    return false
  end

  -- Write the processed data
  dprint("Writing processed data")
  local write_success = pcall(function()
    for i = 1, new_frames do
      for c = 1, ch do
        new_buf:set_sample_data(c, i, processed[c][i] or 0)
      end
    end
  end)

  if not write_success then
    dprint("ERROR: Failed to write processed data")
    renoise.app():show_status("REX Import Error: Failed to write processed data.")
    os.remove(aiff_copy)
    return false
  end

  -- Remove the original sample
  song.selected_instrument:delete_sample_at(1)
  -- Select the new sample
  song.selected_sample_index = 1
  
  -- Insert slice markers at the actual positions
  dprint("Adding slice markers")
  local sample = renoise.song().selected_instrument.samples[1]
  sample.autofade = true
  sample.autoseek = false
  sample.loop_mode = 1
  sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  sample.oversample_enabled = true
  sample.oneshot = false
--  sample.new_note_action = preferences.pakettiLoaderNNA.value
  sample.loop_release = false

  -- First marker at the very beginning
  new_smp:insert_slice_marker(1)
  dprint("Added initial slice marker at position 1")
  
  -- Track how many frames we've removed so far
  local frames_removed = 0
  
  -- Add ALL slice markers, including the first actual slice
  for i = 1, #slice_offsets do
    local original_pos = slice_offsets[i]
    
    -- Calculate frames removed before this slice
    -- Each header before this slice has removed header_len frames
    frames_removed = i * header_len
    
    -- Calculate the new position after header removal
    local new_pos = original_pos - frames_removed
    
    dprint(string.format("Slice %d: Original pos %d, removed %d frames before this, new pos %d", 
      i, original_pos, frames_removed, new_pos))
    
    if new_pos > 1 and new_pos <= new_frames then
      new_smp:insert_slice_marker(new_pos)
      dprint(string.format("Added slice marker %d at position %d", i, new_pos))
    else
      dprint(string.format("Skipping slice marker %d - position %d out of range (1-%d)", 
        i, new_pos, new_frames))
    end
  end
  dprint(string.format("Added %d slice markers in total (including start)", #slice_offsets + 1))

  -- Enable oversampling for all slices
  for i = 1, #new_smp.slice_markers do
    renoise.song().selected_instrument.samples[i+1].oversample_enabled = true
    dprint(string.format("Enabled oversampling for slice %d", i))
  end

  -- Set names
  new_smp.name = get_clean_filename(filename)
  song.selected_instrument.name = get_clean_filename(filename)
  renoise.song().instruments[renoise.song().selected_instrument_index].sample_modulation_sets[1].name=get_clean_filename(filename)
  renoise.song().instruments[renoise.song().selected_instrument_index].sample_device_chains[1].name=get_clean_filename(filename)

  os.remove(aiff_copy)
  dprint("Import completed successfully")

  
  if renoise.song().selected_track.type == 2 then renoise.app():show_status("*Instr. Macro Device will not be added to the Master track.") return else
    loadnative("Audio/Effects/Native/*Instr. Macros") 
    local macro_device = renoise.song().selected_track:device(2)
    macro_device.display_name = string.format("%02X", renoise.song().selected_instrument_index - 1) .. " " .. get_clean_filename(filename)
    renoise.song().selected_track.devices[2].is_maximized = false
end
  renoise.app():show_status(string.format("REX cleaned and imported with %d slice markers", #slice_offsets))
  return true
end

local rex_integration = {
  category = "sample",
  extensions = { "rex" },
  invoke = rex_loadsample
}

if not renoise.tool():has_file_import_hook("sample", { "rex" }) then
  renoise.tool():add_file_import_hook(rex_integration)
end

-- DEBUG TOOL: Dump REX structure to .txt
local function bytes_to_hexstr(data)
  local out = {}
  for i = 1, #data do
    out[#out + 1] = string.format("%02X", data:byte(i))
    if i % 16 == 0 then out[#out + 1] = "\n" else out[#out + 1] = " " end
  end
  return table.concat(out)
end


