---------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/hmiStates/common')
local hmi_values = require('user_modules/hmi_values')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false
common.getConfigAppParams().appHMIType = { "COMMUNICATION" }
common.getConfigAppParams().isMediaApplication = false
local event = "EMBEDDED_NAVI"
local isMixingAudioSupported = false

--[[ Local Functions ]]
local function getHMIParams(pIsMixingSupported)
  local hmiParams = hmi_values.getDefaultHMITable()
  hmiParams.BasicCommunication.MixingAudioSupported.params.attenuatedSupported = pIsMixingSupported
  return hmiParams
end
--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session, isMixingSupported:" .. tostring(isMixingAudioSupported),
    common.start, { getHMIParams(isMixingAudioSupported) })
runner.Step("Register App", common.registerAppWOPTU)
runner.Step("Activate App", common.activateApp)

runner.Title("Active app -> Embedded Event")
runner.Step("Deactivate app", common.deactivateApp)
runner.Step("Start Embedded event " .. event, common.embeddedEventStart, { event })
runner.Title("Active Embedded event -> TTS started")
runner.Step("Start TTS", common.ttsStart)
-- runner.Step("Activate App", common.activateApp)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
