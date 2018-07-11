---------------------------------------------------------------------------------------------------
-- Issue 32917
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Defects/Sync3_2v2/common')
local json = require("modules/json")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local tc = {
  grp = {
    [1] = { name = "Dummy-1", prompt = "Dummy_1", params = json.EMPTY_ARRAY },
    [2] = { name = "Dummy-2", prompt = "Dummy_2", params = { "speed" } }
  },
  resultCode = "SUCCESS",
  success = true
}

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start, { common.getHMIValues() })
runner.Step("Register App", common.registerApp)
runner.Step("Activate App", common.activateApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate, { tc })

runner.Title("Test")
runner.Step("Send GetListOfPermissions", common.getListOfPermissions, { tc })
runner.Step("Consent Groups", common.consentGroups, { tc })
runner.Step("Send GetVehicleData", common.getVD, { tc })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
