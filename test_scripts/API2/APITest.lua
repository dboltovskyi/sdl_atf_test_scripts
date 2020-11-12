----------------------------------------------------------------------------------------------------
-- API Test
----------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]-------------------------------------------------------------------
local runner = require('user_modules/script_runner')
local cmn = require('test_scripts/API2/APICommon')
local tg = require('test_scripts/API2/APITestGen')
local ah = require('test_scripts/API2/APIHelper')

--[[ Local Constants ]]-----------------------------------------------------------------------------
local rpcs = {
  ah.rpc.GetVehicleData
}
local testTypes = {
  -- tg.testType.DEBUG,
  -- tg.testType.ONLY_MANDATORY_PARAMS,
  -- tg.testType.LOWER_IN_BOUND,
  -- tg.testType.UPPER_IN_BOUND,
  -- tg.testType.LOWER_OUT_OF_BOUND,
  -- tg.testType.UPPER_OUT_OF_BOUND,
  tg.testType.VALID_RANDOM
}

--[[ Local Variables ]]-----------------------------------------------------------------------------
rpcs = { rpcs[1] }
-- testTypes = { tg.testType.LOWER_OUT_OF_BOUND }
local paramName = "windowStatus"--"windowStatus"--"deviceStatus"

--[[ Local Functions ]]-----------------------------------------------------------------------------


--[[ Scenario ]]------------------------------------------------------------------------------------
cmn.Title("Preconditions")
cmn.Step("Clean environment and update preloaded_pt file", cmn.preconditions)
cmn.Step("Start SDL, HMI, connect Mobile, start Session", cmn.start)
cmn.Step("Register App", cmn.registerApp)
cmn.Step("Activate App", cmn.activateApp)

runner.Title("Test")

for _, rpc in pairs(rpcs) do
  runner.Title(cmn.getKeyByValue(ah.rpc, rpc))
  for _, testType in pairs(testTypes) do
    runner.Title(cmn.getKeyByValue(tg.testType, testType))
    for _, t in pairs(tg.getTests(rpc, testType, paramName)) do
      runner.Step(t.name, t.func, { t.params })
    end
  end
end

runner.Title("Postconditions")
runner.Step("Stop SDL", cmn.postconditions)
