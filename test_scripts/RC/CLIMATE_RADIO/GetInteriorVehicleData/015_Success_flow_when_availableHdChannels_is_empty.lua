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
-- 2) and SDL received GetInteriorVehicledata_response with successful result code and current module data from HMI
-- SDL must:
-- 1) transfer GetInteriorVehicleData_response with provided from HMI current module data for allowed module and control items
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')
local json = require('json')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local pModule = "RADIO"

local response_table = {
  id = 28,
  jsonrpc = "2.0",
  result = {
    code = 0,
    method = "RC.GetInteriorVehicleData",
    moduleData = {
      moduleType = "RADIO",
      radioControlData = {
        availableHdChannels = json.EMPTY_ARRAY,
        hdChannel = 1
      }
    }
  }
}

--[[ Local Functions ]]
local function MobileRequestSuccessfull(pModuleType)
  local cid = commonRC.getMobileSession():SendRPC("GetInteriorVehicleData", {moduleType = pModuleType})
  EXPECT_HMICALL("RC.GetInteriorVehicleData", {moduleType = pModuleType})
  :Do(function(_, data)
    response_table.id = data.id
    response_table.result.method = data.method
    local payload = json.encode(response_table)
    commonRC.getHMIConnection():Send(payload)
    end)
  commonRC.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS"})
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI", commonRC.registerAppWOPTU)
runner.Step("Activate App", commonRC.activateApp)
runner.Title("Test")
runner.Step("GetInteriorVehicleData ", MobileRequestSuccessfull, {pModule})
runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
