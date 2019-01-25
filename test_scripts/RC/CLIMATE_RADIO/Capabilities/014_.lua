---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/1
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/RC/detailed_info_GetSystemCapability.md
-- Item: Use Case 2: Main Flow
--
-- Requirement summary:
-- [SDL_RC] Capabilities
--
-- Description:
-- In case:
-- 1) App is RC
-- 2) App tries to get RC capabilities
-- SDL must:
-- 1) Transfer RC capabilities to mobiles
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')
local hmi_values = require("user_modules/hmi_values")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local capabParams = {}
for _, v in pairs(commonRC.modules) do capabParams[v] = commonRC.DEFAULT end -- HMI has all posible RC capabilities

--[[ Local Functions ]]
--[[ Local Functions ]]
local function getHMIParams()
  local params = hmi_values.getDefaultHMITable()
  params.RC.IsReady = nil
  params.RC.GetCapabilities = nil
  return params
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Backup HMI capabilities file", commonRC.backupHMICapabilities)
--runner.Step("Update HMI capabilities file", commonRC.updateDefaultCapabilities, { commonRC.modules })
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start, { getHMIParams() })
runner.Step("RAI", commonRC.registerAppWOPTU)
runner.Step("Activate App", commonRC.activateApp)

runner.Title("Test")
runner.Step("GetSystemCapability Positive Case", rpcSuccess)

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
runner.Step("Restore HMI capabilities file", commonRC.restoreHMICapabilities)
