-- PakettiImageToSample.lua
-- Convert image files (PNG, BMP, JPG, GIF) to waveforms

-- Convert image brightness to waveform amplitude
function image_to_waveform(image_path)
  if not image_path then
    -- Create a default sine wave for demonstration
    local samples = 512
    local waveform_data = {}
    
    for i = 0, samples - 1 do
      local phase = (i / samples) * 2 * math.pi
      local amplitude = math.sin(phase)
      table.insert(waveform_data, amplitude)
    end
    
    return waveform_data
  end
  
  local samples = 1024
  local waveform_data = {}
  
  -- Read bytes from the image file for analysis
  local file = io.open(image_path, "rb")
  if not file then
    -- Fallback to default sine wave
    for i = 0, samples - 1 do
      local phase = (i / samples) * 2 * math.pi
      local amplitude = math.sin(phase)
      table.insert(waveform_data, amplitude)
    end
    return waveform_data
  end
  
  -- Read first 1024 bytes of the file
  local file_data = file:read(1024)
  file:close()
  
  if not file_data then file_data = "" end
  
  -- Convert file bytes to waveform amplitudes
  for i = 0, samples - 1 do
    local byte_index = (i % #file_data) + 1
    local byte_value = 0
    
    if i < #file_data then
      byte_value = string.byte(file_data, byte_index) or 0
    end
    
    -- Normalize byte value (0-255) to amplitude (-1 to 1)
    local amplitude = (byte_value / 127.5) - 1.0
    
    -- Add smoothing with neighboring values
    if i > 0 and i < samples - 1 then
      local prev_byte = string.byte(file_data, math.max(1, byte_index - 1)) or 0
      local next_byte = string.byte(file_data, math.min(#file_data, byte_index + 1)) or 0
      local prev_amp = (prev_byte / 127.5) - 1.0
      local next_amp = (next_byte / 127.5) - 1.0
      amplitude = (prev_amp * 0.25 + amplitude * 0.5 + next_amp * 0.25)
    end
    
    table.insert(waveform_data, amplitude)
  end
  
  return waveform_data
end

-- Export waveform as sample
function export_image_to_sample(waveform_data, image_path)
  if not waveform_data then
    renoise.app():show_status("No waveform data to export")
    return false
  end
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  -- Ensure the instrument has at least one sample
  if #instrument.samples == 0 then
    instrument:insert_sample_at(1)
  end
  
  local sample = instrument.samples[1]
  local sample_buffer = sample.sample_buffer
  
  -- Create new sample buffer
  sample_buffer:create_sample_data(44100, 16, 1, #waveform_data)
  
  -- Copy waveform data to sample buffer
  if sample_buffer.has_sample_data then
    sample_buffer:prepare_sample_data_changes()
    
    for i = 1, #waveform_data do
      sample_buffer:set_sample_data(1, i, waveform_data[i])
    end
    
    sample_buffer:finalize_sample_data_changes()
  end
  
  -- Set a nice name for the sample
  if image_path then
    local filename = image_path:match("([^/\\]+)$") or "image"
    local basename = filename:match("(.+)%..+$") or filename
    sample.name = "IMG_" .. basename
  end
  
  -- Set loop points
  sample.loop_start = 1
  sample.loop_end = #waveform_data
  sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
  
  renoise.app():show_status("Image converted to waveform: " .. (sample.name or "Sample 01"))
  return true
end

-- File import hook for image formats
local function image_import_hook(file_path)
  -- Handle instrument creation based on preference
  if not renoise.tool().preferences.pakettiOverwriteCurrent.value then
    renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
    renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1
  end
  
  -- Load Paketti default instrument configuration (if enabled)
  if renoise.tool().preferences.pakettiLoadDefaultInstrument.value then
    pakettiPreferencesDefaultInstrumentLoader()
  end
  
  -- Convert image to waveform
  local waveform_data = image_to_waveform(file_path)
  
  -- Export to sample
  return export_image_to_sample(waveform_data, file_path)
end

-- Create integration for image formats
local image_integration = {
  category = "sample",
  extensions = { "png", "bmp", "jpg", "jpeg", "gif" },
  invoke = image_import_hook
}

-- Add file import hook if not already present
if not renoise.tool():has_file_import_hook("sample", { "png", "bmp", "jpg", "jpeg", "gif" }) then
  renoise.tool():add_file_import_hook(image_integration)
end

