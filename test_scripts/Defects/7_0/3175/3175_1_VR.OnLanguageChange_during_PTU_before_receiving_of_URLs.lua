---------------------------------------------------------------------------------------------------
-- Issue: https://github.com/smartdevicelink/sdl_core/issues/3175
--
-- Description: SDL should successfully process VR.ChangeLanguage during PTU
--
-- Pre-conditions:
-- 1. Start SDL, HMI, connect Mobile device
-- 2. Register application which is new for SDL to trigger PTU
--
-- Steps:
-- 1. HMI sends VR.OnLanguageChange before receiving of URLs during PTU processing
-- SDL does:
--  - send OnLanguageChange notification to App
--  - send OnAppInterfaceUnregistered(reason = "LANGUAGE_CHANGE") notification to App
--  - send BasicCommunication.OnAppUnregistered(unexpectedDisconnect = false) to HMI
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local common = require('test_scripts/Defects/7_0/3175/common_3175')

--[[ Local Functions ]]
local function performPTUWithVrOnLanguageChange()
  local requestId = common.getHmiConnection():SendRequest("SDL.GetPolicyConfigurationData",
    { policyType = "module_config", property = "endpoints" })
  common.getHmiConnection():ExpectResponse(requestId)
  common.checkVrOnLanguageChangeProcessing()
end

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
common.Step("Register App", common.registerApp)

common.Title("Test")
common.Step("VR.OnLanguageChange before receiving of URLs during PTU processing", performPTUWithVrOnLanguageChange)

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
