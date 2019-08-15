---------------------------------------------------------------------------------------------------
-- VehicleData common module
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local actions = require("user_modules/sequences/actions")
local runner = require('user_modules/script_runner')
local utils = require("user_modules/utils")
local sdl = require("SDL")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false
config.defaultProtocolVersion = 2

--[[ Local Variables ]]
local m = {}

--[[ Shared Functions ]]
m.Title = runner.Title
m.Step = runner.Step
m.preconditions = actions.preconditions
m.postconditions = actions.postconditions
m.start = actions.start
m.activateApp = actions.activateApp
m.getMobileSession = actions.getMobileSession
m.getHMIConnection = actions.getHMIConnection
m.registerApp = actions.registerApp
m.policyTableUpdate = actions.policyTableUpdate
m.getConfigAppParams = actions.getConfigAppParams
m.wait = utils.wait
m.extendedPolicy = sdl.buildOptions.extendedPolicy

--[[ Common Functions ]]
function m.ptUpdate(pTbl)
  pTbl.policy_table.app_policies[m.getConfigAppParams().fullAppID].groups = { "Base-4", "Emergency-1" }
  local grp = pTbl.policy_table.functional_groupings["Emergency-1"]
  for _, v in pairs(grp.rpcs) do
    v.parameters = {
      "engineOilLife",
      "fuelRange",
      "tirePressure",
      "electronicParkBrakeStatus",
      "turnSignal",
      "gps",
      "deviceStatus"
    }
  end
end

function m.ptUpdateMin(pTbl)
  pTbl.policy_table.app_policies[m.getConfigAppParams().fullAppID].groups = { "Base-4", "Emergency-1" }
  local grp = pTbl.policy_table.functional_groupings["Emergency-1"]
  for _, v in pairs(grp.rpcs) do
    v.parameters = {
      "gps"
    }
  end
end

return m
