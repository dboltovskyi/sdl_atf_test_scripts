---------------------------------------------------------------------------------------------------
-- Issues:
--   https://github.com/smartdevicelink/sdl_core/issues/2190
--   https://github.com/smartdevicelink/sdl_core/issues/2191
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("test_scripts/Security/SSLHandshakeFlow/common")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false
config.application1.registerAppInterfaceParams.appHMIType = { "NAVIGATION" }

--[[ Local Variables ]]

--[[ Local Functions ]]
local function startServiceSecuredNACK()
  local serviceId = 7
  common.getMobileSession():StartSecureService(serviceId)
  common.getMobileSession():ExpectControlMessage(serviceId, {
    frameInfo = common.frameInfo.START_SERVICE_NACK,
    encryption = false
  })
  common.getMobileSession():ExpectHandshakeMessage()
  :Times(0)
  local function ptUpdate(pTbl)
    pTbl.policy_table.module_config.certificate = nil
  end
  common.policyTableUpdateSuccess(ptUpdate)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Init SDL certificates", common.initSDLCertificates, { "./files/Security/client_credential_expired.pem" })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Test")
runner.Step("Register App", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("Switch RPC Service to Protected mode NACK", startServiceSecuredNACK)

runner.Title("Postconditions")
runner.Step("Stop SDL, clean-up certificates", common.postconditions)
