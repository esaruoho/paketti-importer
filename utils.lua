---@diagnostic disable: lowercase-global

function read_byte_from_memory(data, pos)
  -- read a byte at position pos
  if data and pos then
    return string.byte(data, pos)
  end
end

function read_word_from_memory(data, pos, lsb_first)
  if data and pos then
    if lsb_first then
      return string.byte(data, pos) + 
        bit.lshift(string.byte(data, pos + 1), 8)
    else
      return string.byte(data, pos + 1) +
        bit.lshift(string.byte(data, pos), 8)
    end
  end
end

function read_dword_from_memory(data, pos, lsb_first)
  -- extract a double word at position pos
  if data and pos then
    if lsb_first then
      return string.byte(data, pos) +
        bit.lshift(string.byte(data, pos + 1), 8) +
        bit.lshift(string.byte(data, pos + 2), 16) +
        bit.lshift(string.byte(data, pos + 3), 24)
    else
      return string.byte(data, pos + 3) +
        bit.lshift(string.byte(data, pos + 2), 8) +
        bit.lshift(string.byte(data, pos + 1), 16) +
        bit.lshift(string.byte(data, pos), 24)
    end
  end
end

function byte_to_twos_compliment(value)
  if value == 0x80 then
    return -128
  elseif value < 0x80 then
    return value
  else
    return -128+(value-0x80)
  end
end

function hex_pack(string)
  local raw_string = string.char(tonumber(string:sub(1,2), 16))
  for i = 3, (string:len()-1), 2 do
    raw_string = raw_string .. string.char(tonumber(string:sub(i,i+1), 16))
  end
  return raw_string
end

function merge_generate_aiff(samplerate, bit_depth, left_data, right_data)
  local aiff_file = os.tmpname("aiff")
  local frames = left_data:len() / (bit_depth / 16)
  local length = left_data:len() + 27
  print("generate_aiff: aiff_file=", aiff_file)
  local f = io.open(aiff_file, "wb")
  if f == nil then
    return false
  end
  f:write("FORM")
  f:write(hex_pack(string.format("%08X", length))) -- chunk size = file length - 8 
  f:write("AIFF")
  f:write("COMM") -- (4 bytes)
  f:write(hex_pack("00000012")) -- chunk size = 18 bytes
  f:write(string.char(00, 2))   -- channel count
  f:write(hex_pack(string.format("%08X", frames))) -- sample frames
  f:write(hex_pack(string.format("%04X", bit_depth))) -- bit depth)
  f:write(hex_pack("400E" .. string.format("%04X", samplerate) .. "000000000000"))  -- sample rate as 10 bit float hack
  f:write("SSND") -- (4 bytes)
  f:write(hex_pack(string.format("%08X", left_data:len() + 16))) -- chunk size
  f:write(hex_pack("00000000"))   -- offset
  f:write(hex_pack("00000000"))   -- blocksize
  -- local right_offset = frames * (bit_depth/8)
  for i = 1, frames, (bit_depth / 8) do  -- interleaved audio
    f:write(left_data:sub(i, i + (bit_depth/16))) --left
    f:write(right_data:sub(i, i + (bit_depth/16))) --right
  end
  f:flush()
  f:close()
  return aiff_file
end

function generate_aiff(channels, samplerate, bit_depth, audiodata)
  -- writes a aiff file (to a Renoise temporary location) with the supplied data
  local aiff_file = os.tmpname("aiff")
  local frames = audiodata:len() / (channels * (bit_depth / 8))
  local length = audiodata:len() + 27
  print("generate_aiff: aiff_file=", aiff_file)
  local f = io.open(aiff_file, "wb")
  if f == nil then
    return false
  end
  f:write("FORM")
  f:write(hex_pack(string.format("%08X", length))) -- chunk size = file length - 8 
  f:write("AIFF")
  f:write("COMM") -- (4 bytes)
  f:write(hex_pack("00000012")) -- chunk size = 18 bytes
  f:write(string.char(00, channels))   -- channel count
  f:write(hex_pack(string.format("%08X", frames))) -- sample frames
  f:write(hex_pack(string.format("%04X", bit_depth))) -- bit depth)
  f:write(hex_pack("400E" .. string.format("%04X", samplerate) .. "000000000000"))  -- sample rate as 10 bit float hack
  f:write("SSND") -- (4 bytes)
  f:write(hex_pack(string.format("%08X", audiodata:len() + 16))) -- chunk size
  f:write(hex_pack("00000000"))   -- offset
  f:write(hex_pack("00000000"))   -- blocksize
  if channels == 1 then
    f:write(audiodata)
  elseif channels == 2 then
    local right_offset = frames * (bit_depth/8)
    for i = 1, frames, (bit_depth / 8) do  -- interleaved audio
      f:write(audiodata:sub(i, i + (bit_depth/8)))                               --left
      f:write(audiodata:sub(right_offset + i, right_offset + i + (bit_depth/8))) --right
    end
  end
  f:flush()
  f:close()
  return aiff_file
end

function akaii_to_ascii(akaii_string)
  -- Convert 'AKAII' to ASCII for AKAI naming in certain samplers
  local len = akaii_string:len()
  local ascii_string = ""
  for i=1, len do
    if string.byte(akaii_string:sub(i,i)) < 10 then
      -- number
      ascii_string = ascii_string .. string.char(string.byte(akaii_string:sub(i,i)) + 48)
    elseif string.byte(akaii_string:sub(i,i)) == 10 then
      -- space
      ascii_string = ascii_string .. " "
    elseif string.byte(akaii_string:sub(i,i)) > 10 then
      if string.byte(akaii_string:sub(i,i)) < 37 then
        -- letter
        ascii_string = ascii_string .. string.char(string.byte(akaii_string:sub(i,i)) + 86)
      elseif string.byte(akaii_string:sub(i,i)) == 37 then
        -- #
        ascii_string = ascii_string .. "#"
      elseif string.byte(akaii_string:sub(i,i)) == 38 then
        -- +
        ascii_string = ascii_string .. "+"
      elseif string.byte(akaii_string:sub(i,i)) == 39 then
        -- -
        ascii_string = ascii_string .. "-"
      elseif string.byte(akaii_string:sub(i,i)) == 40 then
        -- .
        ascii_string = ascii_string .. "."
      end
    end
  end
  return ascii_string
end

function split_filename(filename)
  -- Splits a qualified filename into path and filename and returns each or
  -- "", "" on error
  local start_pos = nil
  local end_pos = nil
  local i = 1
  local found = false
  
  -- start of filename (end of path)
  while found == false do
    start_pos = string.find(filename, '[/\\]', -i)
    i = i + 1
    if i > string.len(filename) then 
      return "",""
    end
    if start_pos ~= nil then
      found = true
    end
  end 
  
  -- end of filename
  found = false
  i = 1
  while found == false do
    end_pos = string.find(filename, '[.]', -i)
    i = i + 1
    if i > string.len(filename) then 
      return "",""
    end
    if end_pos ~= nil then
      found = true
    end
  end
  -- return path/filename
  return string.sub(filename,1, start_pos), string.sub(filename,start_pos+1, end_pos-1)
end

function load_file_to_memory(filename)
  local cache
  local f = io.open(filename, "rb")
  if f == nil then
    return ""
  end
  f:seek("set", 0)
  cache = f:read("*a")
  io.close(f)
  return cache
end

function get_samples_path(instrument_name, instrument_path, sample_filename)
  -- Intelligently guess the sample path from the supplied instrument name,
  -- example sample filename and instrument path
  -- Ask the user if we cannot find it ourselves
  -- Return "" on error/abort
  local sample_path
  if io.exists(instrument_path .. sample_filename) == true then
    return instrument_path
  elseif io.exists(instrument_path .. instrument_name .. "/" .. sample_filename) == true then
    return instrument_path .. instrument_name .. "/"
  elseif io.exists(instrument_path .. "samples/" .. sample_filename) == true then
    return instrument_path .. "samples/"
  elseif io.exists(instrument_path .. instrument_name .."-samples/" ..sample_filename) == true then
    return instrument_path .. instrument_name .. "-samples/"
  elseif io.exists(instrument_path .. instrument_name .."_samples/" .. sample_filename) == true then
    return instrument_path .. instrument_name .. "_samples/"
  elseif io.exists(instrument_path .. instrument_name .." samples/" .. sample_filename) == true then
    return instrument_path .. instrument_name .. " samples/"
  elseif io.exists("/Library/Application Support/GarageBand/Instrument Library/Sampler/Sampler Files/" .. instrument_name .. "/" .. sample_filename) == true then  -- added v1.1
    return "/Library/Application Support/GarageBand/Instrument Library/Sampler/Sampler Files/" .. instrument_name .. "/"
  else
    return nil
    -- return renoise.app():prompt_for_path("Location of samples for patch: " .. instrument_name)
  end
end
