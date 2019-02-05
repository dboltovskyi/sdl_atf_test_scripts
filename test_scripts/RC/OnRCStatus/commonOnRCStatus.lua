---------------------------------------------------------------------------------------------------
-- OnRCStatus common module
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local commonRC = require('test_scripts/RC/commonRC')
local utils = require("user_modules/utils")

--[[ Common Variables ]]
commonRC.wait = utils.wait
commonRC.cloneTable = utils.cloneTable

--[[ Common Functions ]]
function commonRC.getModules()
  return { "RADIO", "CLIMATE" }
end

function commonRC.getAllModules()
  return { "RADIO", "CLIMATE", "SEAT", "AUDIO", "LIGHT", "HMI_SETTINGS" }
end

function commonRC.getModulesArray(pModules)
  local out = {}
  for _, mod in pairs(pModules) do
    table.insert(out, { moduleType = mod })
  end
  return out
end

function commonRC.getHMIAppIdsRC()
  local out = {}
  for appID, hmiAppId in pairs(commonRC.getHMIAppIds()) do
    for i = 1, 5 do
      local params = config["application" .. i].registerAppInterfaceParams
      if params.fullAppID == appID and params.appHMIType[1] == "REMOTE_CONTROL" then
        table.insert(out, hmiAppId)
      end
    end
  end
  return out
end

function commonRC.registerRCApplication(pAppId, pAllowed)
  if not pAppId then pAppId = 1 end
  if pAllowed == nil then pAllowed = true end
  local freeModulesArray = {}
  if true == pAllowed then
    freeModulesArray = commonRC.getModulesArray(commonRC.getAllModules())
  end
  local pModuleStatusForApp = {
    freeModules = freeModulesArray,
    allocatedModules = { },
    allowed = pAllowed
  }
  commonRC.registerAppWOPTU(pAppId)
  commonRC.validateOnRCStatusForApp(pAppId, pModuleStatusForApp)
  EXPECT_HMICALL("RC.OnRCStatus")
  :Times(0)
end

local function setAllocationState(pAllocArrays, pAllocApp, pModule)
  for i=1,#pAllocArrays do
    for key, value in pairs(pAllocArrays[i]) do
      if pModule == value then
        table.remove(pAllocArrays[i], key)
      end
    end
  end
  table.insert(pAllocArrays[pAllocApp], pModule)
end

function commonRC.setModuleStatus(pFreeMod, pAllocatedMod, pModule, pAllocApp)
  if not pAllocApp then pAllocApp = 1 end
  local modulesStatusAllocatedApp = { }
  local modulesStatusAnotherApp = { }
  setAllocationState(pAllocatedMod, pAllocApp, pModule)
  for key, value in pairs(pFreeMod) do
    if pModule == value then
      table.remove(pFreeMod, key)
    end
  end
  modulesStatusAllocatedApp.freeModules = commonRC.getModulesArray(pFreeMod)
  modulesStatusAnotherApp.freeModules = commonRC.getModulesArray(pFreeMod)
  modulesStatusAllocatedApp.allocatedModules = commonRC.getModulesArray(pAllocatedMod[pAllocApp])
  if 1 == pAllocApp then
    modulesStatusAnotherApp.allocatedModules = pAllocatedMod[2]
  else
    modulesStatusAnotherApp.allocatedModules = pAllocatedMod[1]
  end
  return modulesStatusAllocatedApp, modulesStatusAnotherApp
end

function commonRC.setModuleStatusByDeallocation(pFreeMod, pAllocatedMod, pModule, pRemoveAllocFromApp)
  if not pRemoveAllocFromApp then pRemoveAllocFromApp = 1 end
  local modulesStatusAllocatedApp = { }
  local modulesStatusAnotherApp = { }
  table.insert(pFreeMod, pModule)
  for key, value in pairs(pAllocatedMod[pRemoveAllocFromApp]) do
    if pModule == value then
      table.remove(pAllocatedMod[pRemoveAllocFromApp], key)
    end
  end
  modulesStatusAllocatedApp.freeModules = commonRC.getModulesArray(pFreeMod)
  modulesStatusAnotherApp.freeModules = commonRC.getModulesArray(pFreeMod)
  modulesStatusAllocatedApp.allocatedModules = commonRC.getModulesArray(pAllocatedMod[pRemoveAllocFromApp])
  if 1 == pRemoveAllocFromApp then
    modulesStatusAnotherApp.allocatedModules = pAllocatedMod[2]
  else
    modulesStatusAnotherApp.allocatedModules = pAllocatedMod[1]
  end
  return modulesStatusAllocatedApp, modulesStatusAnotherApp
end

function commonRC.closeSession(pAppId)
  if not pAppId then pAppId = 1 end
  commonRC.deleteHMIAppId(pAppId)
  commonRC.getMobileSession(pAppId):Stop()
end

function commonRC.sortModules(pModulesArray)
  local function f(a, b)
    if a.moduleType and b.moduleType then
      return a.moduleType < b.moduleType
    elseif a and b then
      return a < b
    end
    return 0
  end
  table.sort(pModulesArray, f)
end

function commonRC.validateOnRCStatusForApp(pAppId, pExpData)
 local ExpData = commonRC.cloneTable(pExpData)
 if ExpData.allowed == nil then ExpData.allowed = true end
 commonRC.getMobileSession(pAppId):ExpectNotification("OnRCStatus")
 :ValidIf(function(_, d)
     commonRC.sortModules(ExpData.freeModules)
     commonRC.sortModules(ExpData.allocatedModules)
     commonRC.sortModules(d.payload.freeModules)
     commonRC.sortModules(d.payload.allocatedModules)
     return compareValues(ExpData, d.payload, "payload")
   end)
 :ValidIf(function(_, d)
   if d.payload.allowed == nil  then
     return false, "RC.OnRCStatus notification doesn't contains 'allowed' parameter"
   end
   return true
 end)
end

function commonRC.validateOnRCStatusForHMI(pCountOfRCApps, pExpData, pAllocApp)
  local usedHmiAppIds = { }
  EXPECT_HMINOTIFICATION("RC.OnRCStatus")
  :ValidIf(function(_, d)
      commonRC.sortModules(d.params.freeModules)
      commonRC.sortModules(d.params.allocatedModules)
      for i=1,#pExpData do
        commonRC.sortModules(pExpData[i].freeModules)
        commonRC.sortModules(pExpData[i].allocatedModules)
      end
      local AnotherApp
      if pAllocApp and pAllocApp == 1 then
        AnotherApp = 2
      else
        AnotherApp = 1
      end
      if d.params.appID == commonRC.getHMIAppId(pAllocApp) and pAllocApp then
        return compareValues(pExpData[pAllocApp], d.params, "params")
      else
        return compareValues(pExpData[AnotherApp], d.params, "params")
      end
    end)
  :ValidIf(function(_, d)
    if d.params.allowed ~= nil then
      return false, "RC.OnRCStatus notification contains unexpected 'allowed' parameter"
    end
    return true
  end)
  :ValidIf(function(e, d)
      if e.occurences == 1 then
        usedHmiAppIds = {}
      end
      local avlHmiAppIds = {}
      for _, appId in pairs(commonRC.getHMIAppIdsRC()) do
        avlHmiAppIds[appId] = true
      end
      local actAppId = d.params.appID
      if avlHmiAppIds[actAppId] and not usedHmiAppIds[actAppId] then
        usedHmiAppIds[actAppId] = true
        return true
      end
      local expAppIds = {}
      for appId in pairs(avlHmiAppIds) do
        if not usedHmiAppIds[appId] then
          table.insert(expAppIds, appId)
        end
      end
      return false, " Occurence: " .. e.occurences .. ", "
      .. "expected appID: [" .. table.concat(expAppIds, ", ") .. "], " .. "actual: " .. tostring(actAppId)
    end)
  :Times(pCountOfRCApps)
end

function commonRC.registerNonRCApp(pAppId)
  commonRC.registerAppWOPTU(pAppId)
  commonRC.getMobileSession(pAppId):ExpectNotification("OnRCStatus")
  :Times(0)
  EXPECT_HMINOTIFICATION("RC.OnRCStatus")
  :Times(0)
end

return commonRC
