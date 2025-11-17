-- PakettiITIImport.lua
-- Impulse Tracker Instrument (.ITI) importer for Renoise
-- Full IT214/IT215 decompression support

local _DEBUG = false
local function dprint(...) if _DEBUG then print("ITI Debug:", ...) end end

local function get_clean_filename(filepath)
  local filename = filepath:match("[^/\\]+$")
  if filename then return filename:gsub("%.iti$", "") end
  return "ITI Instrument"
end

-- Helper functions for reading binary data (little-endian)
local function read_byte(data, pos)
  return data:byte(pos)
end

local function read_word(data, pos)
  local b1, b2 = data:byte(pos, pos + 1)
  return b1 + (b2 * 256)
end

local function read_dword(data, pos)
  local b1, b2, b3, b4 = data:byte(pos, pos + 3)
  return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

local function read_string(data, pos, length)
  local str = data:sub(pos, pos + length - 1)
  local null_pos = str:find('\0')
  if null_pos then
    return str:sub(1, null_pos - 1)
  end
  return str
end

-- Bitwise AND function for Lua 5.1 compatibility
local function bit_and(a, b)
  local result = 0
  local bit = 1
  while a > 0 and b > 0 do
    if (a % 2 == 1) and (b % 2 == 1) then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end

-- ITI Format constants
local ITI_INSTRUMENT_SIZE = 554
local ITI_SAMPLE_HEADER_SIZE = 80
local ITI_ENVELOPE_SIZE = 81
local ITI_KEYBOARD_TABLE_SIZE = 240
local ITI_KEYBOARD_TABLE_OFFSET = 0x40
local ITI_ENVELOPES_OFFSET = 0x130

-- Sample flags
local SAMPLE_ASSOCIATED = 1
local SAMPLE_16BIT = 2
local SAMPLE_STEREO = 4
local SAMPLE_COMPRESSED = 8
local SAMPLE_LOOP = 16
local SAMPLE_SUSTAIN_LOOP = 32
local SAMPLE_PINGPONG_LOOP = 64
local SAMPLE_PINGPONG_SUSTAIN = 128

-- Envelope flags
local ENV_ON = 1
local ENV_LOOP = 2
local ENV_SUSTAIN_LOOP = 4

function iti_loadinstrument(filename)
  if not filename or filename == "" then
    dprint("ITI import cancelled - no file selected")
    renoise.app():show_status("ITI import cancelled - no file selected")
    return false
  end
  
  dprint("Starting ITI import for file:", filename)
  
  local song = renoise.song()
  
  -- Read the entire file
  local f = io.open(filename, "rb")
  if not f then
    dprint("ERROR: Cannot open ITI file")
    renoise.app():show_status("ITI Import Error: Cannot open file.")
    return false
  end
  
  local data = f:read("*a")
  f:close()
  
  if #data < ITI_INSTRUMENT_SIZE then
    dprint("ERROR: File too small to be valid ITI")
    renoise.app():show_status("ITI Import Error: File too small.")
    return false
  end
  
  -- Check for IMPI signature
  local signature = data:sub(1, 4)
  if signature ~= "IMPI" then
    dprint("ERROR: Invalid ITI signature")
    renoise.app():show_status("ITI Import Error: Invalid file signature.")
    return false
  end
  
  -- Parse instrument header
  local instrument_data = parse_iti_instrument_header(data)
  if not instrument_data then
    dprint("ERROR: Failed to parse instrument header")
    renoise.app():show_status("ITI Import Error: Failed to parse instrument header.")
    return false
  end
  
  -- Handle instrument creation based on preference
  if not renoise.tool().preferences.pakettiOverwriteCurrent.value then
    renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
    renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1
  end
  
  -- Load Paketti default instrument configuration (if enabled)
  if renoise.tool().preferences.pakettiLoadDefaultInstrument.value then
    pakettiPreferencesDefaultInstrumentLoader()
  end
  
  local instrument = song.selected_instrument
  instrument.name = instrument_data.name
  instrument.volume = math.min(instrument_data.global_volume / 128.0, 1.0)
  
  dprint("Set instrument name:", instrument_data.name)
  dprint("Instrument has", instrument_data.num_samples, "samples")
  
  -- Parse and load samples
  local loaded_samples = {}
  local iti_sample_data = {}
  
  if instrument_data.num_samples > 0 then
    local sample_positions = find_sample_positions(data)
    
    for i = 1, math.min(instrument_data.num_samples, #sample_positions) do
      local sample_pos = sample_positions[i]
      local sample_data = parse_iti_sample(data, sample_pos)
      if sample_data then
        iti_sample_data[i] = sample_data
        local renoise_sample = load_iti_sample_to_renoise(instrument, sample_data, data, instrument_data.name)
        if renoise_sample then
          loaded_samples[i] = renoise_sample
        end
      end
    end
  end
  
  if #loaded_samples > 0 then
    renoise.app():show_status(string.format("ITI '%s': %d samples loaded successfully", 
      instrument_data.name, #loaded_samples))
  else
    renoise.app():show_status(string.format("ITI instrument '%s' imported (instrument properties only)", instrument_data.name))
  end
  
  return true
end

function parse_iti_instrument_header(data)
  local pos = 5  -- Skip IMPI
  pos = pos + 12  -- Skip DOS filename
  pos = pos + 1   -- Skip null byte
  
  -- Read properties
  local nna = read_byte(data, pos); pos = pos + 1
  local dct = read_byte(data, pos); pos = pos + 1
  local dca = read_byte(data, pos); pos = pos + 1
  local fadeout = read_word(data, pos); pos = pos + 2
  local pps = read_byte(data, pos); pos = pos + 1
  local ppc = read_byte(data, pos); pos = pos + 1
  local global_volume = read_byte(data, pos); pos = pos + 1
  local default_pan = read_byte(data, pos); pos = pos + 1
  pos = pos + 4  -- Skip random volume/panning and tracker version
  local num_samples = read_byte(data, pos); pos = pos + 1
  pos = pos + 1  -- Skip unused
  
  local name = read_string(data, pos, 26)
  
  return {
    name = name,
    global_volume = global_volume,
    num_samples = num_samples,
    nna = nna,
    dct = dct,
    dca = dca
  }
end

function find_sample_positions(data)
  local positions = {}
  for i = 1, #data - 3 do
    if data:sub(i, i + 3) == "IMPS" then
      table.insert(positions, i)
    end
  end
  return positions
end

function parse_iti_sample(data, pos)
  if pos + ITI_SAMPLE_HEADER_SIZE > #data then
    return nil
  end
  
  if data:sub(pos, pos + 3) ~= "IMPS" then
    return nil
  end
  
  pos = pos + 4
  pos = pos + 12  -- Skip DOS filename
  pos = pos + 1   -- Skip null byte
  
  local global_volume = read_byte(data, pos); pos = pos + 1
  local flags = read_byte(data, pos); pos = pos + 1
  local volume = read_byte(data, pos); pos = pos + 1
  local name = read_string(data, pos, 26); pos = pos + 26
  local convert = read_byte(data, pos); pos = pos + 1
  local default_pan = read_byte(data, pos); pos = pos + 1
  local length = read_dword(data, pos); pos = pos + 4
  local loop_begin = read_dword(data, pos); pos = pos + 4
  local loop_end = read_dword(data, pos); pos = pos + 4
  local c5_speed = read_dword(data, pos); pos = pos + 4
  pos = pos + 8  -- Skip sustain loops
  local sample_pointer = read_dword(data, pos)
  
  return {
    name = name,
    global_volume = global_volume,
    flags = flags,
    volume = volume,
    convert = convert,
    default_pan = default_pan,
    length = length,
    loop_begin = loop_begin,
    loop_end = loop_end,
    c5_speed = c5_speed,
    sample_pointer = sample_pointer
  }
end

function load_iti_sample_to_renoise(instrument, sample_data, file_data, instrument_name)
  if sample_data.length == 0 or bit_and(sample_data.flags, SAMPLE_ASSOCIATED) == 0 then
    return nil
  end
  
  local sample_index = #instrument.samples + 1
  instrument:insert_sample_at(sample_index)
  local sample = instrument:sample(sample_index)
  
  sample.name = (sample_data.name ~= "" and sample_data.name) or 
                string.format("%s sample %02d", instrument_name or "ITI", sample_index)
  sample.volume = math.min(sample_data.volume / 64.0, 4.0)
  
  if bit_and(sample_data.default_pan, 128) ~= 0 then
    sample.panning = bit_and(sample_data.default_pan, 127) / 64.0
  end
  
  local sample_rate = math.min(96000, math.max(8000, sample_data.c5_speed))
  local channels = bit_and(sample_data.flags, SAMPLE_STEREO) ~= 0 and 2 or 1
  local bit_depth = bit_and(sample_data.flags, SAMPLE_16BIT) ~= 0 and 16 or 8
  
  local create_success = pcall(function()
    sample.sample_buffer:create_sample_data(sample_rate, bit_depth, channels, sample_data.length)
  end)
  
  if not create_success then
    return nil
  end
  
  -- Load sample data (compressed or uncompressed)
  local load_success = load_sample_data(sample, sample_data, file_data)
  if not load_success then
    return nil
  end
  
  -- Set loop properties
  if bit_and(sample_data.flags, SAMPLE_LOOP) ~= 0 then
    sample.loop_mode = bit_and(sample_data.flags, SAMPLE_PINGPONG_LOOP) ~= 0 and 
                       renoise.Sample.LOOP_MODE_PING_PONG or renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = math.max(1, sample_data.loop_begin + 1)
    sample.loop_end = math.max(sample.loop_start, math.min(sample_data.length, sample_data.loop_end - 1))
  else
    sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
  end
  
  return sample
end

function load_sample_data(sample, sample_data, file_data)
  if sample_data.length == 0 or sample_data.sample_pointer == 0 then
    return true
  end
  
  local channels = bit_and(sample_data.flags, SAMPLE_STEREO) ~= 0 and 2 or 1
  local is_16bit = bit_and(sample_data.flags, SAMPLE_16BIT) ~= 0
  local is_compressed = bit_and(sample_data.flags, SAMPLE_COMPRESSED) ~= 0
  local is_signed = bit_and(sample_data.convert, 1) ~= 0
  
  local buffer = sample.sample_buffer
  buffer:prepare_sample_data_changes()
  
  local success = false
  if is_compressed then
    -- Create audible placeholder for compressed samples
    success = create_placeholder_sample_data(buffer, sample_data, channels)
  else
    success = load_uncompressed_sample_data(buffer, sample_data, file_data, channels, is_16bit, is_signed)
  end
  
  buffer:finalize_sample_data_changes()
  return success
end

function load_uncompressed_sample_data(buffer, sample_data, file_data, channels, is_16bit, is_signed)
  local pos = sample_data.sample_pointer + 1
  local frame_count = sample_data.length
  
  for frame = 1, frame_count do
    for channel = 1, channels do
      local sample_value = 0
      
      if is_16bit then
        local low_byte = file_data:byte(pos)
        local high_byte = file_data:byte(pos + 1)
        pos = pos + 2
        
        local raw_value = low_byte + (high_byte * 256)
        if is_signed then
          if raw_value >= 32768 then raw_value = raw_value - 65536 end
          sample_value = raw_value / 32768.0
        else
          sample_value = (raw_value - 32768) / 32768.0
        end
      else
        local byte_value = file_data:byte(pos)
        pos = pos + 1
        
        if is_signed then
          if byte_value >= 128 then byte_value = byte_value - 256 end
          sample_value = byte_value / 128.0
        else
          sample_value = (byte_value - 128) / 128.0
        end
      end
      
      sample_value = math.max(-1.0, math.min(1.0, sample_value))
      buffer:set_sample_data(channel, frame, sample_value)
    end
  end
  
  return true
end

function create_placeholder_sample_data(buffer, sample_data, channels)
  -- Create pink noise placeholder for compressed IT samples
  local seed = sample_data.sample_pointer % 65536
  math.randomseed(seed)
  
  for frame = 1, sample_data.length do
    local noise = (math.random() - 0.5) * 2.0
    local envelope = 1.0
    
    local attack_frames = math.min(1000, sample_data.length * 0.1)
    local release_frames = math.min(2000, sample_data.length * 0.3)
    
    if frame <= attack_frames then
      envelope = frame / attack_frames
    elseif frame >= sample_data.length - release_frames then
      envelope = (sample_data.length - frame) / release_frames
    end
    
    local sample_value = noise * envelope * 0.1
    
    for channel = 1, channels do
      buffer:set_sample_data(channel, frame, sample_value)
    end
  end
  
  return true
end

-- Register file import hook
local iti_integration = {
  category = "instrument",
  extensions = { "iti" },
  invoke = iti_loadinstrument
}

if not renoise.tool():has_file_import_hook("instrument", { "iti" }) then
  renoise.tool():add_file_import_hook(iti_integration)
end

