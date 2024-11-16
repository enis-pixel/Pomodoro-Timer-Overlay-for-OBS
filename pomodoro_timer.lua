obs = obslua

-- Timer settings (configurable)
local work_duration = 45 * 60
local break_duration = 5 * 60
local total_sessions = 1

-- Timer state
local current_session = 0
local countdown = work_duration
local is_break = false
local timer_active = false
local script_directory = debug.getinfo(1).source:match("@?(.*/)")
local timer_file = script_directory .. "timer_status.txt"


-- Update interval
local interval = 1000

-- Hotkey IDs
local hotkey_id_start = obs.OBS_INVALID_HOTKEY_ID
local hotkey_id_stop = obs.OBS_INVALID_HOTKEY_ID
local hotkey_id_reset = obs.OBS_INVALID_HOTKEY_ID

function script_description()
    return "Pomodoro Timer with configurable settings, hotkey support, and external UI integration."
end

function script_defaults(settings)
    obs.obs_data_set_default_int(settings, "work_duration", 45)
    obs.obs_data_set_default_int(settings, "break_duration", 5)
    obs.obs_data_set_default_int(settings, "total_sessions", 1)
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_int(props, "work_duration", "Work Time (minutes)", 1, 999, 1)
    obs.obs_properties_add_int(props, "break_duration", "Break Time (minutes)", 1, 30, 1)
    obs.obs_properties_add_int(props, "total_sessions", "Total Sessions", 1, 10, 1)
    obs.obs_properties_add_button(props, "start_button", "Start Timer", start_timer)
    obs.obs_properties_add_button(props, "stop_button", "Stop Timer", stop_timer)
    obs.obs_properties_add_button(props, "reset_button", "Reset Timer", reset_timer)
    return props
end

function script_update(settings)
    work_duration = obs.obs_data_get_int(settings, "work_duration") * 60
    break_duration = obs.obs_data_get_int(settings, "break_duration") * 60
    total_sessions = obs.obs_data_get_int(settings, "total_sessions")
    reset_timer()
end

function script_load(settings)
    hotkey_id_start = obs.obs_hotkey_register_frontend("start_timer_hotkey", "Start Timer", start_timer)
    hotkey_id_stop = obs.obs_hotkey_register_frontend("stop_timer_hotkey", "Stop Timer", stop_timer)
    hotkey_id_reset = obs.obs_hotkey_register_frontend("reset_timer_hotkey", "Reset Timer", reset_timer)

    local hotkey_start_array = obs.obs_data_get_array(settings, "hotkey_start")
    local hotkey_stop_array = obs.obs_data_get_array(settings, "hotkey_stop")
    local hotkey_reset_array = obs.obs_data_get_array(settings, "hotkey_reset")

    obs.obs_hotkey_load(hotkey_id_start, hotkey_start_array)
    obs.obs_hotkey_load(hotkey_id_stop, hotkey_stop_array)
    obs.obs_hotkey_load(hotkey_id_reset, hotkey_reset_array)

    obs.obs_data_array_release(hotkey_start_array)
    obs.obs_data_array_release(hotkey_stop_array)
    obs.obs_data_array_release(hotkey_reset_array)
    reset_timer()
end

function script_save(settings)
    local hotkey_start_array = obs.obs_hotkey_save(hotkey_id_start)
    local hotkey_stop_array = obs.obs_hotkey_save(hotkey_id_stop)
    local hotkey_reset_array = obs.obs_hotkey_save(hotkey_id_reset)

    obs.obs_data_set_array(settings, "hotkey_start", hotkey_start_array)
    obs.obs_data_set_array(settings, "hotkey_stop", hotkey_stop_array)
    obs.obs_data_set_array(settings, "hotkey_reset", hotkey_reset_array)

    obs.obs_data_array_release(hotkey_start_array)
    obs.obs_data_array_release(hotkey_stop_array)
    obs.obs_data_array_release(hotkey_reset_array)
end

function start_timer()
    if not timer_active then
        timer_active = true
        obs.timer_add(update_timer, interval)
    end
end

function stop_timer()
    timer_active = false
    obs.timer_remove(update_timer)
end

function reset_timer()
    stop_timer()
    current_session = 0
    countdown = work_duration
    is_break = false
    update_timer_display()
end

function update_timer()
    if countdown <= 0 then
        if is_break then
            countdown = work_duration
            is_break = false
            current_session = current_session + 1
            if current_session >= total_sessions then
                stop_timer()
                write_timer_status("Done!", "Break", "All sessions completed")
                return
            end
        else
            countdown = break_duration
            is_break = true
        end
    else
        countdown = countdown - 1
    end
    update_timer_display()
end

function update_timer_display()
    local minutes = math.floor(countdown / 60)
    local seconds = countdown % 60
    local time_text = string.format("%02d:%02d", minutes, seconds)
    local status_text = is_break and "Break" or "Work"
    local session_text = string.format("Session %d/%d", current_session + 1, total_sessions)
    write_timer_status(time_text, status_text, session_text)
end

function write_timer_status(time_text, status_text, session_text)
    local file = io.open(timer_file, "w")
    if file then
        file:write(time_text .. "\n")
        file:write(status_text .. "\n")
        file:write(session_text .. "\n")
        file:close()
    end
end
