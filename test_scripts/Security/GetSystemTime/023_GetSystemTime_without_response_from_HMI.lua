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
-- 4) HMI does not respond
-- SDL must:
-- 1) wait default timeout
-- 2) Not start secure service: Handshake is finished with frameInfo = START_SERVICE_NACK, encryption = false
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Security/GetSystemTime/common')
local runner = require('user_modules/script_runner')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local serviceId = 7
local pData = {
  frameInfo = common.frameInfo.START_SERVICE_NACK,
  encryption = false
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
runner.Step("PolicyTableUpdate with valid certificate", common.policyTableUpdate, { ptUpdate })
runner.Step("Handshake without BC.GetSystemTime response from HMI", common.startServiceSecuredWitTimeoutWithoutGetSTResp,
  { pData, serviceId })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
