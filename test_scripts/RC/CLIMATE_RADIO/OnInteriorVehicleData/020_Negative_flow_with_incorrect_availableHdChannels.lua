---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/4
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/subscription_on_module_status_change_notification.md
-- Item: Use Case 1: Main Flow
--
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/5
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/unsubscribe_from_module_status_change_notification.md
-- Item: Use Case 1: Main Flow
--
-- Requirement summary:
-- [SDL_RC] Subscribe on RC module change notification
--
-- Description: TRS: GetInteriorVehicleData, #4
-- In case:
-- 1) RC app sends valid and allowed-by-policies GetInteriorVehicleData request with "subscribe:true" parameter
-- 2) and SDL received GetInteriorVehicleData response with "isSubscribed: true", "resultCode: SUCCESS" from HMI
-- 3) and then SDL received OnInteriorVehicleData notification
-- SDL must:
-- 1) Internally subscribe this application for requested <moduleType_value>
-- 2) Transfer GetInteriorVehicleData response with "isSubscribed: true", "resultCode: SUCCESS", "success:true" to the related app
-- 3) Re-send OnInteriorVehicleData notification to the related app
--
-- [SDL_RC] Unsubscribe from RC module change notifications
--
-- Description: TRS: GetInteriorVehicleData, #8
-- In case:
-- 1) RC app is subscribed to "<moduleType_value>"
-- 2) RC app sends valid and allowed-by-policies GetInteriorVehicleData request with "subscribe:false" parameter
-- 3) and SDL received GetInteriorVehicleData response with "isSubscribed: false", "resultCode: SUCCESS" from HMI
-- 4) and then SDL received OnInteriorVehicleData notification
-- SDL must:
-- 1) Internally un-subscribe this application for requested <moduleType_value>
-- 2) Transfer GetInteriorVehicleData response with "isSubscribed: false", "resultCode: SUCCESS", "success:true" to the related app
-- 3) Does not re-send OnInteriorVehicleData notification  to the related app
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local params = {
  {0,1, 2, 3, 7,8},
  {-1,0,1, 2, 3, 4},
  "Z",
  {0,1, 2, 3, 4, 'a', 'b'}
--  {0, 0, 0, 0, 0, 0, 0, 0}     //  OnInteriorVehicleData notification: Times: The most allowed occurences boundary exceed
}

--[[ Local Functions ]]
function commonRC.getAnotherModuleControlData(module_type)
  return commonRC.actualInteriorDataStateOnHMI[module_type]
end

local function updateActualInteriorDataStateOnHMI(pParam)
  commonRC.actualInteriorDataStateOnHMI.RADIO.radioControlData = {
    availableHdChannels = pParam
  }
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI", commonRC.registerAppWOPTU)
runner.Step("Activate App", commonRC.activateApp)
runner.Step("Subscribe app to module RADIO", commonRC.subscribeToModule, { "RADIO" })

runner.Title("Test")
for k, v in pairs(params) do
  runner.Step("updateActualInteriorDataStateOnHMI", updateActualInteriorDataStateOnHMI, { v })
  runner.Step("OnInteriorVehicleData incorrect availableHdChannels values" , commonRC.isUnsubscribed, { "RADIO" })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
