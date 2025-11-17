--- ryrun SFZ2XRNI.lua
--- original source: https://gist.github.com/ryrun/a1e9be02a000bf978bbd

--------------------------------------------------------------------------------
-- Write Permission Detection for SFZ Batch Operations
--------------------------------------------------------------------------------

-- Test if a directory is writable by attempting to create a temporary file
local function test_directory_writable(directory_path)
  if not directory_path or directory_path == "" then
    return false, "Invalid directory path"
  end
  
  -- Create a unique temporary filename
  local temp_filename = "paketti_write_test_" .. os.time() .. ".tmp"
  local temp_path = directory_path .. "/" .. temp_filename
  
  -- Try to create and write to the file
  local success, err = pcall(function()
    local file = io.open(temp_path, "w")
    if not file then
      error("Cannot create file")
    end
    file:write("test")
    file:close()
    
    -- Clean up the test file
    os.remove(temp_path)
  end)
  
  return success, err
end

-- Prompt user to select a writable directory for SFZ files
local function prompt_for_sfz_directory()
  local dialog_result = renoise.app():prompt_for_path("Select a writable folder for SFZ files:")
  
  if dialog_result and dialog_result ~= "" then
    local is_writable, error_msg = test_directory_writable(dialog_result)
    if is_writable then
      return dialog_result
    else
      renoise.app():show_error("Selected directory is not writable: " .. (error_msg or "Unknown error") .. "\nPlease select a different directory.")
      return prompt_for_sfz_directory() -- Recursive call to try again
    end
  end
  
  return nil -- User cancelled or no valid directory selected
end

-- Check and get writable directory for SFZ batch operations
local function get_writable_sfz_directory(source_directory)
  -- First, test if the source directory is writable
  local is_writable, error_msg = test_directory_writable(source_directory)
  
  if is_writable then
    return source_directory
  else
    print("Source directory not writable:", source_directory, "Error:", error_msg)
    renoise.app():show_warning(
      "Cannot write to source directory: " .. source_directory .. "\n" ..
      "Error: " .. (error_msg or "Permission denied") .. "\n\n" ..
      "Please select a writable directory for SFZ files."
    )
    
    return prompt_for_sfz_directory()
  end
end

-- SFZ Batch Converter: Save XRNI + Optionally Load into Renoise
function PakettiBatchSFZToXRNI(load_into_renoise)
  load_into_renoise = load_into_renoise or false
  
  local dialog_text = load_into_renoise and "Select SFZ files to convert to XRNI and load" or "Select SFZ files to convert to XRNI (save only)"
  local files = renoise.app():prompt_for_multiple_filenames_to_read({"*.sfz"}, dialog_text)
  
  if #files > 0 then
    -- Check write permissions before starting batch conversion
    local first_file_dir = files[1]:match("^(.+)/[^/]+$") or files[1]:match("^(.+)\\[^\\]+$")
    local output_directory = get_writable_sfz_directory(first_file_dir)
    
    if not output_directory then
      renoise.app():show_status("SFZ batch conversion cancelled - no writable directory selected")
      return
    end
    
    -- Inform user about output directory if it's different from source
    if output_directory ~= first_file_dir then
      renoise.app():show_status("XRNI files will be saved to: " .. output_directory)
    end
    
    local converted_count = 0
    local failed_count = 0
    local xrni_files = {}
    
    -- Step 1: CONVERT all SFZ files to XRNI with Paketti treatment
    -- Create one temporary instrument slot for conversion
    renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
    local temp_index = renoise.song().selected_instrument_index + 1
    renoise.song().selected_instrument_index = temp_index
    
    for i, file_path in ipairs(files) do
      local filename = file_path:match("[^/\\]+$"):gsub("%.sfz$", "")
      local output_path = output_directory .. "/" .. filename .. ".xrni"
      
      renoise.app():show_status(string.format("Converting %d/%d: %s", i, #files, filename))
      
      local success, error_msg = pcall(function()
        -- Clear temporary instrument for each conversion
        renoise.song().selected_instrument:clear()
        
        -- Load Paketti default instrument into temporary slot (if enabled)
        if renoise.tool().preferences.pakettiLoadDefaultInstrument.value then
          pakettiPreferencesDefaultInstrumentLoader()
        end
        
        -- Load SFZ samples into the Paketti instrument
        renoise.app():load_instrument_multi_sample(file_path)
        
        -- Name the instrument
        renoise.song().selected_instrument.name = filename
        
        -- Save as XRNI file
        renoise.app():save_instrument(output_path)
        
        -- Track successful conversions
        table.insert(xrni_files, {path = output_path, name = filename})
      end)
      
      if success then
        converted_count = converted_count + 1
      else
        failed_count = failed_count + 1
        print("Failed to convert " .. filename .. ": " .. tostring(error_msg))
      end
    end
    
    -- Step 2: If load_into_renoise, load each XRNI into separate instrument slots
    if load_into_renoise and #xrni_files > 0 then
      renoise.app():show_status("Loading converted XRNI files into Renoise...")
      
      for i, xrni_info in ipairs(xrni_files) do
        local success, error_msg = pcall(function()
          -- Create new instrument slot for each XRNI
          local new_index = renoise.song().selected_instrument_index + 1
          renoise.song():insert_instrument_at(new_index)
          renoise.song().selected_instrument_index = new_index
          
          -- Load the XRNI file
          renoise.app():load_instrument(xrni_info.path)
        end)
        
        if not success then
          print("Failed to load " .. xrni_info.name .. ": " .. tostring(error_msg))
        end
      end
    end
    
    -- Clean up: remove the temporary instrument slot
    renoise.song():delete_instrument_at(temp_index)
    
    local action_text = load_into_renoise and "converted & loaded" or "converted"
    local output_info = (output_directory ~= first_file_dir) and (" (saved to: " .. output_directory .. ")") or ""
    renoise.app():show_status(string.format("SFZ Batch: %d %s, %d failed%s", converted_count, action_text, failed_count, output_info))
  else
    renoise.app():show_status("No SFZ files selected for conversion")
  end
end

