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
-- 4) Mobile certificate becomes expired and sdl certificate is still valid according to date/time from GetSystemTime response
-- SDL must:
-- 1) not trigger PTU
-- 2) Not start secure service: Handshake is finished with frameInfo = START_SERVICE_NACK, encryption = false
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Security/GetSystemTime/common')
local runner = require('user_modules/script_runner')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ General configuration parameters ]]
config.serverCertificatePath = "./files/Security/GetSystemTime_certificates/spt_credential_0317_22.pem"
config.serverPrivateKeyPath = "./files/Security/GetSystemTime_certificates/spt_credential_0317_22.pem"
config.serverCAChainCertPath = "./files/Security/GetSystemTime_certificates/spt_credential_0317_22.pem"

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
  year = 2024,
  tz_hour = -3,
  tz_minute = 10
}

--[[ Local Functions ]]
local function ptUpdateWithNotActualCer(pTbl)
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
runner.Step("PolicyTableUpdate with valid certificate", common.policyTableUpdate, { ptUpdateWithNotActualCer })
runner.Step("Handshake with BC.GetSystemTime request from SDL", common.startServiceSecured,
  { pData, serviceId, 1, systemTime })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
