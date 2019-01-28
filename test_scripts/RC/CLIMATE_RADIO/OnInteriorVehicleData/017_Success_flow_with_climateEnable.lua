---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0213-rc-radio-climate-parameter-update.md
-- Description:
-- Preconditions:
-- 1) SDL got RC.GetCapabilities for CLIMATE module with ("climateEnableAvailable" = true) parameter from HMI
-- 2) Mobile app subscribed on getting RC.OnInteriorVehicleData notification for CLIMATE module
-- In case:
-- 1) HMI sends RC.OnInteriorVehicleData notification ("climateEnable" = false) to SDL
-- 2) HMI sends RC.OnInteriorVehicleData notification ("climateEnable" = true) to SDL
-- SDL must:
-- 1) sends OnInteriorVehicleData notification ("climateEnable" = false) to Mobile
-- 2) sends OnInteriorVehicleData notification ("climateEnable" = true) to Mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local params = {
  false,
  true
}

--[[ Local Functions ]]
function commonRC.getAnotherModuleControlData(module_type)
  return commonRC.actualInteriorDataStateOnHMI[module_type]
end

local function updateActualInteriorDataStateOnHMI(isClimateEnable)
  commonRC.actualInteriorDataStateOnHMI.CLIMATE.climateControlData = {
    climateEnable = isClimateEnable
  }
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI", commonRC.registerAppWOPTU)
runner.Step("Activate App", commonRC.activateApp)
runner.Step("Subscribe app to module CLIMATE", commonRC.subscribeToModule, { "CLIMATE" })

runner.Title("Test")
for _, v in pairs(params) do
  runner.Step("updateActualInteriorDataStateOnHMI", updateActualInteriorDataStateOnHMI, { v })
  runner.Step("OnInteriorVehicleData climateEnable " .. tostring(v), commonRC.isSubscribed, { "CLIMATE" })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
