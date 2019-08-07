---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0221-multiple-modules.md
-- Description:
--  HMI sent capabilities, where CLIMATE has three modules.
--  Mobile App sends "ButtonPress" request with omitted "moduleId" parameter to the SDL.
--  During transferring the request to the HMI SDL should add the default value of "moduleId" to it and use it further
--  communication with HMI and mobile App.
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) HMI sent capabilities where CLIMATE has three modules to the SDL
-- 3) Mobile is connected to SDL
-- 4) App is registered and activated
--
-- Steps:
-- 1) App sends "ButtonPress"(moduleType = "CLIMATE", buttonName = "FAN_DOWN", buttonPressMode = "LONG") request
--     to the SDL
--   Check:
--    SDL resends "Buttons.ButtonPress"
--     (moduleType = "CLIMATE", moduleId = "2df6518c", buttonName = "FAN_DOWN", buttonPressMode = "LONG")
--     request to the HMI, adding the default value of "moduleId"
--    HMI sends "Buttons.ButtonPress"
--     (moduleType = "CLIMATE", moduleId = "2df6518c", buttonName = "FAN_DOWN", buttonPressMode = "LONG")
--     response to the SDL
--    SDL sends "ButtonPress"(resultCode = SUCCESS", success = true) response to the App
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("test_scripts/RC/MultipleModules/commonRCMulModules")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local rcCapabilities  = { CLIMATE = common.DEFAULT }
local defaultModuleId = common.getRcCapabilities().CLIMATE[1].moduleInfo.moduleId
local requestModuleData = {
  [defaultModuleId] = {
    moduleType = "CLIMATE",
    buttonName = "FAN_DOWN",
    buttonPressMode = "LONG"
  }
}

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Build default actual module state", common.initHmiDataState, { rcCapabilities })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("RAI", common.registerApp)
runner.Step("PTU", common.policyTableUpdate, { common.PTUfunc })
runner.Step("Activate App", common.activateApp)

runner.Title("Test")
for moduleId, moduleData in pairs(requestModuleData) do
  runner.Step("Send ButtonPress request with omitted moduleId for ".. moduleData.moduleType .." module",
    common.sendButtonPressNoModuleId, { moduleId, moduleData, 1 })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
