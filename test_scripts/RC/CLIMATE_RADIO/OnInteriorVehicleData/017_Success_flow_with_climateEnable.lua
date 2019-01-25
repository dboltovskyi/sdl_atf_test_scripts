---------------------------------------------------------------------------------------------------
-- User story:
-- Use case:
-- Item: Use Case 1: Main Flow
--
-- Requirement summary:
-- [SDL_RC] Current module status data GetInteriorVehicleData
--
-- Description:
-- Preconditions:
-- SDL got RC.GetCapabilities for CLIMATE module with ("climateEnableAvailable" = true) parameter from HMI
-- Mobile app is registered with SyncMsgVersion = 5.1
-- Mobile app subscribed on getting RC.OnInteriorVehicleData notification for CLIMATE module
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
local function onInteriorVehicleData(pParams)
  local paramsNotification = {
    moduleData = {
      moduleType = "CLIMATE",
      climateControlData = { climateEnable = pParams}
    }
  }
  commonRC.getHMIConnection():SendNotification("RC.OnInteriorVehicleData", paramsNotification)

  commonRC.getMobileSession():ExpectNotification("OnInteriorVehicleData", paramsNotification)
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
  runner.Step("OnInteriorVehicleData climateEnable " .. _, onInteriorVehicleData, { v })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
