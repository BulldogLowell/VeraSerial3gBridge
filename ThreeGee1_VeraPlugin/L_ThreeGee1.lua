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

local pingArray = {}
local MAX_ARRAY_SIZE = 60

local internetLostRetries = 0
local lastIpReminderTime = os.time()

function initializeVariables(device)
  assert(device ~= nil)
  luup.log("ThreeGee1: running initializeVariables")
  luup.log("ThreeGee1: initializing...")

  if (luup.variable_get(SECURITY_SENSOR_SID, "Tripped", device) == nil) then
    luup.log("ThreeGee1: initializing Tripped")
    luup.variable_set(SECURITY_SENSOR_SID, "Tripped", 0, device)
  end

  if (luup.variable_get(THREEGEE_SID, "LastUpdate", device) == nil) then
    luup.log("ThreeGee1: initializing LastUpdate")
    luup.variable_set(THREEGEE_SID, "LastUpdate", os.date("%c"), device)
  end

  if (luup.variable_get(SECURITY_SENSOR_SID, "Armed", device) == nil) then
    luup.log("ThreeGee1: initializing Armed")
    luup.variable_set(SECURITY_SENSOR_SID, "Armed", 0, device)
  end

  if (luup.variable_get(SECURITY_SENSOR_SID, "ArmedTripped", device) == nil) then
    luup.log("ThreeGee1: initializing ArmedTripped")
    luup.variable_set(SECURITY_SENSOR_SID, "ArmedTripped", 0, device)
  end

  if (luup.variable_get(THREEGEE_SID, "GatewayTimeout", device) == nil) then
    luup.log("ThreeGee1: initializing GatewayTimeout")
    luup.variable_set(THREEGEE_SID, "GatewayTimeout", GATEWAY_TIMEOUT, device)
  end

  if (luup.variable_get(THREEGEE_SID, "PingFrequency", device) == nil) then
    luup.log("ThreeGee1: initializing PingFrequency")
    luup.variable_set(THREEGEE_SID, "PingFrequency", PING_INTERVAL, device)
  end

  if (luup.variable_get(THREEGEE_SID, "PingTimeout", device) == nil) then
    luup.log("ThreeGee1: initializing PingTimeout")
    luup.variable_set(THREEGEE_SID, "PingTimeout", PING_TIMEOUT, device)
  end

  if (luup.variable_get(THREEGEE_SID, "IPAddress", device) == nil) then
    luup.log("ThreeGee1: initializing IPAddress")
    luup.variable_set(THREEGEE_SID, "IPAddress", IP_ADDRESS, device)
  end

  if (luup.variable_get(THREEGEE_SID, "InternetPing", device) == nil) then
    luup.log("ThreeGee1: initializing InternetPing")
    luup.variable_set(THREEGEE_SID, "InternetPing", 0, device)
  end

  if (luup.variable_get(THREEGEE_SID, "IpRepeatTries", device) == nil) then
    luup.log("ThreeGee1: initializing IpRepeatTries")
    luup.variable_set(THREEGEE_SID, "IpRepeatTries", 0, device)
  end

  if (luup.variable_get(THREEGEE_SID, "RouterDeviceID", device) == nil) then
    luup.log("ThreeGee1: initializing RouterDeviceID")
    luup.variable_set(THREEGEE_SID, "RouterDeviceID", 0, device)
  end

  local pingCount = math.floor(luup.variable_get(THREEGEE_SID, "PingTimeout", device) / luup.variable_get(THREEGEE_SID, "PingFrequency", device)) or 1
  if pingCount > MAX_ARRAY_SIZE then
    pingCount = MAX_ARRAY_SIZE
  end
  luup.log("ThreeGee1: initialized pingCount to:"..tostring(pingCount))
  local storedValue = luup.variable_get(THREEGEE_SID, "InternetPing", device)
  for i = 1, pingCount do
    pingArray[i] = storedValue
  end
  for i = 1, table.getn(pingArray) do
    luup.log("ThreeGee1: Ping Array Value:"..tostring(i).." "..(pingArray[i]))
  end

  internetLostRetries = luup.variable_get(THREEGEE_SID, "IpRepeatTries", device)

  luup.log("ThreeGee1: completed initializeVariables")
  return true
end

-- gateway detection
function pingGateway(device)
  luup.log("ThreeGee1: running pingGateway()")
  luup.io.write("PING:-1", tonumber(device))
  luup.log("ThreeGee1: getting LastUpdate timestamp")
  local value, timestamp = luup.variable_get("urn:konektedplay-com:serviceId:ThreeGee1", "LastUpdate", tonumber(device))
  if not timestamp then
    luup.log("ThreeGee1: error timestamp")
  else
    luup.log("ThreeGee1: timestamp: "..timestamp)
  end
  luup.log("ThreeGee1: getting current tripped state")
  local currentTrippedState = luup.variable_get("urn:micasaverde-com:serviceId:SecuritySensor1", "Tripped", tonumber(device))
  if not currentTrippedState then
    luup.log("ThreeGee1: error currentTrippedState")
  end
  luup.log("ThreeGee1: getting current PingTimeout")
  local pingTimeout = luup.variable_get("urn:konektedplay-com:serviceId:ThreeGee1", "PingTimeout", tonumber(device))
  if not pingTimeout then
    luup.log("ThreeGee1: error pingTimeout")
  else
    luup.log("ThreeGee1: pingTimeout: "..tonumber(pingTimeout))
  end
  luup.log("ThreeGee1: checking...")
  luup.log("ThreeGee1: os.time:"..os.time())
  luup.log("ThreeGee1: timestamp:"..tonumber(timestamp))
  luup.log("ThreeGee1: pingTimeout:"..tonumber(pingTimeout))
  if (os.time() - timestamp > tonumber(pingTimeout)) then
    luup.log("ThreeGee1:  Gateway Sensor Is Tripped")
    if(currentTrippedState == "0") then
      luup.log("ThreeGee1: Setting to Tripped")
      luup.variable_set("urn:micasaverde-com:serviceId:SecuritySensor1", "Tripped", 1, tonumber(device))
    end
  else
    luup.log("ThreeGee1: Gateway Sensor Is Not Tripped")
    if(currentTrippedState == "1") then
      luup.log("ThreeGee1: setting to not tripped")
      luup.variable_set("urn:micasaverde-com:serviceId:SecuritySensor1", "Tripped", 0, tonumber(device))
    end
  end
end

-- Notifications for Loss of Internet
function ipCheckAndNotify(device)
  assert(device ~= nil)
  luup.log("ThreeGee1: running ipCheckAndNotify()")
  local routerID = luup.variable_get(THREEGEE_SID, "RouterDeviceID", device)

  -- assert that the router's power is "ON"  this allows for 'manual' reset of router with the Vera UI

  if tonumber(routerID) ~= 0 then
    local currentSwitchStatus = luup.variable_get(SWITCHPOWER_SID, "Status", tonumber(routerID))
    if (currentSwitchStatus == "0") then
      threeGeeNotify(device, "Restoring Router Power")
      luup.call_action(SWITCHPOWER_SID, "SetTarget", {newTargetValue="1"}, tonumber(routerID))
      luup.log("ThreeGee1: Restoring Router Power"..routerID)
    end
  else
    luup.log("ThreeGee1: No Router Device Number Selected")
  end


  local currentState = getPingState(device)
  luup.log("ThreeGee1: currentPingState: "..currentState)

  table.remove(pingArray, table.getn(pingArray))
  table.insert(pingArray, 1, currentState)

  for i = 1, table.getn(pingArray) do
    luup.log("ThreeGee1: Ping Array Value:"..tostring(i).."->"..(pingArray[i]))
  end

  local savedState, stateChangeTime = luup.variable_get("urn:konektedplay-com:serviceId:ThreeGee1", "InternetPing", device)

  -- look for state change
  if (currentState ~= tostring(savedState)) then
    if currentState == "0" then  -- immediately indicate connected, zero is success
      luup.variable_set("urn:konektedplay-com:serviceId:ThreeGee1", "InternetPing", tonumber(currentState), tonumber(device))
      luup.log("ThreeGee1: IP Sensor State Change, new state = CONNECTED")
      threeGeeNotify(device, "Internet Restored")
      internetLostRetries = luup.variable_get(THREEGEE_SID, "IpRepeatTries", device)
    else
      if getTrailingState() == "1" then  -- wait PingTimeout to indicate not connected
        luup.variable_set("urn:konektedplay-com:serviceId:ThreeGee1", "InternetPing", tonumber(currentState), tonumber(device))
        luup.log("ThreeGee1: IP Sensor State Change, new state = NOT CONNECTED")
        threeGeeNotify(device, "Internet Not Connected")
        lastIpReminderTime = os.time()
      end
    end
  end

  -- Attempt to reset router if persistent loss of internet
  if tostring(savedState) == "1" then
    if tonumber(routerID) ~= 0 then
      if os.time() - lastIpReminderTime >= POWER_CYCLE_INTERVAL then
        if internetLostRetries > 0 then
          internetLostRetries = internetLostRetries - 1
          lastIpReminderTime = os.time()
          luup.log("ThreeGee1: Initiating Power Cycle")
          local mssg = "Power-Cycling Router-"..internetLostRetries
          threeGeeNotify(device, mssg)
          luup.call_action(SWITCHPOWER_SID, "SetTarget", {newTargetValue="0"}, tonumber(routerID))
        end
      end
    end
  end

end

function getPingState(device)
  assert(device ~= nil)
  luup.log("ThreeGee1: running getPingState()")
  local ipAddress = luup.variable_get("urn:konektedplay-com:serviceId:ThreeGee1", "IPAddress", device)
  luup.log("ThreeGee1: Pinging IP address: "..ipAddress)
  local success = os.execute("ping -c 1 -W 1 " .. ipAddress)
	if (success == 0) then
    luup.log("ThreeGee1: IP Ping Success...")
    return "0"
  end
  luup.log("ThreeGee1: IP Ping FAILED!")
  return "1"
end

function setPingFrequency(device, newFrequency)
  assert(device ~= nil)
  luup.log("ThreeGee1: Setting Ping Frequency with interval:"..newFrequency)
  luup.variable_set(THREEGEE_SID, "PingFrequency", newFrequency, device)
  luup.variable_set("urn:konektedplay-com:serviceId:ThreeGee1", "Received", "Ping Frequency:"..newFrequency.."seconds", device)
  local timeout = luup.variable_get(THREEGEE_SID, "PingTimeout", device)
  local pingCount = math.floor(timeout / newFrequency) or 1
  if pingCount > MAX_ARRAY_SIZE then
    pingCount = MAX_ARRAY_SIZE
  end
  luup.log("ThreeGee1: newPingCount:"..pingCount)
  for i = 1, getMax(pingCount, table.getn(pingArray)) do
    if i <= pingCount then
      pingArray[i] = "0"
    else
      pingArray[i] = nil
    end
  end
  luup.log("ThreeGee1: newPingArrayLength: "..table.getn(pingArray))
end

function setPingTimeout(device, newTimeout)
  assert(device ~= nil)
  luup.log("ThreeGee1: Setting Ping Timeout with interval:"..newTimeout)
  luup.variable_set(THREEGEE_SID, "PingTimeout", newTimeout, device)
  luup.variable_set("urn:konektedplay-com:serviceId:ThreeGee1", "Received", "Ping Timeout:"..newTimeout.."seconds", device)
  local freq = luup.variable_get(THREEGEE_SID, "PingFrequency", device)
  local pingCount = math.floor(newTimeout / freq) or 1
  if pingCount > MAX_ARRAY_SIZE then
    pingCount = MAX_ARRAY_SIZE
  end
  luup.log("ThreeGee1: newPingCount:"..pingCount)
  for i = 1, getMax(pingCount, table.getn(pingArray)) do
    if i <= pingCount then
      pingArray[i] = "0"
    else
      pingArray[i] = nil
    end
  end
  luup.log("ThreeGee1: newPingArrayLength: "..table.getn(pingArray))
end

function setIpRepeatTries(device, tries)
  assert(device ~= nil)
  luup.log("ThreeGee1: Setting IP Repeat Tries to:"..tries)
  luup.variable_set(THREEGEE_SID, "IpRepeatTries", tries, device)
  luup.variable_set("urn:konektedplay-com:serviceId:ThreeGee1", "Received", "Restart Attempts:"..tries.." tries", device)
  internetLostRetries = luup.variable_get(THREEGEE_SID, "IpRepeatTries", device)
end

function setRouterDeviceID(device, routerID)
  assert(device ~= nil)
  luup.log("ThreeGee1: Setting Router Target Device to: "..routerID)
  --if (luup.variable.get(SWITCHPOWER_SID, "Target", routerID) == nil) then
  if luup.device_supports_service(SWITCHPOWER_SID, routerID) or tonumber(routerID) == 0 then
    luup.log("ThreeGee1: Setting RouterDeviceID to:"..routerID)
    luup.variable_set(THREEGEE_SID, "RouterDeviceID", tonumber(routerID), device)
    luup.variable_set("urn:konektedplay-com:serviceId:ThreeGee1", "Received", "Router Device:"..routerID, device)
  else
    luup.log("ThreeGee1: Device"..routerID.."is not a Switch")
    luup.variable_set("urn:konektedplay-com:serviceId:ThreeGee1", "Received", "Device not a switch", device)
  end
end

function getMax(pingCount, arraySize)
  if arraySize > pingCount then
    return arraySize;
  else
    return pingCount
  end
end

function getTrailingState()
  luup.log("ThreeGee1: running getTrailingState()")
  for i = 1, (table.getn(pingArray)) do
    if pingArray[i] == "0" then
      luup.log("ThreeGee1: trailingState = 0")
      return "0";
    end
  end
  luup.log("ThreeGee1: trailingState = 1")
  return "1"
end


function setIPAddress(device, newIP)
  assert(device ~= nil)
  luup.log("ThreeGee1: Setting IP Address:"..newIP)
  luup.variable_set(THREEGEE_SID, "IPAddress", newIP, device)
  luup.variable_set("urn:konektedplay-com:serviceId:ThreeGee1", "Received", "IP/Domain:"..newIP, device)
end


function setGatewayTimeout(device, newInterval)
  assert(device ~= nil)
  luup.log("ThreeGee1: Setting Gateway Timeout with interval:"..newInterval)
  luup.io.write("GWTO:"..newInterval);
  luup.variable_set(THREEGEE_ID, "GatewayTimeout", newInterval, device)
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
    luup.log("ThreeGee1: Arming ThreeGee1 device:"..device)
    if not isArmed(device) then
    	luup.variable_set(SECURITY_SENSOR_SID, "Armed", "1", device)
      luup.log("ThreeGee1: Armed ThreeGee1 device")
    	if isTripped(device) then
        luup.variable_set(SECURITY_SENSOR_SID, "ArmedTripped", "1", device)
      end
    end
end

function disarm(device)
	assert(device ~= nil)
	luup.log("ThreeGee1: Disarming ThreeGee1 device:"..device)
	if isArmed(device) then

    luup.variable_set(SECURITY_SENSOR_SID, "Armed", "0", device)
    luup.log("ThreeGee1: Disarmed ThreeGee1 device")
  end
  luup.variable_set(SECURITY_SENSOR_SID, "ArmedTripped", "0", device)
end

function threeGeeNotify(device, message)
  luup.io.write("MSSG:"..message, tonumber(device))
end
