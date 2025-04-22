---@diagnostic disable: lowercase-global

require("ProcessSlicer")
require("s1000s")

function s1000_loadinstrument(filename)
  -- Main import function for .p files
  local d = ""
  local instrument = renoise.song().selected_instrument
  local inst_name = ""
  local inst_path = ""
  local samples = {}
  -- local sample_path
  -- local lsb_first = false
  local sliced_process

  renoise.app():show_status("Importing Akai S1000 Program...")
  inst_path, inst_name = split_filename(filename)

  if inst_path == "" then
    return false
  elseif inst_name == "" then
    return false
  end

  d = load_file_to_memory(filename)
  if d == "" then
    renoise.app():show_status("Couldn't open Akai S1000 program file.")
    return false
  end

  if read_byte_from_memory(d,1) ~= 1 then
    renoise.app():show_error(filename .. " is not a valid Akai S1000 program file.")
    renoise.app():show_status(filename .. " is not a valid Akai S1000 program file.")
    d = ""
    return false
  end

  print("s1000_loadinstrument: inst_name", inst_name)

  for chunk_start=150, ((d:len()/150)-1)*150, 150 do
    print("s1000_loadinstrument: chunk_start", chunk_start)

    local zone_key_lo = read_byte_from_memory(d, chunk_start + 4)
    local zone_key_hi = read_byte_from_memory(d, chunk_start + 5)
    local zone_transpose = byte_to_twos_compliment(read_byte_from_memory(d, chunk_start + 6))
    local zone_finetune = byte_to_twos_compliment(read_byte_from_memory(d, chunk_start + 7))

    for sample_offset = 35,103,34 do
      local vel_lo = read_byte_from_memory(d, chunk_start + sample_offset + 12)
      local vel_hi = read_byte_from_memory(d, chunk_start + sample_offset + 13)
      local transpose = zone_transpose +
                        byte_to_twos_compliment(read_byte_from_memory(d, chunk_start + sample_offset + 15))
      local finetune = zone_finetune +
                       byte_to_twos_compliment(read_byte_from_memory(d, chunk_start + sample_offset + 14))
      local sample_name = ""
      if d:sub(chunk_start+sample_offset, chunk_start+sample_offset):byte() ~= 10 then
        if d:sub(chunk_start+sample_offset, chunk_start+sample_offset):byte() ~= 0 then
          sample_name = akaii_to_ascii(d:sub(chunk_start+sample_offset, chunk_start+sample_offset+11))
          -- strip off trailing whitespace
          while sample_name:sub(sample_name:len(), sample_name:len()) == " " do
            sample_name = sample_name:sub(1, sample_name:len()-1)
          end
          sample_name = string.upper(sample_name)
          sample_name = sample_name .. ".S" .. filename:match("%d*$")
          table.insert(samples, {sample_name, zone_key_lo, zone_key_hi, vel_lo, vel_hi, transpose, finetune})
        end
      end
    end
  end

  print("s1000_loadinstrument: parsed ",#samples, "sample chunks successfully")

  if #samples > 254 then
    table.clear(samples)
    renoise.app():show_error("Sorry, Renoise is limited to 255 samples per instrument.  The instrument you are trying to import has more than this.")
    renoise.app():show_status(filename .. " has too many samples for Renoise!  Aborting.")
    return false
  end

  local sample_path
  for i=1, #samples do
    sample_path = get_samples_path(inst_name, inst_path, samples[i][1])
    if sample_path ~= nil then
      break
    end
  end

  if sample_path == "" then
    sample_path = renoise.app():prompt_for_path("Location of samples for patch: " .. inst_name)
  end
  if sample_path == "" then
    renoise.app():show_status("Akai S1000 program import aborted.")
    return false
  end

  inst_name = akaii_to_ascii(d:sub(4,15))
  d = ""
  instrument:clear()
  instrument.name = inst_name

  sliced_process = ProcessSlicer(s1000_loadinstrument_samples, nil, instrument, sample_path, samples)
  sliced_process:start()
  return true
end

function setup_slot(instrument, sample, sample_path)
  local s = instrument:sample(1)
  local t = sample[2]
  if t < 0 then
    t = 0
  elseif t > 119 then
    t = 119
  end
  sample[2] = t
  t = sample[3]
  if t < 0 then
    t = 0
  elseif t > 119 then
    t = 119
  end
  sample[3] = t
  -- set transpose
  t = sample[6]
  if t < -127 then
    t = -127
  elseif t > 127 then
    t = 127
  end
  s.transpose = t
  -- set finetune
  t = sample[7]
  if t < -127 then
    t = -127
  elseif t > 127 then
    t = 127
  end
  s.fine_tune = t
  -- volume
  -- we usually get stereo slices, take their volume down
  -- s.volume = math.db2lin(-3)
  -- create sample mapping
  local base_note = s1000_get_basenote_from_sample(sample_path .. sample[1])
  s.sample_mapping.map_key_to_pitch = true
  if base_note ~= nil then
    s.sample_mapping.base_note = base_note - 12
  else
    s.sample_mapping.base_note = 60
  end
  s.sample_mapping.note_range = {sample[2],sample[3]}
  s.sample_mapping.velocity_range = {sample[4],sample[5]}
end

function reverse(tab)
    for i = 1, #tab/2, 1 do
        tab[i], tab[#tab-i+1] = tab[#tab-i+1], tab[i]
    end
    return tab
end


function s1000_loadinstrument_samples(instrument, sample_path, samples)
  -- rprint(samples)
  samples = reverse(samples)
  -- rprint(samples)

  local missing_samples = 0
  for i = 1, #samples do
    samples[i][1] = samples[i][1]:upper()
    if io.exists(sample_path .. samples[i][1]) == false then
      -- try with -L.s ending  (ugly workaround)
      samples[i][1] = samples[i][1]:gsub("-l.s", "-L.s", 1)
      print("trying sample", samples[i][1])
    end
    if io.exists(sample_path .. samples[i][1]) == false then 
      print("s1000_loadinstrument_samples: missing sample=", sample_path .. samples[i][1])
      missing_samples = missing_samples + 1
    else

      if samples[i][1]:match("-L.S%d*$") then
        local sample_right = samples[i] -- [1]:gsub("-L(.S%d*)$", "-R%1")
        sample_right[1] = sample_right[1]:gsub("-L(.S%d*)$", "-R%1")
        if load_it_stereo(sample_path..samples[i][1], sample_path..sample_right[1]) == true then
          setup_slot(instrument, samples[i], sample_path)
          setup_slot(instrument, sample_right, sample_path)
        end
      elseif samples[i][1]:match("-R.S%d*$") then
        local sample_left = samples[i] -- [1]:gsub("-L(.S%d*)$", "-R%1")
        sample_left[1] = sample_left[1]:gsub("-R(.S%d*)$", "-L%1")
        if load_it_stereo(sample_path..samples[i][1], sample_path..sample_left[1]) == true then
          setup_slot(instrument, samples[i], sample_path)
          setup_slot(instrument, sample_left, sample_path)
        end
      else
        if load_it(sample_path .. samples[i][1], 0.5) == true then
          setup_slot(instrument, samples[i], sample_path)
        end
      end
    end
    renoise.app():show_status(string.format("Importing Akai S1000 program file (%d%% done)...",((i/#samples))*100))
      coroutine.yield()
  end
  if missing_samples == 0 then
    renoise.app():show_status("Importing Akai S1000 program complete.")
  else
    renoise.app():show_status(string.format("Importing Akai S1000 program partially complete (%d missing samples).", missing_samples))
  end
end