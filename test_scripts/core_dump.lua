---------------------------------------------------------------------------------------------------
-- Issue: https://github.com/SmartDeviceLink/sdl_core/issues/1888
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Defects/4_5/Trigger_PTU_NO_Certificate/common')
local runner = require('user_modules/script_runner')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function updateIni()
  common.setSDLIniParameter("ServerAddress", "-127.0.0.1")
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Update INI", updateIni)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
