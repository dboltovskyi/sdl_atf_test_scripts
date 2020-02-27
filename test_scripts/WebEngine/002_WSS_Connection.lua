---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0240-sdl-js-pwa.md
--
-- Description:
-- Successfully registering the Web application over the WebSocket-Secure connection
--
-- Precondition:
-- 1. SDL and HMI are started
--
-- Sequence:
-- 1. Create WebSocket-Secure connection
--  a. SDL successfully established a  WebSocket-Secure  connection
-- 2. Register the Web application
--  a. Web application is registered successfully
-- 3. Activate the Web application
--  a. Web application is activated successfully on the HMI and it has FULL level
---------------------------------------------------------------------------------------------------
--[[ General test configuration ]]
config.defaultMobileAdapterType = "WSS"

--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/WebEngine/commonWebEngine')

--[[ General configuration parameters ]]
runner.testSettings.isSelfIncluded = false
runner.testSettings.restrictions.sdlBuildOptions = {{webSocketServerSupport = {"ON"}}}

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Add certificates for WS Server in smartDeviceLink.ini file", common.addAllCertInIniFile)
runner.Step("Start SDL, HMI, connect regular mobile, start Session", common.startWOdeviceConnect)

runner.Title("Test")
runner.Step("Connect WebEngine device", common.connectWebEngine, { 1, config.defaultMobileAdapterType })
runner.Step("RAI of web app", common.registerApp, { 1, 1 })
runner.Step("Activate web app", common.activateApp, { 1 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
