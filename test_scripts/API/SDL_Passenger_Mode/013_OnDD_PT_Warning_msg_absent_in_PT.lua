---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0119-SDL-passenger-mode.md
-- Description:
-- In case:
-- 1) OnDriverDistraction notification is allowed by Policy for (FULL, LIMITED, BACKGROUND, NONE) HMILevel
-- 2) In Policy:
--  - "lock_screen_dismissal_enabled" parameter is defined with correct value (true)
--  - there is empty value in "LockScreenDismissalWarning" section for default language
-- 3) App registered (HMI level NONE) with 'DE-DE' language
-- 4) HMI sends OnDriverDistraction notifications with state=DD_OFF and then with state=DD_ON one by one
-- SDL does:
--  - Send OnDriverDistraction(DD_OFF) notification to mobile without both "lockScreenDismissalEnabled"
--    and "lockScreenDismissalWarning" parameters and all mandatory fields
--  - Send OnDriverDistraction(DD_ON) notification to mobile with both "lockScreenDismissalEnabled"=true
--    and empty "lockScreenDismissalWarning" parameters and all mandatory fields
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/SDL_Passenger_Mode/commonPassengerMode')
local utils = require("user_modules/utils")
local json = require("modules/json")
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local lockScreenDismissalEnabled = true

--[[ Local Functions ]]
local function updatePreloadedPT()
  local preloadedPT = commonFunctions:read_parameter_from_smart_device_link_ini("PreloadedPT")
  local preloadedFile = commonPreconditions:GetPathToSDL() .. preloadedPT
  local pt = utils.jsonFileToTable(preloadedFile)
  pt.policy_table.functional_groupings["DataConsent-2"].rpcs = json.null
  pt.policy_table.module_config.lock_screen_dismissal_enabled = lockScreenDismissalEnabled
  pt.policy_table.consumer_friendly_messages.messages["LockScreenDismissalWarning"] = nil
  utils.tableToJsonFile(pt, preloadedFile)
end

local function onDriverDistraction(pState)
  common.getHMIConnection():SendNotification("UI.OnDriverDistraction", { state = pState })
  common.getMobileSession():ExpectNotification("OnDriverDistraction")
  :ValidIf(function(_, data)
      local act = data.payload
      if act.state == "DD_OFF"
        and (act.lockScreenDismissalEnabled ~= nil or act.lockScreenDismissalWarning ~= nil) then
          return false, "There are unexpected 'lockScreenDismissalEnabled' "
          .. "or 'lockScreenDismissalWarning' parameters in case DD_OFF"
      end
      if act.state == "DD_ON" then
        if act.lockScreenDismissalEnabled ~= true then
          return false, "Expected 'true' for 'lockScreenDismissalEnabled' parameter in case DD_ON"
        end
        if act.lockScreenDismissalWarning ~= "" then
          return false, "Expected '' for 'lockScreenDismissalWarning' parameter in case DD_ON"
        end
      end
      return true
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Set LockScreenDismissalEnabled", updatePreloadedPT)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("Register App", common.registerAppWOPTU)
runner.Step("Activate App to FULL", common.activateApp)

runner.Title("Test")
runner.Step("OnDriverDistraction OFF true", onDriverDistraction, { "DD_OFF", lockScreenDismissalEnabled })
runner.Step("OnDriverDistraction ON true", onDriverDistraction, { "DD_ON", lockScreenDismissalEnabled })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
