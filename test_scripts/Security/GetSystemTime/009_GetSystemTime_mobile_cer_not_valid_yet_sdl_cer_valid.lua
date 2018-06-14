---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary: TBD
--
-- Description:
-- In case:
-- 1) Mobile app starts secure RPC service
-- 2) Mobile certificate is not up to date yet and sdl certificates is up to date
-- 3) SDL requests GetSystemTime
-- 4) Mobile certificate is still not valid and sdl certificates is valid according to date/time from GetSystemTime response
-- SDL must:
-- 1) not trigger PTU
-- 2) Not start secure service: Handshake is finished with frameInfo = START_SERVICE_NACK, encryption = false
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Security/GetSystemTime/common')
local runner = require('user_modules/script_runner')

--[[ General configuration parameters ]]
config.serverCertificatePath = "./files/Security/GetSystemTime_certificates/spt_credential_0323_28.pem"
config.serverPrivateKeyPath = "./files/Security/GetSystemTime_certificates/spt_credential_0323_28.pem"
config.serverCAChainCertPath = "./files/Security/GetSystemTime_certificates/spt_credential_0323_28.pem"

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local serviceId = 7
local pData = {
  frameInfo = common.frameInfo.START_SERVICE_NACK,
  encryption = false
}

local systemTime = {
  millisecond = 100,
  second = 30,
  minute = 29,
  hour = 15,
  day = 20,
  month = 1,
  year = 2020,
  tz_hour = -3,
  tz_minute = 10
}

--[[ Local Functions ]]
local function ptUpdate(pTbl)
  local filePath = "./files/Security/GetSystemTime_certificates/client_credential_0316_21.pem"
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
runner.Step("PolicyTableUpdate with valid certificate", common.policyTableUpdate, { ptUpdate })
runner.Step("Handshake with BC.GetSystemTime request from SDL", common.startServiceSecured,
  { pData, serviceId, 1, systemTime, 1 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
