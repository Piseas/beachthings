-- Required libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"
local preferences = require "preferences"

-- Dew point calculation function
local function calculate_dew_point(temp, humidity, is_fahrenheit)
  -- Constants for Magnus formula
  local a = 17.27
  local b = 237.7

  -- Convert Fahrenheit to Celsius if necessary
  local temp_c = is_fahrenheit and ((temp - 32) * 5 / 9) or temp

  -- Calculate dew point using Magnus-Tetens approximation
  local alpha = (a * temp_c) / (b + temp_c) + math.log(humidity / 100)
  local dew_point_c = (b * alpha) / (a - alpha)

  -- Convert back to Fahrenheit if needed
  return is_fahrenheit and (dew_point_c * 9 / 5 + 32) or dew_point_c
end

-- Device event handler for temperature and humidity updates
local function handle_sensor_event(driver, device, event)
  local temp = device:get_latest_state("main", capabilities.temperatureMeasurement.ID, "temperature")
  local humidity = device:get_latest_state("main", capabilities.relativeHumidityMeasurement.ID, "humidity")

  if temp and humidity then
    -- Fetch user-defined preference for temperature unit
    local is_temp_fahrenheit = device.preferences.is_fahrenheit

    local dew_point = calculate_dew_point(temp.value, humidity.value, is_temp_fahrenheit)

    log.info(string.format("Temperature: %.2f%s, Humidity: %.2f%%, Dew Point: %.2f%s",
      temp.value, is_temp_fahrenheit and "°F" or "°C",
      humidity.value,
      dew_point, is_temp_fahrenheit and "°F" or "°C"))

    -- Check if dew point is reached and send an alert
    if temp.value <= dew_point then
      device:emit_event(capabilities.notificationSensor.notification("Dew point reached!"))
    end
  end
end

-- Driver definition
local dew_point_driver = Driver("dew_point_monitor", {
  discovery = function(driver, opts, callback, ...)
    log.info("Device discovery started...")
    -- Logic to discover the physical sensor device (optional)
  end,
  lifecycle_handlers = {
    init = function(driver, device)
      log.info("Device initialized: " .. device.device_network_id)
    end,
    added = function(driver, device)
      log.info("Device added: " .. device.device_network_id)
      device:emit_event(capabilities.notificationSensor.notification("Ready to monitor dew point"))
    end
  },
  capability_handlers = {
    [capabilities.temperatureMeasurement.ID] = {
      [capabilities.temperatureMeasurement.commands.get.NAME] = handle_sensor_event,
    },
    [capabilities.relativeHumidityMeasurement.ID] = {
      [capabilities.relativeHumidityMeasurement.commands.get.NAME] = handle_sensor_event,
    },
  }
})

-- Add preferences (user-defined settings)
dew_point_driver.supported_capabilities = {
  capabilities.temperatureMeasurement,
  capabilities.relativeHumidityMeasurement,
  capabilities.notificationSensor
}

dew_point_driver.preferences = {
  is_fahrenheit = {
    name = "Temperature Unit",
    description = "Select temperature unit (Fahrenheit or Celsius)",
    type = "boolean", -- True for Fahrenheit, False for Celsius
    default = true -- Default is Fahrenheit
  }
}

-- Run the driver
dew_point_driver:run()