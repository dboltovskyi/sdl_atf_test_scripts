---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary: TBD
--
-- Description:
-- In case:
-- 1) Mobile app starts secure RPC service
-- 2) Mobile and sdl certificates are up to date
-- 3) SDL requests GetSystemTime
-- 4) HMI responds in 9 seconds
-- SDL must:
-- 1) wait GetSystemTime default timeout
-- 2) Start secure service: Handshake is finished with frameInfo = START_SERVICE_ACK, encryption = true
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Security/GetSystemTime/common')
local runner = require('user_modules/script_runner')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local serviceId = 7
local pData = {
  frameInfo = common.frameInfo.START_SERVICE_ACK,
  encryption = true
}

--[[ Local Functions ]]
local function ptUpdate(pTbl)
  local filePath = "./files/Security/GetSystemTime_certificates/client_credential.pem"
  local crt = common.readFile(filePath)
  pTbl.policy_table.module_config.certificate = crt
end

local function startServiceSecuredWithDelayedGSTResponse()
  common.getMobileSession():StartSecureService(serviceId)
  common.getMobileSession():ExpectControlMessage(serviceId, pData)
  :Timeout(11500)
  common.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate")
  :Times(0)
  common.getMobileSession():ExpectHandshakeMessage()
  :Times(1)
  EXPECT_HMICALL("BasicCommunication.GetSystemTime")
  :Do(function(_,data)
      local function GetSystemTimeResponse()
        common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {
          systemTime = common.getSystemTimeValue() })
      end
      RUN_AFTER(GetSystemTimeResponse, 8000)
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI with BC.OnSystemTimeReady, connect Mobile, start Session", common.start, { true })

runner.Title("Test")

runner.Step("Register App", common.registerApp)
runner.Step("Activate App", common.activateApp)
runner.Step("PolicyTableUpdate with valid certificate", common.policyTableUpdate, { ptUpdate })
runner.Step("Handshake with response BC.GetSystemTime in 9 sec from HMI", startServiceSecuredWithDelayedGSTResponse)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
