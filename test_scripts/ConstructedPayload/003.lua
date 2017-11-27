---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary:
-- TBD
--
-- Description:
-- In case:
-- TBD
-- SDL must:
-- TBD
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/ConstructedPayload/commonConstructedPayload')

--[[ Local Constants ]]
local testCase = {
  name = "Start Service RPC NACK",
  service = common.serviceType.RPC,
  request = {
    frameInfo = common.frameInfo.START_SERVICE,
    version = 1,
    params = {
      protocolVersion = {
        type = common.bsonType.INT32, -- incorrect type
        value = 4
      }
    }
  },
  response = {
    frameInfo = common.frameInfo.START_SERVICE_NACK,
    version = 5,
    params = { }
  }
}

--[[ Local Functions ]]
local function startService(pServiceType, pRequest, pResponse)
  common.sendControlMessage(pServiceType, pRequest.frameInfo, pRequest.version, pRequest.params)
  common.expectControlMessage(pServiceType, pResponse.frameInfo, pResponse.version, pResponse.params)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, Connect Mobile", common.start)
runner.Step("Start Mobile Session", common.startMobileSession)

runner.Title("Test")
runner.Step(testCase.name, startService, { testCase.service, testCase.request, testCase.response })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
