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
  ah.rpc.SendLocation,
  ah.rpc.GetWayPoints
}
local testTypes = {
  tg.testType.ONLY_MANDATORY_PARAMS,
  tg.testType.LOWER_IN_BOUND,
  tg.testType.UPPER_IN_BOUND,
  tg.testType.LOWER_OUT_OF_BOUND,
  tg.testType.UPPER_OUT_OF_BOUND
}

--[[ Local Variables ]]-----------------------------------------------------------------------------
rpcs = { rpcs[1] }
-- testTypes = { tg.testType.LOWER_OUT_OF_BOUND }
local paramName = ""

--[[ Local Functions ]]-----------------------------------------------------------------------------
local function ptUpdate(pTbl)
  local grp = "APITest"
  pTbl.policy_table.functional_groupings[grp] = { rpcs = {}}
  for _, rpc in pairs(rpcs) do
    pTbl.policy_table.functional_groupings[grp].rpcs[cmn.getKeyByValue(ah.rpc, rpc)] = {
      hmi_levels = { "BACKGROUND", "FULL", "LIMITED" }
    }
  end
  pTbl.policy_table.app_policies[cmn.getMobileAppId(1)] = cmn.getAppConfig()
end

--[[ Scenario ]]------------------------------------------------------------------------------------
runner.Title("Preconditions")
runner.Step("Clean environment", cmn.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", cmn.start)
runner.Step("RAI, PTU", cmn.registerAppWithPTU, { 1, ptUpdate })
runner.Step("Activate App", cmn.activateApp)

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
