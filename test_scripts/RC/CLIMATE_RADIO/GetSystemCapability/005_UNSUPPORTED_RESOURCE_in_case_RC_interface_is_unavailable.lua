---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/1
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/RC/detailed_info_GetSystemCapability.md
-- Item: Use Case 2: Exception 5.1
--
-- Requirement summary:
-- [SDL_RC] Capabilities
--
-- Description:
-- In case:
--
-- SDL must:
--
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')
local hmi_values = require('user_modules/hmi_values')

--[[ General configuration parameters ]]
config.checkAllValidations = true

--[[ Local Functions ]]
local function getHMIParams()
  local params = hmi_values.getDefaultHMITable()
  params.RC.IsReady.params.available = false
  params.RC.GetCapabilities.params = { }
  params.RC.GetCapabilities.occurrence = 0
  return params
end

local function rpcUnsupportedResource(self)
  local mobSession = commonRC.getMobileSession(self)
  local cid = mobSession:SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  mobSession:ExpectResponse(cid, { success = false, resultCode = "UNSUPPORTED_RESOURCE" })
  :ValidIf(function(_, data)
      if data.payload.systemCapability.remoteControlCapability then
        return false, "RC capabilities are transferred to mobile application"
      end
      return true
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI (RC interface is unavailable), connect Mobile, start Session", commonRC.start,
  { getHMIParams() })
runner.Step("RAI, PTU", commonRC.rai_ptu)
runner.Step("Activate App1", commonRC.activate_app)

runner.Title("Test")
runner.Step("GetSystemCapability_UNSUPPORTED_RESOURCE", rpcUnsupportedResource)

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
