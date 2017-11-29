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
  name = "Start Service Video ACK",
  service = common.serviceType.VIDEO,
  request = {
    frameInfo = common.frameInfo.START_SERVICE,
    version = 5,
    params = {
      height = {
        type = common.bsonType.STRING, -- incorrect type
        value = "240"
      },
      width = {
        type = common.bsonType.STRING, -- incorrect type
        value = "320"
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
    frameInfo = common.frameInfo.START_SERVICE_ACK,
    version = 5,
    params = {
      hashId = {
        type = common.bsonType.INT32,
        value = common.hashId.value
      },
      mtu = {
        type = common.bsonType.INT64,
        value = 131072
      },
      rejectedParams = {
        type = common.bsonType.ARRAY,
        value = {
          {
            type = common.bsonType.STRING,
            value = "height"
          },
          {
            type = common.bsonType.STRING,
            value = "width"
          }
        }
      }
    }
  }
}

--[[ Local Functions ]]
local function startService(pServiceType, pRequest, pResponse, pTest)
  EXPECT_HMICALL("SetVideoConfig")
  :Do(function(_, data)
      pTest.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", { })
    end)
  common.sendControlMessage(pServiceType, pRequest.frameInfo, pRequest.version, pRequest.params)
  common.expectControlMessage(pServiceType, pResponse.frameInfo, pResponse.version, pResponse.params)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, Connect Mobile", common.start)
runner.Step("Start Mobile Session", common.startMobileSession)
runner.Step("Start RPC Service", common.startRPCService)
runner.Step("Register Application", common.registerApp)
runner.Step("Activate Application", common.activateApp)

runner.Title("Test")
runner.Step(testCase.name, startService, { testCase.service, testCase.request, testCase.response })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
