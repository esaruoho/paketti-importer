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
-- Paketti preferences
preferences = renoise.Document.create("ScriptingToolPreferences") {
  pakettiOverwriteCurrent = false  -- false = create new instrument (default), true = overwrite current
  pakettiREXBundlePath = "." .. separator .. "rx2",
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