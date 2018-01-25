---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/1
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/RC/detailed_info_GetSystemCapability.md
-- Item: Use Case 2: Exception 3.1
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
local mod = "RADIO"

--[[ Local Functions ]]
local function ptu_update_func(tbl)
  tbl.policy_table.app_policies[config.application1.registerAppInterfaceParams.appID].moduleType = { "CLIMATE" }
end

local function rpcDissallowed(self)
  local mobSession = commonRC.getMobileSession(self)
  local cid = mobSession:SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  mobSession:ExpectResponse(cid, { success = false, resultCode = "DISALLOWED" })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI, PTU", commonRC.rai_ptu, { ptu_update_func })
runner.Step("Activate App1", commonRC.activate_app)

runner.Title("Test")
runner.Step("GetSystemCapability_DISALLOWED " .. mod, rpcDissallowed)

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
