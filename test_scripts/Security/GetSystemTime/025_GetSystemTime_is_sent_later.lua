---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary: TBD
--
-- Description:
-- In case:
-- 1) HMI does not send BC.OnSystemTimeReady notification to SDL during initialization
-- 2) Mobile and sdl certificates are valid
-- 3) Mobile app starts secure service
-- 4) SDL respond with NACK
-- 5) HMI sends BC.OnSystemTimeReady notification
-- 6) Mobile app starts secure service again
-- SDL must:
-- 1) Send GetSystemTime request to HMI (and HMI replies with valid system time)
-- 2) Start secure service: Handshake is finished with frameInfo = START_SERVICE_ACK, encryption = true
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Security/GetSystemTime/common')
local runner = require('user_modules/script_runner')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local serviceId = 7

--[[ Local Functions ]]
local function ptUpdate(pTbl)
  local filePath = "./files/Security/GetSystemTime_certificates/client_credential.pem"
  local crt = common.readFile(filePath)
  pTbl.policy_table.module_config.certificate = crt
end

local function sendOnSystemTimeReady()
  common.getHMIConnection():SendNotification("BasicCommunication.OnSystemTimeReady")
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI without BC.OnSystemTimeReady, connect Mobile, start Session", common.start, { false })

runner.Title("Test")

runner.Step("Register App", common.registerApp)
runner.Step("Activate App", common.activateApp)
runner.Step("PolicyTableUpdate with certificate", common.policyTableUpdate, { ptUpdate })
runner.Step("Handshake without BC.GetSystemTime request from SDL", common.startServiceSecured, {
  { frameInfo = common.frameInfo.START_SERVICE_NACK, encryption = false },
  serviceId,
  0,
  common.getSystemTimeValue(),
  0 })
runner.Step("Send BC.OnSystemTimeReady from HMI", sendOnSystemTimeReady)
runner.Step("Handshake with BC.GetSystemTime request from SDL", common.startServiceSecured, {
  { frameInfo = common.frameInfo.START_SERVICE_ACK, encryption = true },
  serviceId,
  1,
  common.getSystemTimeValue(),
  1 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
