---------------------------------------------------------------------------------------------------
-- 1. EmbeddedServices = MEDIA
-- 2. Publish App service MEDIA => published, activated
-- 2. Publish Embedded service MEDIA =>
--    - app: deactivated
--    - embedded: published, activated
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/AppServices/commonAppServices')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function PTUfunc(tbl)
  tbl.policy_table.app_policies[common.getConfigAppParams(1).fullAppID] = common.getAppServiceProducerConfig(1)
end

local function getExpSysCapData(...)
  local out = {
    systemCapability = {
      appServicesCapabilities = {
        appServices = { }
      },
      systemCapabilityType = "APP_SERVICES"
    }
  }
  for i, p in pairs({...}) do
    out.systemCapability.appServicesCapabilities.appServices[i] = {
      updateReason = p.reason,
        updatedAppServiceRecord = {
        serviceActive = p.isActive,
        servicePublished = true
      }
    }
  end
  return out
end

local function publishAppService(pAppID)
  local manifest = {
    serviceName = config["application" .. pAppID].registerAppInterfaceParams.appName,
    serviceType = "MEDIA",
    allowAppConsumers = true,
    rpcSpecVersion = config["application" .. pAppID].registerAppInterfaceParams.syncMsgVersion,
    mediaServiceManifest = {}
  }
  local cid = common.getMobileSession(pAppID):SendRPC("PublishAppService", { appServiceManifest = manifest })
  common.getMobileSession(pAppID):ExpectResponse(cid, {
    appServiceRecord = {
      serviceManifest = manifest,
      servicePublished = true,
      serviceActive = true
    },
    success = true,
    resultCode = "SUCCESS"
  })

  local exp1 = getExpSysCapData({ reason = "PUBLISHED", isActive = false })
  local exp2 = getExpSysCapData({ reason = "ACTIVATED", isActive = true })

  common.getMobileSession():ExpectNotification("OnSystemCapabilityUpdated", exp1, exp2)
  :Times(2)
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnSystemCapabilityUpdated", exp1, exp2)
  :Times(2)
end

local function publishEmbeddedService()
  local manifest = {
    serviceName = "HMI_MEDIA",
    serviceType = "MEDIA",
    allowAppConsumers = true,
    rpcSpecVersion = config.application1.registerAppInterfaceParams.syncMsgVersion,
    mediaServiceManifest = {}
  }
  local cid = common.getHMIConnection():SendRequest("AppService.PublishAppService", { appServiceManifest = manifest })
  common.getHMIConnection():ExpectResponse(cid, {
    result = {
      appServiceRecord = {
        serviceManifest = manifest,
        servicePublished = true,
        serviceActive = true -- embedded service is activated automatically
      },
      code = 0,
      method = "AppService.PublishAppService"
    }
  })

  local exp1 = getExpSysCapData({ reason = nil, isActive = true }, { reason = "PUBLISHED", isActive = false })
  local exp2 = getExpSysCapData({ reason = "DEACTIVATED", isActive = false }, { reason = "ACTIVATED", isActive = true })

  common.getMobileSession():ExpectNotification("OnSystemCapabilityUpdated", exp1, exp2)
  :Times(2)
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnSystemCapabilityUpdated", exp1, exp2)
  :Times(2)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Set EmbeddedServices parameter to MEDIA", common.setSDLIniParameter, { "EmbeddedServices", "MEDIA" })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Test")

runner.Step("RAI 1", common.registerApp, { 1 })
runner.Step("PTU", common.policyTableUpdate, { PTUfunc })
runner.Step("Publish App 1 Service MEDIA", publishAppService, { 1 })

runner.Step("Publish Embedded Service MEDIA_active", publishEmbeddedService)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
