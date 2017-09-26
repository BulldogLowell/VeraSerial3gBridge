module("L_ThreeGee1", package.seeall)

local SWITCHPOWER_SID = "urn:upnp-org:serviceId:SwitchPower1"
local SECURITY_SENSOR_SID = "urn:micasaverde-com:serviceId:SecuritySensor1"
local THREEGEE_SID = "urn:konektedplay-com:serviceId:ThreeGee1"
local THREEGEE_TYPE = "urn:schemas-konektedplay-com:device:ThreeGee:1"

local GATEWAY_TIMEOUT = 3
local PING_INTERVAL = 30
local PING_TIMEOUT = 120
local IP_ADDRESS = "google.com"
local POWER_CYCLE_INTERVAL = 900 -- 15 minutes between power cycles

local restartRetries = 0
local lastIpReminderTime = 0

function initializeVariables(device)
  assert(device ~= nil)
  logToVera("running initializeVariables")
  logToVera("initializing...")

  if (luup.variable_get(SECURITY_SENSOR_SID, "Tripped", device) == nil) then
    logToVera("initializing Tripped")
    luup.variable_set(SECURITY_SENSOR_SID, "Tripped", 0, device)
  end

  if (luup.variable_get(THREEGEE_SID, "LastUpdate", device) == nil) then
    logToVera("initializing LastUpdate")
    luup.variable_set(THREEGEE_SID, "LastUpdate", os.date("%c"), device)
  end

  if (luup.variable_get(SECURITY_SENSOR_SID, "Armed", device) == nil) then
    logToVera("initializing Armed")
    luup.variable_set(SECURITY_SENSOR_SID, "Armed", 0, device)
  end

  if (luup.variable_get(SECURITY_SENSOR_SID, "ArmedTripped", device) == nil) then
    logToVera("initializing ArmedTripped")
    luup.variable_set(SECURITY_SENSOR_SID, "ArmedTripped", 0, device)
  end

  if (luup.variable_get(THREEGEE_SID, "GatewayTimeout", device) == nil) then
    logToVera("initializing GatewayTimeout")
    luup.variable_set(THREEGEE_SID, "GatewayTimeout", GATEWAY_TIMEOUT, device)
  end

  if (luup.variable_get(THREEGEE_SID, "PingFrequency", device) == nil) then
    logToVera("initializing PingFrequency")
    luup.variable_set(THREEGEE_SID, "PingFrequency", PING_INTERVAL, device)
  end

  if (luup.variable_get(THREEGEE_SID, "PingTimeout", device) == nil) then
    logToVera("initializing PingTimeout")
    luup.variable_set(THREEGEE_SID, "PingTimeout", PING_TIMEOUT, device)
  end

  if (luup.variable_get(THREEGEE_SID, "IPAddress", device) == nil) then
    logToVera("initializing IPAddress")
    luup.variable_set(THREEGEE_SID, "IPAddress", IP_ADDRESS, device)
  end

  if (luup.variable_get(THREEGEE_SID, "InternetPing", device) == nil) then
    logToVera("initializing InternetPing")
    luup.variable_set(THREEGEE_SID, "InternetPing", 0, device)
  end

  if (luup.variable_get(THREEGEE_SID, "IpRepeatTries", device) == nil) then
    logToVera("initializing IpRepeatTries")
    luup.variable_set(THREEGEE_SID, "IpRepeatTries", 0, device)
  end

  if (luup.variable_get(THREEGEE_SID, "RouterDeviceID", device) == nil) then
    logToVera("initializing RouterDeviceID")
    luup.variable_set(THREEGEE_SID, "RouterDeviceID", 0, device)
  end

  restartRetries = luup.variable_get(THREEGEE_SID, "IpRepeatTries", device)
  logToVera("completed initializeVariables")
  return true
end

-- gateway detection
function pingGateway(device)
  logToVera("running pingGateway()")
  luup.io.write("PING:-1", tonumber(device))
  logToVera("getting LastUpdate timestamp")
  local value, timestamp = luup.variable_get(THREEGEE_SID, "LastUpdate", tonumber(device))
  if not timestamp then
    logToVera("error timestamp")
  else
    logToVera("timestamp: "..timestamp)
  end
  logToVera("getting current tripped state")
  local currentTrippedState = luup.variable_get(SECURITY_SENSOR_SID, "Tripped", tonumber(device))
  if not currentTrippedState then
    logToVera("error currentTrippedState")
  end
  logToVera("getting current PingTimeout")
  local pingTimeout = luup.variable_get(THREEGEE_SID, "PingTimeout", tonumber(device))
  if not pingTimeout then
    logToVera("error pingTimeout")
  else
    logToVera("pingTimeout: "..tonumber(pingTimeout))
  end
  if (os.time() - timestamp > tonumber(pingTimeout)) then
    logToVera("Gateway Sensor Is Tripped")
    if(currentTrippedState == "0") then
      logToVera("Setting to Tripped")
      luup.variable_set(SECURITY_SENSOR_SID, "Tripped", 1, tonumber(device))
    end
  else
    logToVera("Gateway Sensor Is Not Tripped")
    if(currentTrippedState == "1") then
      logToVera("setting to not tripped")
      luup.variable_set(SECURITY_SENSOR_SID, "Tripped", 0, tonumber(device))
    end
  end
end

-- Notifications for Loss of Internet
function ipCheckAndNotify(device)
  assert(device ~= nil)
  logToVera("running ipCheckAndNotify()")
  local routerID = luup.variable_get(THREEGEE_SID, "RouterDeviceID", device)
  local savedState, stateChangeTime = luup.variable_get(THREEGEE_SID, "InternetPing", device)
  local currentState = getPingState(device)
  logToVera("currentPingState: "..currentState)

  -- assert that the router's power is "ON"  this allows for 'manual' reset of router with the Vera UI
  if tonumber(routerID) ~= 0 then
    local currentSwitchStatus = luup.variable_get(SWITCHPOWER_SID, "Status", tonumber(routerID))
    if (currentSwitchStatus == "0") then
      luup.call_action(SWITCHPOWER_SID, "SetTarget", {newTargetValue="1"}, tonumber(routerID))
      logToVera("Restoring Router Power"..routerID)
    end
  else
    logToVera("No Router Device Number Selected")
  end

  -- look for state change
  if (currentState ~= tostring(savedState)) then
    if currentState == "0" then  -- immediately indicate connected, zero is success
      luup.variable_set(THREEGEE_SID, "InternetPing", currentState, tonumber(device))
      logToVera("IP Sensor State Change, new state = CONNECTED")
      threeGeeNotify(device, "Internet Restored")
      restartRetries = luup.variable_get(THREEGEE_SID, "IpRepeatTries", tonumber(device))
    else  -- or wait PingTimeout to switch to Not Connected
      local timeout = luup.variable_get(THREEGEE_SID, "PingTimeout", device)
      if (os.time() - stateChangeTime) >= tonumber(timeout) then
        luup.variable_set(THREEGEE_SID, "InternetPing", currentState, tonumber(device))
        logToVera("IP Sensor State Change, new state = NOT CONNECTED")
        threeGeeNotify(device, "Internet Not Connected")
        lastIpReminderTime = os.time()
      end
    end
  else -- Attempt to reset router if persistent loss of internet
    if tostring(savedState) == "1" then
      if tonumber(routerID) ~= 0 then
        if tonumber(restartRetries) > 0 then
          if  os.time() - lastIpReminderTime >= POWER_CYCLE_INTERVAL then
            restartRetries = restartRetries - 1
            lastIpReminderTime = os.time()
            logToVera("Initiating Power Cycle")
            local mssg = "Power-Cycling Router-"..restartRetries
            threeGeeNotify(device, mssg)
            luup.call_action(SWITCHPOWER_SID, "SetTarget", {newTargetValue="0"}, tonumber(routerID))
          end
        end
      end
    end
  end
end

function getPingState(device)
  assert(device ~= nil)
  logToVera("running getPingState()")
  local ipAddress = luup.variable_get(THREEGEE_SID, "IPAddress", device)
  logToVera("Pinging IP address: "..ipAddress)
  local success = os.execute("ping -c 1 -W 1 " .. ipAddress)
	if (success == 0) then
    logToVera("IP Ping Success...")
    return "0"
  end
  logToVera("IP Ping FAILED!")
  return "1"
end

function setPingFrequency(device, newFrequency)
  assert(device ~= nil)
  logToVera("Setting Ping Frequency with interval:"..newFrequency)
  luup.variable_set(THREEGEE_SID, "PingFrequency", newFrequency, device)
  luup.variable_set(THREEGEE_SID, "Received", "Ping Frequency:"..newFrequency.."seconds", device)
end

function setPingTimeout(device, newTimeout)
  assert(device ~= nil)
  logToVera("Setting Ping Timeout with interval:"..newTimeout)
  luup.variable_set(THREEGEE_SID, "PingTimeout", newTimeout, device)
  luup.variable_set(THREEGEE_SID, "Received", "Ping Timeout:"..newTimeout.."seconds", device)
end

function setIpRepeatTries(device, tries)
  assert(device ~= nil)
  logToVera("Setting IP Repeat Tries to:"..tries)
  luup.variable_set(THREEGEE_SID, "IpRepeatTries", tries, device)
  luup.variable_set(THREEGEE_SID, "Received", "Restart Attempts:"..tries.." tries", device)
  restartRetries = luup.variable_get(THREEGEE_SID, "IpRepeatTries", device)
end

function setRouterDeviceID(device, routerID)
  assert(device ~= nil)
  logToVera("Setting Router Target Device to: "..routerID)
  --if (luup.variable.get(SWITCHPOWER_SID, "Target", routerID) == nil) then
  if luup.device_supports_service(SWITCHPOWER_SID, routerID) or tonumber(routerID) == 0 then
    logToVera("Setting RouterDeviceID to:"..routerID)
    luup.variable_set(THREEGEE_SID, "RouterDeviceID", tonumber(routerID), device)
    luup.variable_set(THREEGEE_SID, "Received", "Router Device:"..routerID, device)
  else
    logToVera("Device"..routerID.."is not a Switch")
    luup.variable_set(THREEGEE_SID, "Received", "Device not a switch", device)
  end
end

function setIPAddress(device, newIP)
  assert(device ~= nil)
  logToVera("Setting IP Address:"..newIP)
  luup.variable_set(THREEGEE_SID, "IPAddress", newIP, device)
  luup.variable_set(THREEGEE_SID, "Received", "IP/Domain:"..newIP, device)
end


function setGatewayTimeout(device, newInterval)
  assert(device ~= nil)
  logToVera("Setting Gateway Timeout with interval:"..newInterval)
  luup.io.write("GWTO:"..newInterval);
  luup.variable_set(THREEGEE_SID, "GatewayTimeout", newInterval, device)
end

local function getVarNumeric( name, dflt, device, serviceId )
    --if serviceId == nil then serviceId = MYSID end
    local s = luup.variable_get(serviceId, name, device)
    if (s == nil or s == "") then return dflt end
    s = tonumber(s, 10)
    if (s == nil) then return dflt end
    return s
end

local function isTripped(device)
    assert(device ~= nil)
    local tripped = getVarNumeric("Tripped", 0, device, SECURITY_SENSOR_SID)
    return tripped ~= 0
end

local function isArmed(device)
    assert(device ~= nil)
    local armed = getVarNumeric("Armed", 0, device, SECURITY_SENSOR_SID)
    return armed ~= 0
end

function arm(device)
	assert(device ~= nil)
    logToVera("Arming ThreeGee1 device:"..device)
    if not isArmed(device) then
    	luup.variable_set(SECURITY_SENSOR_SID, "Armed", "1", device)
      logToVera("Armed ThreeGee1 device")
    	if isTripped(device) then
        luup.variable_set(SECURITY_SENSOR_SID, "ArmedTripped", "1", device)
      end
    end
end

function disarm(device)
	assert(device ~= nil)
	logToVera("Disarming ThreeGee1 device:"..device)
	if isArmed(device) then

    luup.variable_set(SECURITY_SENSOR_SID, "Armed", "0", device)
    logToVera("Disarmed ThreeGee1 device")
  end
  luup.variable_set(SECURITY_SENSOR_SID, "ArmedTripped", "0", device)
end

function threeGeeNotify(device, message)
  luup.io.write("MSSG:"..message, tonumber(device))
end

function logToVera(mssg)
  local message = "ThreeGee1: "..mssg
  luup.log(message)
end
