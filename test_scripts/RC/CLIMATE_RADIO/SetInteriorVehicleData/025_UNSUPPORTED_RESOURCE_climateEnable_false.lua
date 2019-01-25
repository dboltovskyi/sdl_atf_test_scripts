---------------------------------------------------------------------------------------------------
-- Proposal:
-- User story: TBD
--
-- Requirement summary:
-- TBD
--
-- Description:
-- Preconditions:
-- Mobile app is registered with SyncMsgVersion = 5.1
-- SDL got RC.GetCapabilities for CLIMATE module  with new ("climateEnableAvailable" = false) parameter from HMI
-- In case:
-- 1) Mobile app send SetInteriorVehicleData with parameter ("climateEnable" = false) to SDL
-- SDL must:
-- 1) rejects with ("resultCode" = UNSUPPORTED_RESOURCE)
-- 2) not send RC.SetInteriorVehicleData to HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')
local hmi_values = require("user_modules/hmi_values")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local hmiValues = hmi_values.getDefaultHMITable()
hmiValues.RC.GetCapabilities.params.remoteControlCapability.climateControlCapabilities[1].climateEnable = false

--[[ Local Functions ]]
function commonRC.getModuleControlData(module_type)
  local out = { moduleType = module_type }
  if module_type == "CLIMATE" then
    out.climateControlData = {
      climateEnable = true
    }
  end
  return out
end

commonRC.actualInteriorDataStateOnHMI = {CLIMATE = commonRC.cloneTable(commonRC.getModuleControlData("CLIMATE"))}

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start, { hmiValues })
runner.Step("RAI", commonRC.registerAppWOPTU)
runner.Step("Activate App", commonRC.activateApp)

runner.Title("Test")

runner.Step("SetInteriorVehicleData UNSUPPORTED_RESOURCE in case climateEnable false", commonRC.rpcDenied,
  {"CLIMATE", 1, "SetInteriorVehicleData", "UNSUPPORTED_RESOURCE"})

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
