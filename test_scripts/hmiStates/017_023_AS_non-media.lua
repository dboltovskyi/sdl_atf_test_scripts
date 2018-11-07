---------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/hmiStates/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false
common.getConfigAppParams().appHMIType = { "DEFAULT" }
common.getConfigAppParams().isMediaApplication = false
local event = "AUDIO_SOURCE"

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("Register App", common.registerAppWOPTU)
runner.Step("Activate App", common.activateApp)

runner.Title("Active app -> Embedded Event")
runner.Step("Deactivate app", common.deactivateApp)
runner.Step("Start Embedded event " .. event, common.embeddedEventStart, { event })
runner.Title("Active Embedded event -> App activation")
-- runner.Step("Finish Embedded event " .. event, common.embeddedEventFinish, { event })
runner.Step("Activate App", common.activateApp)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
