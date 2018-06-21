---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary:
-- TBD
--
-- Description:
-- In case:
-- 1) Application is registered with PROJECTION appHMIType
-- 2) and starts audio services
-- 3) HMI does not respond on first StartAudioStream
-- SDL must:
-- 1) start retry sequence for StartAudioStream
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/MobileProjection/Phase1/common')
local runner = require('user_modules/script_runner')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local appHMIType = "PROJECTION"

--[[ General configuration parameters ]]
config.application1.registerAppInterfaceParams.appHMIType = { appHMIType }

--[[ Local Functions ]]
local function ptUpdate(pTbl)
  pTbl.policy_table.app_policies[common.getConfigAppParams().appID].AppHMIType = { appHMIType }
end

local function startService()
  common.getMobileSession():StartService(10)
  common.getHMIConnection():ExpectRequest("Navigation.StartAudioStream")
  :Do(function(exp,data)
      if 4 == exp.occurences then
        common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { })
      end
    end)
  :Times(4)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Set StartStreamRetry value to 5,50", common.setSDLIniParameter, { "StartStreamRetry", "5,50" })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("Register App", common.registerApp)
runner.Step("PolicyTableUpdate with HMI types", common.policyTableUpdate, { ptUpdate })
runner.Step("Activate App", common.activateApp)

runner.Title("Test")
runner.Step("Start audio service with retry sequence for StartAudioStream", startService)

runner.Title("Postconditions")
runner.Step("Stop service", common.StopService, { 10 })
runner.Step("Stop SDL", common.postconditions)
