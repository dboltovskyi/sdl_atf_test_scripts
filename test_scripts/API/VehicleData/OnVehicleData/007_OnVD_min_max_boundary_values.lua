----------------------------------------------------------------------------------------------------
-- TBA
----------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/API/VehicleData/common')

--[[ Local Constants ]]
local testTypes = {
  common.testType.VALID_RANDOM,
  common.testType.ONLY_MANDATORY_PARAMS,
  common.testType.LOWER_IN_BOUND,
  common.testType.UPPER_IN_BOUND,
  common.testType.LOWER_OUT_OF_BOUND,
  common.testType.UPPER_OUT_OF_BOUND,
  common.testType.ENUM_ITEMS,
  common.testType.BOOL_ITEMS,
  common.testType.VALID_RANDOM_ALL,
  common.testType.MANDATORY_MISSING
}

--[[ Local Variables ]]
local isSubscribed = {}

--[[ Local Functions ]]
local function processRPC(pParams, pTestType, pVDParam)
  local function SendNotification()
    local times = 1
    if pTestType == common.testType.LOWER_OUT_OF_BOUND
      or pTestType == common.testType.UPPER_OUT_OF_BOUND
      or pTestType == common.testType.MANDATORY_MISSING then
      times = 0
    end
    common.getHMIConnection():SendNotification(pParams.hmi.name, pParams.hmi.notification)
    common.getMobileSession():ExpectNotification(pParams.mobile.name, pParams.mobile.notification)
    :Times(times)
  end
  if not isSubscribed[pVDParam] then
    common.processSubscriptionRPC(common.rpc.sub, pVDParam)
    :Do(function()
        SendNotification()
      end)
    isSubscribed[pVDParam] = true
  else SendNotification()
  end
end

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment and update preloaded_pt file", common.preconditions)
common.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
common.Step("Register App", common.registerApp)
common.Step("Activate App", common.activateApp)

common.Title("Test")
for param in common.spairs(common.getVDParams(true)) do
  common.Title("VD parameter: " .. param)
  for _, testType in pairs(testTypes) do
    local tests = common.getTests(common.rpc.on, testType, param)
    if common.getTableSize(tests) > 0 then
      common.Title(common.getKeyByValue(common.testType, testType))
      for _, t in pairs(tests) do
        common.Step(t.name, processRPC, { t.params, testType, param })
      end
    end
  end
end

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
