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

local function unregisterApp()
  local cid = common.getMobileSession():SendRPC("UnregisterAppInterface", {})
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppUnregistered")
end

local function registerApp()
  local cid = common.getMobileSession():SendRPC("RegisterAppInterface", common.getConfigAppParams())
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppRegistered")
  common.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate")
  :Times(0)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Init SDL certificates", common.initSDLCertificates, { "./files/Security/client_credential.pem" })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Test")
runner.Step("Register App", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("Disconnect App", unregisterApp)
runner.Step("Connect App PTU is not started", registerApp)

runner.Title("Postconditions")
runner.Step("Stop SDL, clean-up certificates", common.postconditions)
