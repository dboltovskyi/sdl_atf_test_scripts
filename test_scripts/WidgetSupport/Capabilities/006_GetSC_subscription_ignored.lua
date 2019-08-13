---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0216-widget-support.md
--
-- Description: Check that SDL ignores subscribe/unsubscribe flag in case App sends `GetSystemCapability`
-- with DISPLAYS type and always contains display capability in GetSystemCapability response
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) App is registered
-- Steps:
-- 1) HMI sends `OnSystemCapabilityUpdated` to SDL for display capabilities
-- SDL does:
--  - transfer `OnSystemCapabilityUpdated` notification to App
-- 2) App sends `GetSystemCapability` request to SDL (with or without`subscribe` flag) for DISPLAYS capabilities
-- SDL does:
--  - proceed with request successfully
--  - provide up-to-date DISPLAYS data to App in response
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/WidgetSupport/common')

--[[ Local Variables ]]
local systemCapabilityParams

--[[ Local Functions ]]
local function sendOnSCU(pId)
  systemCapabilityParams = common.getOnSystemCapabilityParams()
  local disCap = systemCapabilityParams.systemCapability.displayCapabilities[1]
  disCap.windowTypeSupported[1].maximumNumberOfWindows = pId
  disCap.windowCapabilities[1].windowID = pId
  local paramsToSDL = common.cloneTable(systemCapabilityParams)
  paramsToSDL.appID = common.getHMIAppId()
  common.getHMIConnection():SendNotification("BasicCommunication.OnSystemCapabilityUpdated", paramsToSDL)
  common.getMobileSession():ExpectNotification("OnSystemCapabilityUpdated", systemCapabilityParams)
end

local function sendGetSC(pType, pSubscribe)
  local params = {
    systemCapabilityType = pType,
    subscribe = pSubscribe
  }
  local cid = common.getMobileSession():SendRPC("GetSystemCapability", params)
  common.getMobileSession():ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS",
    systemCapability = systemCapabilityParams.systemCapability
  })
  :ValidIf(function(_, data)
      local info = "Subscribe parameter is ignored. "
        .. "Auto Subscription/Unsubscription is used for DISPLAY capability type."
      if pSubscribe ~= nil and data.payload.info ~= info then
        return false, "Info parameter is missing or has unexpected value"
      end
      if pSubscribe == nil and data.payload.info ~= nil then
        return false, "Info parameter is unexpected"
      end
      return true
    end)
end

--[[ Scenario ]]
common.Title("Precondition")
common.Step("Clean environment and Back-up/update PPT", common.precondition)
common.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
common.Step("App registration", common.registerAppWOPTU)
common.Step("App activation", common.activateApp)

common.Title("Test")
common.Step("SDL transfers OnSCU notification", sendOnSCU, { 1 })
common.Step("App sends GetSC RPC for DISPLAYS, no subscribe", sendGetSC, { "DISPLAYS", nil })
common.Step("SDL transfers OnSCU notification", sendOnSCU, { 2 })
common.Step("App sends GetSC RPC for DISPLAYS, subscribe=true", sendGetSC, { "DISPLAYS", true })
common.Step("SDL transfers OnSCU notification", sendOnSCU, { 3 })
common.Step("App sends GetSC RPC for DISPLAYS, subscribe=false", sendGetSC, { "DISPLAYS", false })
common.Step("SDL transfers OnSCU notification", sendOnSCU, { 4 })
common.Step("App sends GetSC RPC for DISPLAYS, no subscribe", sendGetSC, { "DISPLAYS", nil })

common.Title("Postconditions")
common.Step("Stop SDL, restore SDL settings and PPT", common.postcondition)
