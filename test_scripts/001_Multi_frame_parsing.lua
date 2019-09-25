---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("user_modules/sequences/actions")
local utils = require("user_modules/utils")
local constants = require('protocol_handler/ford_protocol_constants')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false
config.defaultProtocolVersion = 2
constants.FRAME_SIZE["P2"] = 100

local appConfig = utils.cloneTable(config.application1)

for appId = 1, 10 do
  config["application" ..appId] = utils.cloneTable(appConfig)
  config["application" ..appId].registerAppInterfaceParams.appHMIType = { "REMOTE_CONTROL" }
  config["application" ..appId].registerAppInterfaceParams.appName = "App" .. appId
  config["application" ..appId].registerAppInterfaceParams.appID = "000" .. appId
  config["application" ..appId].registerAppInterfaceParams.fullAppID = "000000" .. appId
end

--[[ Local Functions ]]
local function getConfig(pTbl)
  local out = utils.cloneTable(pTbl.policy_table.app_policies.default)
  out.moduleType = { "RADIO", "CLIMATE", "SEAT", "AUDIO", "LIGHT", "HMI_SETTINGS" }
  out.groups = { "Base-4", "RemoteControl" }
  out.AppHMIType = { "REMOTE_CONTROL" }
  return out
end

local function ptUpdate(pTbl)
  for appId = 1, 10 do
    pTbl.policy_table.app_policies[common.app.getParams(appId).fullAppID] = getConfig(pTbl)
  end
end

local function getCaps(pAppId)
   local cid = common.getMobileSession(pAppId):SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
   common.getMobileSession(pAppId):ExpectResponse(cid)
end

local function getCapsManyApps()
  local cid = {}
  for appId = 2, 10 do
    cid[appId] = common.getMobileSession(appId):SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
    common.getMobileSession(appId):ExpectResponse(cid[appId], { success = true })
  end
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Test")

local apps = { 1,2,3,4,5,6,7,8,9 }
for _, appId in ipairs(apps) do
  runner.Step("Register App " .. appId, common.app.registerNoPTU, { appId })
end
runner.Step("Activate App 1", common.app.activate, { 1 })

runner.Step("Register App 10", common.app.register, { 10 })
runner.Step("PTU", common.ptu.policyTableUpdate, { ptUpdate })

-- for _, appId in ipairs(apps) do
-- runner.Step("Get capabilities " .. appId, getCaps, { appId })
-- runner.Step("Get capabilities " .. appId, getCaps, { appId })
-- runner.Step("Get capabilities " .. appId, getCaps, { appId })
-- end

for _ = 1, 1 do
  runner.Step("Get capabilities", getCapsManyApps)
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
