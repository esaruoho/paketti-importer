---@diagnostic disable: lowercase-global, need-check-nil

function s1000_get_basenote_from_sample(filename)
  -- extract the base note from the supplied .s format sample
  -- used for s1000 .p program loading
  local d = "" -- in memory copy
  local lsb_first = true

  local f_in = io.open(filename, "rb")
  if f_in == nil then
    print("s1000_get_basenote_from_sample: couldn't open .s sample", filename)
    return nil
  end
  f_in:seek("set")
  d = f_in:read("*a")
  f_in:close()

  if read_byte_from_memory(d, 1) ~= 3 then
    print("s1000_get_basenote_from_sample: not an akai s1000 .s sample")
    d = ""
    return nil
  elseif read_byte_from_memory(d, 16) ~= 128 then
    print("s1000_get_basenote_from_sample: not an akai s1000 .s sample")
    d = ""
    return nil
  end

  local base_note = read_byte_from_memory(d, 3)
  print("s1000_get_basenote_from_sample: base_note", base_note)
  d =""
  return base_note
end

function s1000_loadsample(filename)
  renoise.app():show_status("Importing Akai S1000/S3000 Sample...")
  local song = renoise.song()
  if not #song.selected_instrument.samples == 0 then
    local s = song.selected_instrument:sample(1)
    for _, slice in pairs(s.slice_markers) do
      s:delete_slice_marker(slice)
    end
  end
  song.selected_instrument:clear()
  if filename:match("-L.S%d*$") then
    load_it_stereo(filename, filename:gsub("-L(.S%d*)$", "-R%1"))
  elseif filename:match("-R.S%d*$") then
    load_it_stereo(filename:gsub("-R(.S%d*)$", "-L%1"), filename)
  else
    load_it(filename,  0.5)
  end
  return true
end

function load_it_stereo(fname_left, fname_right)
  local aiff_file
  local loop_start = 0
  local loop_end = 0
  local sample_name = ""
  local sample_rate = 0
  local fine_tune = 0
  local transpose = 0
  local active_loop_count = 0

  local lsb_first = true

  local song = renoise.song()
  song.selected_instrument:insert_sample_at(1)
  local smp = song.selected_sample
  local s_basename = fname_left:match("([^/\\]+)$") or "Akai Sample"
  song.selected_instrument.name = s_basename:gsub("-[LR].S%d*$","")
  -- smp.name = s_basename:gsub("-[LR].S%d*$","")
  print(s_basename)

  local left_f_in = io.open(fname_left, "rb")
  local right_f_in = io.open(fname_right, "rb")
  if left_f_in == nil then
    renoise.app():show_status("Couldn't open sample file: " .. left_f_in .. ".")
    return false
  end
  if right_f_in == nil then
    renoise.app():show_status("Couldn't open sample file: " .. right_f_in .. ".")
    return false
  end
  left_f_in:seek("set")
  right_f_in:seek("set")
  local ld = left_f_in:read("*a")
  local rd = right_f_in:read("*a")
  left_f_in:close()
  right_f_in:close()
  if read_byte_from_memory(ld, 1) ~= 3 then
    print("s1000_loadsample: invalid file (byte1)")
    ld = ""
    return false
  elseif read_byte_from_memory(ld, 16) ~= 128 then
    print("s1000_loadsample: invalid file (byte16)")
    ld = ""
    return false
  end
  if read_byte_from_memory(rd, 1) ~= 3 then
    print("s1000_loadsample: invalid file (byte1)")
    rd = ""
    return false
  elseif read_byte_from_memory(rd, 16) ~= 128 then
    print("s1000_loadsample: invalid file (byte16)")
    rd = ""
    return false
  end
  -- we assume right and left metas are identical....
  sample_name = akaii_to_ascii(ld:sub(4,15))
  sample_rate = read_word_from_memory(ld, 139, lsb_first)
  fine_tune = byte_to_twos_compliment(read_byte_from_memory(ld, 21))
  transpose = byte_to_twos_compliment(read_byte_from_memory(ld, 22))
  active_loop_count = read_byte_from_memory(ld, 17)

  print("s1000_loadsample: sample_name", sample_name)
  print("s1000_loadsample: sample_rate", sample_rate)
  print("s1000_loadsample: fine_tune", fine_tune)
  print("s1000_loadsample: transpose", transpose)
  print("s1000_loadsample: active_loop_count", active_loop_count)

  aiff_file = merge_generate_aiff(sample_rate, 16, ld:sub(150), rd:sub(150))
  if smp.sample_buffer.has_sample_data == true then
    if smp.sample_buffer.read_only == true then
      ld = ""
      rd = ""
      return false
    end
  end
  smp:clear()
---@diagnostic disable-next-line: param-type-mismatch
  if smp.sample_buffer:load_from(aiff_file) == false then
    ld = ""
    rd = ""
    return false
  end

  smp.fine_tune = fine_tune
  smp.transpose = transpose
  smp.name = sample_name:upper():gsub("-[LR]$","")
  smp.panning = 0.5
  -- single chans are fullscale, reduce stereo volume...
  -- smp.volume = math.db2lin(-3)

  -- set looping
  if active_loop_count ~= 0 then
    -- use loop 1
    loop_start = read_dword_from_memory(ld, 39, lsb_first)
    loop_end = loop_start + read_dword_from_memory(ld, 45, lsb_first)
    -- validate
    if loop_start <= 0 then
      loop_start = 1
    elseif loop_start > smp.sample_buffer.number_of_frames then
      loop_start = smp.sample_buffer.number_of_frames
    end
    if loop_end <= 0 then
      loop_end = 1
    elseif loop_end > smp.sample_buffer.number_of_frames then
      loop_end = smp.sample_buffer.number_of_frames
    end

    print("s1000_loadsample: loop_start", loop_start)
    print("s1000_loadsample: loop_end", loop_end)
    -- loop location are often faulty... set to no loop to let user decide
    smp.loop_start = loop_start
    smp.loop_end = loop_end
  end
  return true

end

function load_it(fname, pan)
  local aiff_file
  local loop_start = 0
  local loop_end = 0
  local sample_name = ""
  local sample_rate = 0
  local fine_tune = 0
  local transpose = 0
  local active_loop_count = 0

  local lsb_first = true

  local song = renoise.song()
  song.selected_instrument:insert_sample_at(1)
  local smp = renoise.song().selected_sample

  local s_basename = fname:match("([^/\\]+)$") or "Akai Sample"
  renoise.song().selected_instrument.name = s_basename
  renoise.song().selected_sample.name = s_basename

  local f_in = io.open(fname, "rb")
  if f_in == nil then
    renoise.app():show_status("Couldn't open sample file: " .. fname .. ".")
    return false
  end
  f_in:seek("set")
  local d = f_in:read("*a")
  f_in:close()
  if read_byte_from_memory(d, 1) ~= 3 then
    print("s1000_loadsample: invalid file (byte1)")
    d = ""
    return false
  elseif read_byte_from_memory(d, 16) ~= 128 then
    print("s1000_loadsample: invalid file (byte16)")
    d = ""
    return false
  end
  sample_name = akaii_to_ascii(d:sub(4,15))
  sample_rate = read_word_from_memory(d, 139, lsb_first)
  fine_tune = byte_to_twos_compliment(read_byte_from_memory(d, 21))
  transpose = byte_to_twos_compliment(read_byte_from_memory(d, 22))
  active_loop_count = read_byte_from_memory(d, 17)

  print("s1000_loadsample: sample_name", sample_name)
  print("s1000_loadsample: sample_rate", sample_rate)
  print("s1000_loadsample: fine_tune", fine_tune)
  print("s1000_loadsample: transpose", transpose)
  print("s1000_loadsample: active_loop_count", active_loop_count)

  aiff_file = generate_aiff(1, sample_rate, 16, d:sub(150))
  if smp.sample_buffer.has_sample_data == true then
    if smp.sample_buffer.read_only == true then
      d = ""
      return false
    end
  end
  smp:clear()
---@diagnostic disable-next-line: param-type-mismatch
  if smp.sample_buffer:load_from(aiff_file) == false then
    d = ""
    return false
  end

  smp.fine_tune = fine_tune
  smp.transpose = transpose
  smp.name = sample_name
  smp.panning = pan

  -- set looping
  if active_loop_count ~= 0 then
    -- use loop 1
    loop_start = read_dword_from_memory(d, 39, lsb_first)
    loop_end = loop_start + read_dword_from_memory(d, 45, lsb_first)
    -- validate
    if loop_start <= 0 then
      loop_start = 1
    elseif loop_start > smp.sample_buffer.number_of_frames then
      loop_start = smp.sample_buffer.number_of_frames
    end
    if loop_end <= 0 then
      loop_end = 1
    elseif loop_end > smp.sample_buffer.number_of_frames then
      loop_end = smp.sample_buffer.number_of_frames
    end

    print("s1000_loadsample: loop_start", loop_start)
    print("s1000_loadsample: loop_end", loop_end)
    -- loop location are often faulty... set to no loop to let user decide
    -- smp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    smp.loop_start = loop_start
    smp.loop_end = loop_end
  end
  return true
end