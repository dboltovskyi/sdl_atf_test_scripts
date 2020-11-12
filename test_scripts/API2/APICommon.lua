----------------------------------------------------------------------------------------------------
-- API Common module
----------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local actions = require("user_modules/sequences/actions")
local runner = require('user_modules/script_runner')
local utils = require("user_modules/utils")

--[[ General configuration parameters ]]
runner.testSettings.isSelfIncluded = false
config.defaultProtocolVersion = 2

--[[ Module ]] -------------------------------------------------------------------------------------
local m = {}

--[[ Common Proxy Functions ]]
do
  m.Title = runner.Title
  m.Step = runner.Step
  m.getPreloadedPT = actions.sdl.getPreloadedPT
  m.setPreloadedPT = actions.sdl.setPreloadedPT
  m.registerApp = actions.app.register
  m.registerAppWOPTU = actions.app.registerNoPTU
  m.activateApp = actions.app.activate
  m.getMobileSession = actions.getMobileSession
  m.getHMIConnection = actions.hmi.getConnection
  m.cloneTable = utils.cloneTable
  m.printTable = utils.printTable
  m.start = actions.start
  m.postconditions = actions.postconditions
  m.wait = utils.wait
  m.spairs = utils.spairs
  m.cprint = utils.cprint
  m.json = actions.json
  m.getHMIAppId = actions.getHMIAppId
end

--[[ Constants ]] ----------------------------------------------------------------------------------
m.vd = {
  vin = "",
  gps = "VEHICLEDATA_GPS",
  speed = "VEHICLEDATA_SPEED",
  rpm = "VEHICLEDATA_RPM",
  fuelLevel = "VEHICLEDATA_FUELLEVEL",
  fuelLevel_State = "VEHICLEDATA_FUELLEVEL_STATE",
  instantFuelConsumption = "VEHICLEDATA_FUELCONSUMPTION",
  externalTemperature = "VEHICLEDATA_EXTERNTEMP",
  prndl = "VEHICLEDATA_PRNDL",
  tirePressure = "VEHICLEDATA_TIREPRESSURE",
  odometer = "VEHICLEDATA_ODOMETER",
  beltStatus = "VEHICLEDATA_BELTSTATUS",
  bodyInformation = "VEHICLEDATA_BODYINFO",
  deviceStatus = "VEHICLEDATA_DEVICESTATUS",
  eCallInfo = "VEHICLEDATA_ECALLINFO",
  airbagStatus = "VEHICLEDATA_AIRBAGSTATUS",
  emergencyEvent = "VEHICLEDATA_EMERGENCYEVENT",
  -- clusterModeStatus = "VEHICLEDATA_CLUSTERMODESTATUS", -- disabled due to issue: https://github.com/smartdevicelink/sdl_core/issues/3460
  myKey = "VEHICLEDATA_MYKEY",
  driverBraking = "VEHICLEDATA_BRAKING",
  wiperStatus = "VEHICLEDATA_WIPERSTATUS",
  headLampStatus = "VEHICLEDATA_HEADLAMPSTATUS",
  engineTorque = "VEHICLEDATA_ENGINETORQUE",
  accPedalPosition = "VEHICLEDATA_ACCPEDAL",
  steeringWheelAngle = "VEHICLEDATA_STEERINGWHEEL",
  turnSignal = "VEHICLEDATA_TURNSIGNAL",
  fuelRange = "VEHICLEDATA_FUELRANGE",
  engineOilLife = "VEHICLEDATA_ENGINEOILLIFE",
  electronicParkBrakeStatus = "VEHICLEDATA_ELECTRONICPARKBRAKESTATUS",
  cloudAppVehicleID = "VEHICLEDATA_CLOUDAPPVEHICLEID",
  handsOffSteering = "VEHICLEDATA_HANDSOFFSTEERING",
  stabilityControlsStatus = "VEHICLEDATA_STABILITYCONTROLSSTATUS",
  gearStatus = "VEHICLEDATA_GEARSTATUS",
  windowStatus = "VEHICLEDATA_WINDOWSTATUS"
}

-- [[ Functions ]] ---------------------------------------------------------------------------------
local function updatePreloadedPTFile(pGroup)
  local params = { }
  for param in pairs(m.vd) do
    table.insert(params, param)
  end
  local rpcs = { "GetVehicleData", "OnVehicleData", "SubscribeVehicleData", "UnsubscribeVehicleData" }
  local levels = { "NONE", "BACKGROUND", "LIMITED", "FULL" }
  local pt = actions.sdl.getPreloadedPT()
  if not pGroup then
    pGroup = {
      rpcs = {}
    }
    for _, rpc in pairs(rpcs) do
      pGroup.rpcs[rpc] = {
        hmi_levels = levels,
        parameters = params
      }
    end
  end
  pt.policy_table.functional_groupings["VDGroup"] = pGroup
  pt.policy_table.app_policies["default"].groups = { "Base-4", "VDGroup" }
  pt.policy_table.functional_groupings["DataConsent-2"].rpcs = m.json.null
  actions.sdl.setPreloadedPT(pt)
end

function m.preconditions(pGroup)
  actions.preconditions()
  updatePreloadedPTFile(pGroup)
end

function m.getTableSize(pTbl)
  local out = 0
  for _ in pairs(pTbl) do
    out = out + 1
  end
  return out
end

function m.tableContains(pTbl, pValue)
  for _, v in pairs(pTbl) do
    if v == pValue then return true end
  end
  return false
end

function m.splitString(pStr, pDelimiter)
  local result = {}
  for match in (pStr .. pDelimiter):gmatch("(.-)%" .. pDelimiter) do
    table.insert(result, match)
  end
  return result
end

function m.getKeyByValue(pTbl, pValue)
  for k, v in pairs(pTbl) do
    if v == pValue then return k end
  end
end

return m
