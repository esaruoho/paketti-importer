function paketti_toggle_signed_unsigned()
  local instr=renoise.song().selected_instrument
  if not instr or #instr.samples==0 then renoise.app():show_status("No sample found.") return end
  local smp=instr.samples[renoise.song().selected_sample_index]
  if not smp.sample_buffer.has_sample_data then renoise.app():show_status("Empty sample buffer.") return end

  local buf=smp.sample_buffer
  local frames=math.min(512, buf.number_of_frames)
  local avg=0
  for f=1,frames do
    avg=avg+buf:sample_data(1,f)
  end
  avg=avg/frames

  local unwrap=(avg>0.25) -- if mean is high, likely unsigned-wrap

  buf:prepare_sample_data_changes()
  for c=1,buf.number_of_channels do
    for f=1,buf.number_of_frames do
      local val=buf:sample_data(c,f)
      local out
      if unwrap then
        local u16=math.floor(((val+1.0)*0.5)*65535)
        local i16=(u16>=32768) and (u16-65536) or u16
        out=i16/32768
      else
        local i16=math.floor(val*32768)
        local u16=(i16+65536)%65536
        out=((u16/65535)*2.0)-1.0
      end
      buf:set_sample_data(c,f,math.max(-1.0,math.min(1.0,out)))
    end
  end
  buf:finalize_sample_data_changes()

  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  local msg=unwrap and "Unwrapped unsigned to signed." or "Wrapped signed to unsigned."
  renoise.app():show_status(msg)
end

--renoise.tool():add_menu_entry {name="Sample Editor:Paketti..:Toggle Signed/Unsigned",invoke=paketti_toggle_signed_unsigned}
renoise.tool():add_menu_entry {name="Sample Editor:Paketti..:Process..:Toggle Signed/Unsigned",invoke=paketti_toggle_signed_unsigned}

renoise.tool():add_keybinding {name="Sample Editor:Paketti:Toggle Signed/Unsigned",invoke=paketti_toggle_signed_unsigned}





renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Samples..:Load .MOD as Sample",
  invoke=function() 
    local file_path = renoise.app():prompt_for_filename_to_read({"*.mod"}, "Select Any File to Load as Sample")
    if file_path ~= "" then
      pakettiLoadExeAsSample(file_path)
      paketti_toggle_signed_unsigned() end end}

renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Load .MOD as Sample",
  invoke=function() 
    local file_path = renoise.app():prompt_for_filename_to_read({"*.mod"}, "Select Any File to Load as Sample")
    if file_path ~= "" then
      pakettiLoadExeAsSample(file_path)
      paketti_toggle_signed_unsigned() end end}


renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti..:Load .MOD as Sample",invoke=function() 
    local file_path = renoise.app():prompt_for_filename_to_read({"*.mod"}, "Select Any File to Load as Sample")
    if file_path ~= "" then
      pakettiLoadExeAsSample(file_path)
      paketti_toggle_signed_unsigned() end end}


renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Load .MOD as Sample",
  invoke=function() 
    local file_path = renoise.app():prompt_for_filename_to_read({"*.mod"}, "Select Any File to Load as Sample")
    if file_path ~= "" then
      pakettiLoadExeAsSample(file_path)
      paketti_toggle_signed_unsigned() end end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Samples..:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}


-- helpers to build little-endian words/dwords for WAV header
local function le_u16(n)
  return string.char(n % 256, math.floor(n/256) % 256)
end
local function le_u32(n)
  local b1 = n % 256
  local b2 = math.floor(n/256) % 256
  local b3 = math.floor(n/65536) % 256
  local b4 = math.floor(n/16777216) % 256
  return string.char(b1, b2, b3, b4)
end

function load_samples_from_mod()
  -- pick a .mod
  local mod_file = renoise.app():prompt_for_filename_to_read(
    { "mod" }, "Load .MOD file"
  )
  if not mod_file then 
    renoise.app():show_status("No MOD selected.") 
    return 
  end

  -- read full file
  local f = io.open(mod_file, "rb")
  if not f then 
    renoise.app():show_status("Cannot open .MOD") 
    return 
  end
  local data = f:read("*all")
  f:close()

  -- parse 31 sample headers
  local sample_infos = {}
  local off = 21
  for i = 1,31 do
    local raw_name = data:sub(off, off+21)
    local name = raw_name:gsub("%z+$","")
    local length     = read_be_u16(data, off+22) * 2
    local loop_start = read_be_u16(data, off+26) * 2
    local loop_len   = read_be_u16(data, off+28) * 2
    sample_infos[i] = {
      name        = (#name>0 and name) or ("Sample_"..i),
      length      = (length>0 and length) or nil,
      loop_start  = loop_start,
      loop_length = loop_len,
    }
    off = off + 30
  end

  -- compute patterns to skip
  local song_len    = data:byte(951)
  local patt_bytes  = { data:byte(953, 953+127) }
  local maxp = 0
  for i = 1, song_len do
    if patt_bytes[i] and patt_bytes[i] > maxp then
      maxp = patt_bytes[i]
    end
  end
  local num_patterns = maxp + 1

  -- channels from ID
  local id = data:sub(1081,1084)
  local channel_map = { M_K=4, ["4CHN"]=4, ["6CHN"]=6, ["8CHN"]=8, ["FLT4"]=4, ["FLT8"]=8 }
  local channels = channel_map[id] or 4

  -- skip to sample data
  local patt_size = num_patterns * 64 * channels * 4
  local sample_data_off = 1085 + patt_size

  -- loop through each sample
  for idx,info in ipairs(sample_infos) do
    if info.length then
      -- extract raw sample
      local s0 = sample_data_off
      local s1 = s0 + info.length - 1
      local raw = data:sub(s0, s1)
      sample_data_off = s1 + 1

      -- signed→unsigned
      local unsigned = raw:gsub(".", function(c)
        return string.char((c:byte() + 128) % 256)
      end)

      -- make minimal 8-bit/44.1k WAV header
      local sr, nch, bits = 44100, 1, 8
      local byte_rate   = sr * nch * (bits/8)
      local block_align = nch * (bits/8)
      local data_sz     = #unsigned
      local fmt_sz      = 16
      local riff_sz     = 4 + (8 + fmt_sz) + (8 + data_sz)

      local hdr = {
        "RIFF", le_u32(riff_sz), "WAVE",
        "fmt ", le_u32(fmt_sz),
        le_u16(1),       -- PCM
        le_u16(nch),
        le_u32(sr),
        le_u32(byte_rate),
        le_u16(block_align),
        le_u16(bits),
        "data", le_u32(data_sz),
      }
      local header = table.concat(hdr)

      -- write to temp .wav
      local tmp = os.tmpname()..".wav"
      local wf  = io.open(tmp,"wb")
      wf:write(header)
      wf:write(unsigned)
      wf:close()

      -- apply Paketti defaults + insert instrument
      
      local next_ins = renoise.song().selected_instrument_index + 1
      renoise.song():insert_instrument_at(next_ins)
      renoise.song().selected_instrument_index = next_ins
      -- Load Paketti default instrument configuration (if enabled)
      if renoise.tool().preferences.pakettiLoadDefaultInstrument.value then
        pakettiPreferencesDefaultInstrumentLoader()
      end
      local ins = renoise.song().selected_instrument
      
      -- name instrument from .mod
      ins.name = info.name
      ins.macros_visible = true
      ins.sample_modulation_sets[1].name = "Pitchbend"

      -- ensure sample slot 1 exists
      if #ins.samples == 0 then ins:insert_sample_at(1) end
      renoise.song().selected_sample_index = 1

      -- load the sample
      local samp = ins.samples[1]
      if samp.sample_buffer:load_from(tmp) then
        -- name the sample too
        samp.name = info.name

        -- prefs
        samp.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
        samp.oversample_enabled = true
        samp.autofade           = true
        samp.autoseek           = false
        samp.oneshot            = false
        samp.new_note_action    = renoise.Sample.NEW_NOTE_ACTION_NOTE_CUT
        samp.loop_release       = false

        -- set looping only if loop_length > 1
        if info.loop_length and info.loop_length > 5 then
          samp.loop_mode  = renoise.Sample.LOOP_MODE_FORWARD
          samp.loop_start = info.loop_start + 1
          samp.loop_end   = info.loop_start + info.loop_length
        else
          samp.loop_mode  = renoise.Sample.LOOP_MODE_OFF
        end

        renoise.app():show_status(("Loaded “%s”"):format(info.name))
      else
        renoise.app():show_status(("Failed to load “%s”"):format(info.name))
      end

      -- clean up
      os.remove(tmp)
    end
  end

  renoise.app():show_status("All MOD samples loaded.")
end

---
-- big-endian 16-bit reader, 1-based
local function read_be_u16(str, pos)
  local b1,b2 = str:byte(pos,pos+1)
  return b1*256 + b2
end

-- determine where in a 4-ch/31-sample .mod the sample data begins
local function find_mod_sample_data_offset(data)
  -- song length
  local song_len = data:byte(951)
  -- pattern table
  local patt = { data:byte(953, 953+127) }
  local maxp = 0
  for i=1,song_len do
    if patt[i] and patt[i]>maxp then maxp = patt[i] end
  end
  local num_patterns = maxp + 1

  -- channel count from bytes 1081–1084
  local id = data:sub(1081,1084)
  local channels = ({
    ["M.K."]=4, ["4CHN"]=4, ["6CHN"]=6,
    ["8CHN"]=8, ["FLT4"]=4, ["FLT8"]=8
  })[id] or 4

  -- offset = 1084 (end of header) + pattern_data_size
  local pattern_data_size = num_patterns * 64 * channels * 4
  return 1084 + pattern_data_size
end

function pakettiLoadExeAsSample(file_path)
  local f = io.open(file_path,"rb")
  if not f then 
    renoise.app():show_status("Could not open file: "..file_path)
    return 
  end
  local data = f:read("*all")
  f:close()
  if #data == 0 then 
    renoise.app():show_status("File is empty.") 
    return 
  end

  -- detect .mod by extension or signature
  local is_mod = file_path:lower():match("%.mod$")
  if not is_mod then
    -- maybe detect signature too?
    local sig = data:sub(1081,1084)
    if sig:match("^[46]CHN$") or sig=="M.K." or sig=="FLT4" or sig=="FLT8" then
      is_mod = true
    end
  end

  local raw
  if is_mod then
    -- strip header & patterns
    local off = find_mod_sample_data_offset(data)
    -- Lua strings are 1-based, so data:sub(off+1) if off bytes are header
    raw = data:sub(off+1)
  else
    raw = data
  end

  -- now load raw as before
  local name = file_path:match("([^\\/]+)$") or "Sample"
  renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
  renoise.song().selected_instrument_index =
    renoise.song().selected_instrument_index + 1
  -- Load Paketti default instrument configuration (if enabled)
  if renoise.tool().preferences.pakettiLoadDefaultInstrument.value then
    pakettiPreferencesDefaultInstrumentLoader()
  end

  local instr = renoise.song().selected_instrument
  instr.name = name

  local smp = instr:insert_sample_at(#instr.samples+1)
  smp.name = name

  -- 8363 Hz, 8-bit, mono
  local length = #raw
  smp.sample_buffer:create_sample_data(8363, 8, 1, length)

  local buf = smp.sample_buffer
  buf:prepare_sample_data_changes()
  for i = 1, length do
    local byte = raw:byte(i)
    local val  = (byte / 255) * 2.0 - 1.0
    buf:set_sample_data(1, i, val)
  end
  buf:finalize_sample_data_changes()

  -- clean up any “Placeholder sample” left behind
  for i = #instr.samples, 1, -1 do
    if instr.samples[i].name == "Placeholder sample" then
      instr:delete_sample_at(i)
    end
  end

  renoise.app().window.active_middle_frame =
    renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR

  local what = is_mod and "MOD samples" or "bytes"
  renoise.app():show_status(
    ("Loaded %q as 8-bit-style sample (%d %s at 8363Hz).")
    :format(name, length, what)
  )
end


renoise.tool():add_file_import_hook{category="sample",extensions={"exe","dll","bin","sys","dylib"},invoke=pakettiLoadExeAsSample}

