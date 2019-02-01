---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/2
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/current_module_status_data.md
-- Item: Use Case 1: Main Flow
--
-- Requirement summary:
-- [SDL_RC] Current module status data GetInteriorVehicleData

--
-- Description: TRS: GetInteriorVehicleData, #3
-- In case:
-- 1) RC app sends valid and allowed by policies GetInteriorvehicleData_request
-- 2) and SDL received GetInteriorVehicledata_response with successful result code and module data containing
--  "availableHdChannels" parameter having invalid values from HMI
-- SDL must:
-- 1) transfer GetInteriorVehicleData_response with resultCode = "GENERIC_ERROR" and 'false' as a success result of
-- request
---------------------------------------------------------------------------------------------------

--[[ Requiredcontaining incorrect  Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')
local hmi_values = require("user_modules/hmi_values")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local hmiVal = hmi_values.getDefaultHMITable()
hmiVal.RC.GetCapabilities.params.remoteControlCapability.radioControlCapabilities[1].availableHdChannelsAvailable = true

local incorrectParams = {
  outOfBoundaryArray = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  negativNumber = {-1},
  stringValue = "String"
}

--[[ Local Functions ]]
function commonRC.getModuleControlData(module_type)
  return commonRC.actualInteriorDataStateOnHMI[module_type]
end

local function MobileRequestSuccessfull(invParam)
  commonRC.actualInteriorDataStateOnHMI.RADIO.radioControlData = {availableHdChannels = invParam}
  local cid = commonRC.getMobileSession():SendRPC("GetInteriorVehicleData", {moduleType = "RADIO"})
  commonRC.getHMIConnection():ExpectRequest("RC.GetInteriorVehicleData", {moduleType = "RADIO"})

  :Do(function(_, data)
      commonRC.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {
        moduleData = commonRC.getModuleControlData("RADIO")})
    end)
  commonRC.getMobileSession():ExpectResponse(cid, {success = false, resultCode = "GENERIC_ERROR"})
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start, {hmiVal})
runner.Step("RAI", commonRC.registerAppWOPTU)
runner.Step("Activate App", commonRC.activateApp)

runner.Title("Test HMI send response with availableHdChannels parameter having incorrect values.")
for index, val in pairs(incorrectParams) do
  runner.Step("GetInteriorVehicleData HMI sends availableHdChannels as _" .. index, MobileRequestSuccessfull, {val})
end

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
