---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0266-New-vehicle-data-GearStatus.md
--
-- Description: Check that SDL rejects SubscribeVehicleData request with resultCode "IGNORED" in case
--  app is already subscribed to 'gearStatus' data
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) App is registered
-- 3) App is subscribed to 'gearStatus' data
--
-- In case:
-- 1) App sends valid SubscribeVehicleData(gearStatus=true) request to SDL
-- SDL does:
-- - a) send SubscribeVehicleData response with (success = false, resultCode = "IGNORED") to App
-- - b) not transfer this request to HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/API/VehicleData/GearStatus/common')

--[[ Local Variables ]]
local rpc = "SubscribeVehicleData"
local result = "IGNORED"

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment and update preloaded_pt file", common.preconditions)
common.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
common.Step("Register App", common.registerApp)
common.Step("App subscribes to gearStatus parameter", common.processSubscriptionRPC, { rpc })

common.Title("Test")
common.Step("RPC " .. rpc .. " with gearStatus parameter IGNORED",
  common.processRPCFailure, { rpc, result })

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
