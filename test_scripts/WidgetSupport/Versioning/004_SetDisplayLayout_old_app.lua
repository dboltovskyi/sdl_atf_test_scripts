---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0216-widget-support.md
--
-- Description: Check SDL doesn't proceed with "SetDisplayLayout" RPC for old apps (5.0)
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) New app registers with 'syncMsgVersion' = 5.0 and activated
-- Steps:
-- 1) App sends 'SetDisplayLayout' request to SDL
-- SDL:
-- 1) Doesn't NOT send request to HMI and responds with INVALID_DATA to Application
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/WidgetSupport/common')

--[[ Test Configuration ]]
common.getConfigAppParams().syncMsgVersion.majorVersion = 5
common.getConfigAppParams().syncMsgVersion.minorVersion = 0

--[[ Local Functions ]]
local function sendSetDisplayLayout()
  local params = {
    displayLayout = "Layout1"
  }
  local cid = common.getMobileSession():SendRPC("SetDisplayLayout", params)
  common.getHMIConnection():ExpectRequest("UI.SetDisplayLayout"):Times(0)
  common.getMobileSession():ExpectResponse(cid, { success = false, resultCode = "INVALID_DATA"})
end

--[[ Scenario ]]
common.Title("Precondition")
common.Step("Clean environment and Back-up/update PPT", common.precondition)
common.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
common.Step("App registration", common.registerAppWOPTU)
common.Step("App activation", common.activateApp)

common.Title("Test")
common.Step("App sends SetDisplayLayout RPC - FAIL", sendSetDisplayLayout)

common.Title("Postconditions")
common.Step("Stop SDL, restore SDL settings and PPT", common.postcondition)
