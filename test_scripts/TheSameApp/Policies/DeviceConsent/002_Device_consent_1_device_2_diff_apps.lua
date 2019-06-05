---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0204-same-app-from-multiple-devices.md
-- Description: Consent of one mobile device with two different registered applications
--
-- Preconditions:
-- 1)SDL and HMI are started
-- 2)Mobile №1 is connected to SDL but is not consented
-- 3)Applications App1 and App2 are registered on Mobile №1 (two different applications)
--
-- Steps:
-- 1) App1 from Mobile №1 sends valid GetSystemCapability request to SDL
--   Check:
--    SDL sends GetSystemCapability(resultCode = DISALLOWED) response to App1
-- 2) App2 from Mobile №1 sends valid GetSystemCapability request to SDL
--   Check:
--    SDL sends GetSystemCapability(resultCode = DISALLOWED) response to App2
-- 3) Mobile №1 is consented by user from HMI GUI (SDL.OnAllowSDLFunctionality)
-- App1 from Mobile №1 sends valid GetSystemCapability request to SDL
--   Check:
--    SDL sends GetSystemCapability(resultCode = SUCCESS) response to App1
-- 4) App2 from Mobile №1 sends valid GetSystemCapability request to SDL
--   Check:
--    SDL sends GetSystemCapability(resultCode = SUCCESS) response to App2
-- 5) Mobile №1 is declined by user from HMI GUI (SDL.OnAllowSDLFunctionality)
-- App1 from Mobile №1 sends valid GetSystemCapability request to SDL
--   Check:
--    SDL sends GetSystemCapability(resultCode = DISALLOWED) response to App1
-- 6) App2 from Mobile №1 sends valid GetSystemCapability request to SDL
--   Check:
--    SDL sends GetSystemCapability(resultCode = DISALLOWED) response to App2

---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/TheSameApp/commonTheSameApp')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false
runner.testSettings.restrictions.sdlBuildOptions = {{extendedPolicy = {"EXTERNAL_PROPRIETARY"}}}

--[[ Local Data ]]
local devices = {
  [1] = { host = "1.0.0.1", port = config.mobilePort }
}

local appParams = {
  [1] = {
    syncMsgVersion =
    {
      majorVersion = 5,
      minorVersion = 0
    },
    appName = "Test Application1",
    isMediaApplication = false,
    languageDesired = 'EN-US',
    hmiDisplayLanguageDesired = 'EN-US',
    appHMIType = { "DEFAULT" },
    appID = "0001",
    fullAppID = "0000001",
    deviceInfo =
    {
      os = "Android",
      carrier = "Megafon",
      firmwareRev = "Name: Linux, Version: 3.4.0-perf",
      osVersion = "4.4.2",
      maxNumberRFCOMMPorts = 1
    }
  },
  [2] = {
    syncMsgVersion =
    {
      majorVersion = 5,
      minorVersion = 0
    },
    appName = "Test Application2",
    isMediaApplication = false,
    languageDesired = 'EN-US',
    hmiDisplayLanguageDesired = 'EN-US',
    appHMIType = { "DEFAULT" },
    appID = "0002",
    fullAppID = "0000022",
    deviceInfo =
    {
      os = "Android",
      carrier = "Megafon",
      firmwareRev = "Name: Linux, Version: 3.4.0-perf",
      osVersion = "4.4.2",
      maxNumberRFCOMMPorts = 1
    }
  }
}

--[[ Local Functions ]]
local function modificationOfPreloadedPT(pPolicyTable)
  pPolicyTable.policy_table.functional_groupings["DataConsent-2"].rpcs = common.json.null
  pPolicyTable.policy_table.functional_groupings["BaseBeforeDataConsent"].rpcs["GetSystemCapability"] = nil
  pPolicyTable.policy_table.functional_groupings["Base-4"].rpcs["GetSystemCapability"] = {
    hmi_levels = {"BACKGROUND", "FULL", "LIMITED", "NONE"}
  }

  for i = 1, #appParams do
    pPolicyTable.policy_table.app_policies[appParams[1].fullAppID] =
        common.cloneTable(pPolicyTable.policy_table.app_policies["default"])
    pPolicyTable.policy_table.app_policies[appParams[1].fullAppID].groups = {"Base-4"}
  end
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Prepare preloaded PT", common.modifyPreloadedPt, {modificationOfPreloadedPT})
runner.Step("Start SDL and HMI", common.start)
runner.Step("Connect mobile device 1 to SDL", common.connectMobDevice, {1, devices[1], false})
runner.Step("Register App1 from device 1", common.registerAppEx, {1, appParams[1], 1})
runner.Step("Register App2 from device 1", common.registerAppEx, {2, appParams[2], 1})

runner.Title("Test")
runner.Step("Disallowed GetSystemCapability from App1 from device 1", common.getSystemCapability, {1, "DISALLOWED"})
runner.Step("Disallowed GetSystemCapability from App2 from device 1", common.getSystemCapability, {2, "DISALLOWED"})

runner.Step("Allow SDL for Device 1", common.mobile.allowSDL, {1})
runner.Step("Succeed GetSystemCapability from App1 from device 1", common.getSystemCapability, {1, "SUCCESS"})
runner.Step("Succeed GetSystemCapability from App2 from device 1", common.getSystemCapability, {2, "SUCCESS"})

runner.Step("Disallow SDL for Device 1", common.mobile.disallowSDL, {1})
runner.Step("Disallowed GetSystemCapability from App1 from device 1", common.getSystemCapability, {1, "DISALLOWED"})
runner.Step("Disallowed GetSystemCapability from App2 from device 1", common.getSystemCapability, {2, "DISALLOWED"})

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
