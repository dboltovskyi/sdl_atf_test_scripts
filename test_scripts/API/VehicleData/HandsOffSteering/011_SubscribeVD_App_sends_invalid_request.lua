---------------------------------------------------------------------------------------------------
-- Proposal:https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0257-New-vehicle-data-HandsOffSteering.md
--
-- Description: Check that SDL responds with resultCode "INVALID_DATA" to SubscribeVehicleData request if App sends
-- request with invalid data
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) RPC SubscribeVehicleData and handsOffSteering parameter are allowed by policies
-- 3) App is registered
--
-- In case:
-- 1) App sends invalid SubscribeVehicleData(handsOffSteering=123) request to SDL
-- SDL does:
-- - a) send SubscribeVehicleData response with (success = false, resultCode = "INVALID_DATA") to App
-- - b) not transfer this request to HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/API/VehicleData/HandsOffSteering/common')

--[[ Local Variables ]]
local rpc = "SubscribeVehicleData"
local result = "INVALID_DATA"
local invalidData = 123

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment and update preloaded_pt file", common.preconditions)
common.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
common.Step("Register App", common.registerApp)

common.Title("Test")
common.Step("RPC SubscribeVehicleData, App sends invalid request",
  common.processRPCFailure, { rpc, result, invalidData })

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)