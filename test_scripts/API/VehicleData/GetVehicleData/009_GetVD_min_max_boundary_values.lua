----------------------------------------------------------------------------------------------------
-- TBA
----------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]-------------------------------------------------------------------
local common = require('test_scripts/API/VehicleData/common')

--[[ Local Constants ]]-----------------------------------------------------------------------------
local testTypes = {
  -- common.testType.VALID_RANDOM,
  -- common.testType.ONLY_MANDATORY_PARAMS,
  -- common.testType.LOWER_IN_BOUND,
  -- common.testType.UPPER_IN_BOUND,
  -- common.testType.LOWER_OUT_OF_BOUND,
  -- common.testType.UPPER_OUT_OF_BOUND,
  -- common.testType.ENUM_ITEMS,
  common.testType.DEBUG
}

--[[ Local Variables ]]-----------------------------------------------------------------------------
function common.getVDParams()
  return { emergencyEvent = 1 }
end

--[[ Local Functions ]]-----------------------------------------------------------------------------
local function processRPC(pParams)
  local cid = common.getMobileSession():SendRPC(pParams.mobile.name, pParams.mobile.request)
  common.getHMIConnection():ExpectRequest(pParams.hmi.name, pParams.hmi.request)
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", pParams.hmi.response)
    end)
  common.getMobileSession():ExpectResponse(cid, pParams.mobile.response)
end

--[[ Scenario ]]------------------------------------------------------------------------------------
common.Title("Preconditions")
common.Step("Clean environment and update preloaded_pt file", common.preconditions)
common.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
common.Step("Register App", common.registerApp)
common.Step("Activate App", common.activateApp)

common.Title("Test")
for param in common.spairs(common.getVDParams(true)) do
  common.Title("VD parameter: " .. param)
  for _, testType in pairs(testTypes) do
    common.Title(common.getKeyByValue(common.testType, testType))
    for _, t in pairs(common.getTests(common.rpc.get, testType, param)) do
      common.Step(t.name, processRPC, { t.params })
    end
  end
end

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
