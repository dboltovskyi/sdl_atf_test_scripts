---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_core/issues/2670
--
-- Steps to reproduce:
-- 1. Empty array is defined in moduleType parameter in default section in preloaded_pt.json
-- 2. Update groups in default with "RemoteControl" group
-- 3. Register RC app
-- 4. App requests successful GetInteriorVD with module_1
-- 5. App requests successful GetInteriorVD with module_2
-- 6. Perform IGN_OFF and IGN_ON
-- 7. Register same RC app
-- 8. Request GetInteriorVD with allowed module_1
-- 9. Request GetInteriorVD with allowed module_2
-- SDL must:
-- 1. process GetInteriorVD with allowed module_1 successful and resend request to HMI
-- 2. process GetInteriorVD with allowed module_2 successful and resend request to HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')
local actions = require("user_modules/sequences/actions")
local test = require("user_modules/dummy_connecttest")
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local json = require("modules/json")
local utils = require('user_modules/utils')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local function ]]
local function updatePreloadedPT()
  if not pCountOfRCApps then pCountOfRCApps = 2 end
  local preloadedFile = commonPreconditions:GetPathToSDL()
  .. commonFunctions:read_parameter_from_smart_device_link_ini("PreloadedPT")
  local preloadedTable = utils.jsonFileToTable(preloadedFile)
  preloadedTable.policy_table.functional_groupings["DataConsent-2"].rpcs = json.null
  preloadedTable.policy_table.functional_groupings["RemoteControl"].rpcs.OnRCStatus = {
    hmi_levels = { "FULL", "BACKGROUND", "LIMITED", "NONE" }
  }
  preloadedTable.policy_table.app_policies.default.groups = {"Base-4", "RemoteControl"}
  preloadedTable.policy_table.app_policies.default.moduleType = json.EMPTY_ARRAY
  utils.tableToJsonFile(preloadedTable, preloadedFile)
end

function preconditions()
  	actions.preconditions()
    updatePreloadedPT()
end

local function ignitionOff()
  actions.getHMIConnection():SendNotification("BasicCommunication.OnExitAllApplications", { reason = "SUSPEND" })
  EXPECT_HMINOTIFICATION("BasicCommunication.OnSDLPersistenceComplete")
  :Do(function()
      actions.getHMIConnection():SendNotification("BasicCommunication.OnExitAllApplications",{ reason = "IGNITION_OFF" })
      actions.getMobileSession():ExpectNotification("OnAppInterfaceUnregistered", { reason = "IGNITION_OFF" })
    end)
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppUnregistered", { unexpectedDisconnect = false })
  EXPECT_HMINOTIFICATION("BasicCommunication.OnSDLClose")
  :Do(function()
      test.mobileSession[1] = nil
      StopSDL()
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", preconditions)
runner.Step("Backup preloaded pt", commonPreconditions.BackupFile, { test, "sdl_preloaded_pt.json" })
runner.Step("Start SDL, HMI, connect Mobile, start Session", actions.start)
runner.Step("RAI", actions.registerAppWOPTU)
runner.Step("Activate App", actions.activateApp)
runner.Step("GetInteriorVehicleData SEAT", commonRC.subscribeToModule, { "SEAT" })
runner.Step("GetInteriorVehicleData RADIO", commonRC.subscribeToModule,{ "RADIO" })
-- runner.Title("Test")
runner.Step("ignitionOff", ignitionOff)
runner.Step("Start SDL, HMI, connect Mobile, start Session", actions.start)
runner.Step("RAI", actions.registerAppWOPTU)
runner.Step("Activate App", actions.activateApp)
runner.Step("GetInteriorVehicleData SEAT", commonRC.subscribeToModule, { "SEAT" })
runner.Step("GetInteriorVehicleData RADIO", commonRC.subscribeToModule,{ "RADIO" })

runner.Title("Postconditions")
runner.Step("Restore preloaded pt", commonPreconditions.RestoreFile, { test, "sdl_preloaded_pt.json" })
runner.Step("Stop SDL", actions.postconditions)
