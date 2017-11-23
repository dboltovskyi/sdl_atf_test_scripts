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
local testCase1 = {
  name = "Start Service RPC ACK",
  service = common.serviceType.RPC,
  request = {
    frameInfo = common.frameInfo.START_SERVICE,
    version = 1,
    params = { }
  },
  response = {
    frameInfo = common.frameInfo.START_SERVICE_ACK,
    version = 4,
    params = { }
  }
}

local testCase2 = {
  name = "Start Service Video NACK",
  service = common.serviceType.VIDEO,
  request = {
    frameInfo = common.frameInfo.START_SERVICE,
    version = 5,
    params = {
      height = {
        type = common.bsonType.INT32,
        value = 240
      },
      width = {
        type = common.bsonType.INT32,
        value = 320
      },
      videoProtocol = {
        type = common.bsonType.STRING,
        value = "RAW"
      },
      videoCodec = {
        type = common.bsonType.STRING,
        value = "H264"
      }
    }
  },
  response = {
    frameInfo = common.frameInfo.START_SERVICE_NACK,
    version = 5,
    params = {
      rejectedParams = { } -- List for rejected parameters needs to be defined in correct Array format
    }
  }
}

--[[ Local Functions ]]
local function process(pServiceType, pRequest, pResponse, self)
  EXPECT_HMICALL("SetVideoConfig")
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", { rejectedParams = { "protocol" }})
    end)
  common.sendControlMessage(common.app.id1, pServiceType, pRequest.frameInfo, pRequest.version, pRequest.params, self)
  common.expectControlMessage(common.app.id1, pServiceType, pResponse.frameInfo, pResponse.version, pResponse.params, self)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, Connect Mobile", common.start)
runner.Step("Start Mobile Session", common.startMobileSession)
runner.Step(testCase1.name, process, { testCase1.service, testCase1.request, testCase1.response })
runner.Step("RAI", common.registerApp)
runner.Step("ActivateApp", common.activateApp)

runner.Title("Test")
runner.Step(testCase2.name, process, { testCase2.service, testCase2.request, testCase2.response })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
