---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0213-rc-radio-climate-parameter-update.md
-- Description:
-- Preconditions:
-- 1) SDL got RC.GetCapabilities("climateEnableAvailable" = true) for CLIMATE module parameter from HMI
-- In case:
-- 1) Mobile app sends SetInteriorVehicleData with parameter ("climateEnable" = false) to SDL
-- 2) HMI sends response RC.SetInteriorVehicleData ("climateEnable" = false)
-- SDL must:
-- 1) sends RC.SetInteriorVehicleData (CLIMATE ("climateEnable" = false)) to HMI
-- 2) send SetInteriorVehicleData  with ("resultCode" = SUCCESS) to Mobile
-- In case:
-- 1) Mobile app sends SetInteriorVehicleData  request parameter ("climateEnable" = true) to SDL
-- 2) HMI sends RC.SetInteriorVehicleData response ("climateEnable" = true)
-- SDL must:
-- 1) sends RC.SetInteriorVehicleData request (CLIMATE ("climateEnable" = true)) to HMI
-- 2) sends SetInteriorVehicleData response with ("resultCode" = SUCCESS) to Mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

local params = {
  8, -1, "0"
}

--[[ Local Functions ]]
function commonRC.getModuleControlData(module_type)
  return commonRC.actualInteriorDataStateOnHMI[module_type]
end

local function updateActualInteriorDataStateOnHMI(pParam)
  commonRC.actualInteriorDataStateOnHMI.RADIO.radioControlData = {
    hdChannel = pParam
  }
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI", commonRC.registerAppWOPTU)
runner.Step("Activate App", commonRC.activateApp)

runner.Title("Test")
for _, v in pairs(params) do
  runner.Step("updateActualInteriorDataStateOnHMI", updateActualInteriorDataStateOnHMI, { v })
  runner.Step("SetInteriorVehicleData set incorrect values for hdChannels " .. tostring(v), commonRC.rpcDenied,
    { "RADIO", 1, "SetInteriorVehicleData", "INVALID_DATA" })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
