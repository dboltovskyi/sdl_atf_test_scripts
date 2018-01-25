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
--
-- SDL must:
--
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')

--[[ Local Variables ]]
local hmiRcCapabilities = commonRC.buildHmiRcCapabilities(commonRC.DEFAULT, commonRC.DEFAULT, commonRC.DEFAULT)

--[[ Local Functions ]]
local function rpcSuccess(self)
  local mobSession = commonRC.getMobileSession(self)
  local rcCapabilities = hmiRcCapabilities.RC.GetCapabilities.params.remoteControlCapability
  rcCapabilities.climateControlCapabilities[1].currentTemperatureAvailable = nil -- absent in Mobile API
  local cid = mobSession:SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  mobSession:ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS",
    systemCapability = {
      remoteControlCapability = {
        climateControlCapabilities = rcCapabilities.climateControlCapabilities,
        radioControlCapabilities = rcCapabilities.radioControlCapabilities,
        buttonCapabilities = rcCapabilities.buttonCapabilities
      }
    }
  })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Backup HMI capabilities file", commonRC.backupHMICapabilities)
runner.Step("Update HMI capabilities file", commonRC.updateDefaultCapabilities, { { "CLIMATE", "RADIO" } })
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI (HMI has all posible RC capabilities), connect Mobile, start Session", commonRC.start,
  { hmiRcCapabilities })
runner.Step("RAI, PTU", commonRC.rai_ptu)
runner.Step("Activate App1", commonRC.activate_app)

runner.Title("Test")
runner.Step("GetSystemCapability_Positive_Case", rpcSuccess)

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
runner.Step("Restore HMI capabilities file", commonRC.restoreHMICapabilities)
