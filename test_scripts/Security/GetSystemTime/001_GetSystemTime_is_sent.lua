---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary: TBD
--
-- Description:
-- In case:
-- 1) HMI sends BC.OnSystemTimeReady notification to SDL during initialization
-- 2) Mobile and sdl certificates are valid
-- 3) Mobile app starts secure service
-- SDL must:
-- 1) Request GetSystemTime from HMI
-- 2) Mobile and SDL certificates are valid according to date/time from GetSystemTime response
-- 3) Start secure service: Handshake is finished with frameInfo = START_SERVICE_ACK, encryption = true
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

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI with BC.OnSystemTimeReady, connect Mobile, start Session", common.start, { true })

runner.Title("Test")

runner.Step("Register App", common.registerApp)
runner.Step("Activate App", common.activateApp)
runner.Step("PolicyTableUpdate with certificate", common.policyTableUpdate, { ptUpdate })
runner.Step("Handshake with BC.GetSystemTime request from SDL", common.startServiceSecured,
	{ pData, serviceId, 1, common.getSystemTimeValue(), 1 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
