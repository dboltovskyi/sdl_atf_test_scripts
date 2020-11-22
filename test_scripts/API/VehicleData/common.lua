---------------------------------------------------------------------------------------------------
-- Common module
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local actions = require("user_modules/sequences/actions")
local runner = require('user_modules/script_runner')
local utils = require("user_modules/utils")
local json = require("modules/json")
local SDL = require("SDL")
local color = require("user_modules/consts").color
local ah = require("user_modules/api/APIHelper")
local tdg = require("user_modules/api/APITestDataGenerator")

--[[ General configuration parameters ]]
runner.testSettings.isSelfIncluded = false
config.defaultProtocolVersion = 2
config.zeroOccurrenceTimeout = 1000

--[[ Local Variables ]]
local m = {}
local hashId = {}
local isSubscribed = {}

--[[ Common Proxy Functions ]]
do
  m.Title = runner.Title
  m.Step = runner.Step
  m.getPreloadedPT = actions.sdl.getPreloadedPT
  m.setPreloadedPT = actions.sdl.setPreloadedPT
  m.registerApp = actions.app.register
  m.registerAppWOPTU = actions.app.registerNoPTU
  m.activateApp = actions.app.activate
  m.getMobileSession = actions.getMobileSession
  m.getHMIConnection = actions.hmi.getConnection
  m.getAppParams = actions.app.getParams
  m.getConfigAppParams = actions.app.getParams
  m.cloneTable = utils.cloneTable
  m.start = actions.start
  m.postconditions = actions.postconditions
  m.policyTableUpdate = actions.policyTableUpdate
  m.connectMobile = actions.mobile.connect
  m.wait = utils.wait
  m.spairs = utils.spairs
  m.cprint = utils.cprint
  m.json = actions.json
  m.getKeyByValue = utils.getKeyByValue
  m.getTableSize = utils.getTableSize
end

--[[ Common Variables ]]
m.rpc = {
  get = "GetVehicleData",
  sub = "SubscribeVehicleData",
  unsub = "UnsubscribeVehicleData",
  on = "OnVehicleData"
}

m.rpcHMIMap = {
  [m.rpc.get] = "VehicleInfo.GetVehicleData",
  [m.rpc.sub] = "VehicleInfo.SubscribeVehicleData",
  [m.rpc.unsub] = "VehicleInfo.UnsubscribeVehicleData",
  [m.rpc.on] = "VehicleInfo.OnVehicleData"
}

m.vd = {
  vin = "",
  gps = "VEHICLEDATA_GPS",
  speed = "VEHICLEDATA_SPEED",
  rpm = "VEHICLEDATA_RPM",
  fuelLevel = "VEHICLEDATA_FUELLEVEL",
  fuelLevel_State = "VEHICLEDATA_FUELLEVEL_STATE",
  instantFuelConsumption = "VEHICLEDATA_FUELCONSUMPTION",
  externalTemperature = "VEHICLEDATA_EXTERNTEMP",
  prndl = "VEHICLEDATA_PRNDL",
  tirePressure = "VEHICLEDATA_TIREPRESSURE",
  odometer = "VEHICLEDATA_ODOMETER",
  beltStatus = "VEHICLEDATA_BELTSTATUS",
  bodyInformation = "VEHICLEDATA_BODYINFO",
  deviceStatus = "VEHICLEDATA_DEVICESTATUS",
  eCallInfo = "VEHICLEDATA_ECALLINFO",
  airbagStatus = "VEHICLEDATA_AIRBAGSTATUS",
  emergencyEvent = "VEHICLEDATA_EMERGENCYEVENT",
  -- clusterModeStatus = "VEHICLEDATA_CLUSTERMODESTATUS", -- disabled due to issue: https://github.com/smartdevicelink/sdl_core/issues/3460
  myKey = "VEHICLEDATA_MYKEY",
  driverBraking = "VEHICLEDATA_BRAKING",
  wiperStatus = "VEHICLEDATA_WIPERSTATUS",
  headLampStatus = "VEHICLEDATA_HEADLAMPSTATUS",
  engineTorque = "VEHICLEDATA_ENGINETORQUE",
  accPedalPosition = "VEHICLEDATA_ACCPEDAL",
  steeringWheelAngle = "VEHICLEDATA_STEERINGWHEEL",
  turnSignal = "VEHICLEDATA_TURNSIGNAL",
  fuelRange = "VEHICLEDATA_FUELRANGE",
  engineOilLife = "VEHICLEDATA_ENGINEOILLIFE",
  electronicParkBrakeStatus = "VEHICLEDATA_ELECTRONICPARKBRAKESTATUS",
  cloudAppVehicleID = "VEHICLEDATA_CLOUDAPPVEHICLEID",
  handsOffSteering = "VEHICLEDATA_HANDSOFFSTEERING",
  stabilityControlsStatus = "VEHICLEDATA_STABILITYCONTROLSSTATUS",
  gearStatus = "VEHICLEDATA_GEARSTATUS",
  windowStatus = "VEHICLEDATA_WINDOWSTATUS"
}

m.operator = {
  increase = 1,
  decrease = -1
}

m.app = {
  [1] = 1,
  [2] = 2
}
m.isExpected = 1
m.isNotExpected = 0
m.isExpectedSubscription = true
m.isNotExpectedSubscription = false

m.testType = {
  VALID_RANDOM = 1,
  MANDATORY_ONLY = 2,
  UPPER_IN_BOUND = 3,
  LOWER_IN_BOUND = 4,
  UPPER_OUT_OF_BOUND = 5,
  LOWER_OUT_OF_BOUND = 6,
  ENUM_ITEMS = 7,
  BOOL_ITEMS = 8,
  PARAM_VERSION = 9,
  VALID_RANDOM_ALL = 10,
  MANDATORY_MISSING = 11
}

m.isMandatory = {
  YES = true,
  NO = false,
  ALL = 3
}

m.isArray = {
  YES = true,
  NO = false,
  ALL = 3
}

m.isVersion = {
  YES = true,
  NO = false,
  ALL = 3
}

--[[ Common Functions ]]

--[[ @getAvailableVDParams: Return available for processing VD parameters
--! @parameters: none
--! @return: none
--]]
local function getAvailableVDParams()
  local graph = ah.getGraph(ah.apiType.MOBILE, ah.eventType.REQUEST, m.rpc.get)
  local vdParams = {}
  for _, data in pairs(graph) do
    if data.parentId == nil then vdParams[data.name] = true end
  end
  -- print not defined in API parameters
  for k in pairs(m.vd) do
    if vdParams[k] == nil then
      m.cprint(color.magenta, "Not found in API VD parameter:", k)
    end
  end
  -- remove disabled parameters
  for k in pairs(vdParams) do
    if m.vd[k] == nil then
      vdParams[k] = nil
      m.cprint(color.magenta, "Disabled VD parameter:", k)
    end
  end
  return vdParams
end

local vdParams = getAvailableVDParams()

--[[ @updatePreloadedPTFile: Update preloaded file with additional permissions
--! @parameters:
--! pGroup: table with additional updates (optional)
--! @return: none
--]]
local function updatePreloadedPTFile(pGroup)
  local params = { }
  for param in pairs(m.vd) do
    table.insert(params, param)
  end
  local rpcs = { "GetVehicleData", "OnVehicleData", "SubscribeVehicleData", "UnsubscribeVehicleData" }
  local levels = { "NONE", "BACKGROUND", "LIMITED", "FULL" }
  local pt = actions.sdl.getPreloadedPT()
  if not pGroup then
    pGroup = {
      rpcs = {}
    }
    for _, rpc in pairs(rpcs) do
      pGroup.rpcs[rpc] = {
        hmi_levels = levels,
        parameters = params
      }
    end
  end
  pt.policy_table.functional_groupings["VDGroup"] = pGroup
  pt.policy_table.app_policies["default"].groups = { "Base-4", "VDGroup" }
  pt.policy_table.functional_groupings["DataConsent-2"].rpcs = json.null
  actions.sdl.setPreloadedPT(pt)
end

--[[ @preconditions: Clean environment, optional backup and update of sdl_preloaded_pt.json file
--! @parameters:
--! pGroup: data for updating sdl_preloaded_pt.json file
--! @return: none
--]]
function m.preconditions(pGroup)
  actions.preconditions()
  updatePreloadedPTFile(pGroup)
end

--[[ @setHashId: Set hashId value which is required during resumption
--! @parameters:
--! pHashValue: application hashId
--! pAppId: application number (1, 2, etc.)
--! @return: none
--]]
function m.setHashId(pHashValue, pAppId)
  hashId[pAppId] = pHashValue
end

--[[ @getHashId: Get hashId value of an app which is required during resumption
--! @parameters:
--! pAppId: application number (1, 2, etc.)
--! @return: app's hashId
--]]
function m.getHashId(pAppId)
  return hashId[pAppId]
end

function m.isSubscribable(pParam)
  if m.vd[pParam] ~= "" then return true end
  return false
end

--[[ @getVDParams: Return VD parameters and values
--! @parameters:
--! pIsSubscribable: true if parameter is available for subscription, otherwise - false
--! @return: table with VD parameters and values
--]]
function m.getVDParams(pIsSubscribable)
  if pIsSubscribable == nil then return vdParams end
  local out = {}
  for param in pairs(m.vd) do
    if pIsSubscribable == m.isSubscribable(param) then out[param] = true end
  end
  return out
end

--[[ @getVehicleData: Successful processing of GetVehicleData RPC
--! @parameters:
--! pParam: name of the VD parameter
--! pValue: data for HMI response
--! @return: none
--]]
function m.getVehicleData(pParam, pValue)
  if pValue == nil then pValue = m.vdValues[pParam] end
  local cid = m.getMobileSession():SendRPC("GetVehicleData", { [pParam] = true })
  m.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData", { [pParam] = true })
  :Do(function(_, data)
    m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { [pParam] = pValue })
  end)
  m.getMobileSession():ExpectResponse(cid,
    { success = true, resultCode = "SUCCESS", [pParam] = pValue })
end

--[[ @processRPCFailure: Processing VehicleData RPC with ERROR resultCode
--! @parameters:
--! pRPC: RPC for mobile request
--! pParam: name of the VD parameter
--! pResult: expected result code
--! pRequestValue: data for App request
--! @return: none
--]]
function m.processRPCFailure(pRPC, pParam, pResult, pRequestValue)
  if pRequestValue == nil then pRequestValue = true end
  local cid = m.getMobileSession():SendRPC(pRPC, { [pParam] = pRequestValue })
  m.getHMIConnection():ExpectRequest("VehicleInfo." .. pRPC):Times(0)
  m.getMobileSession():ExpectResponse(cid, { success = false, resultCode = pResult })
end

--[[ @processRPCgenericError: Processing VehicleData RPC with invalid HMI response
--! @parameters:
--! pRPC: RPC for mobile request
--! pParam: name of the VD parameter
--! pValue: data for HMI response
--! @return: none
--]]
function m.processRPCgenericError(pRPC, pParam, pValue)
  local cid = m.getMobileSession():SendRPC(pRPC, { [pParam] = true })
  m.getHMIConnection():ExpectRequest("VehicleInfo." .. pRPC, { [pParam] = true })
  :Do(function(_,data)
    m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { [pParam] = pValue })
  end)
  m.getMobileSession():ExpectResponse(cid, { success = false, resultCode = "GENERIC_ERROR" })
end

--[[ @getInvalidData: Return invalid value bases on valid one
--! @parameters:
--! pData: valid value
--! @return: invalid value
--]]
function m.getInvalidData(pData)
  if type(pData) == "boolean" then return 123 end
  if type(pData) == "number" then return true end
  if type(pData) == "string" then return false end
  if type(pData) == "table" then
    for k, v in pairs(pData) do
      pData[k] = m.getInvalidData(v)
    end
    return pData
  end
end

--[[ @processSubscriptionRPC: Processing SubscribeVehicleData and UnsubscribeVehicleData RPCs
--! @parameters:
--! pRPC: RPC for mobile request
--! pParam: name of the VD parameter
--! pAppId: application number (1, 2, etc.)
--! isRequestOnHMIExpected: if true or omitted VI.Sub/UnsubscribeVehicleData request is expected on HMI,
--!   otherwise - not expected
--! @return: none
--]]
function m.processSubscriptionRPC(pRPC, pParam, pAppId, isRequestOnHMIExpected)
  if pAppId == nil then pAppId = 1 end
  if isRequestOnHMIExpected == nil then isRequestOnHMIExpected = true end
  local response = {
    dataType = m.vd[pParam],
    resultCode = "SUCCESS"
  }
  local responseParam = pParam
  if pParam == "clusterModeStatus" then responseParam = "clusterModes" end
  local cid = m.getMobileSession(pAppId):SendRPC(pRPC, { [pParam] = true })
  if isRequestOnHMIExpected == true then
    m.getHMIConnection():ExpectRequest("VehicleInfo." .. pRPC, { [pParam] = true })
    :Do(function(_,data)
      m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { [responseParam] = response })
    end)
  else
    m.getHMIConnection():ExpectRequest("VehicleInfo." .. pRPC):Times(0)
  end
  m.getMobileSession(pAppId):ExpectResponse(cid,
    { success = true, resultCode = "SUCCESS", [responseParam] = response })
  local ret = m.getMobileSession(pAppId):ExpectNotification("OnHashChange")
  :Do(function(_, data)
    m.setHashId(data.payload.hashID, pAppId)
  end)
  return ret
end

--[[ @sendOnVehicleData: Processing OnVehicleData RPC
--! @parameters:
--! pParam: name of the VD parameter
--! pExpTime: number of notifications (0, 1 or more)
--! pValue: data for the notification
--! @return: none
--]]
function m.sendOnVehicleData(pParam, pExpTime, pValue)
  if pExpTime == nil then pExpTime = 1 end
  if pValue == nil then pValue = m.vdValues[pParam] end
  m.getHMIConnection():SendNotification("VehicleInfo.OnVehicleData", { [pParam] = pValue })
  m.getMobileSession():ExpectNotification("OnVehicleData", { [pParam] = pValue })
  :Times(pExpTime)
end

--[[ @sendOnVehicleDataTwoApps: Processing OnVehicleData RPC for two apps
--! @parameters:
--! pParam: name of the VD parameter
--! pExpTimesApp1: number of notifications for 1st app
--! pExpTimesApp2: number of notifications for 2nd app
--! @return: none
--]]
function m.sendOnVehicleDataTwoApps(pParam, pExpTimesApp1, pExpTimesApp2)
  local value = m.vdValues[pParam]
  m.getHMIConnection():SendNotification("VehicleInfo.OnVehicleData", { [pParam] = value })
  m.getMobileSession(1):ExpectNotification("OnVehicleData", { [pParam] = value })
  :Times(pExpTimesApp1)
  m.getMobileSession(2):ExpectNotification("OnVehicleData", { [pParam] = value })
  :Times(pExpTimesApp2)
end

--[[ @unexpectedDisconnect: Unexpected disconnect sequence
--! @parameters:
--! pParam: name of the VD parameter
--! @return: none
--]]
function m.unexpectedDisconnect(pParam)
  m.getHMIConnection():ExpectNotification("BasicCommunication.OnAppUnregistered", { unexpectedDisconnect = true })
  :Times(actions.mobile.getAppsCount())
  if pParam then
    m.getHMIConnection():ExpectRequest("VehicleInfo.UnsubscribeVehicleData", { [pParam] = true })
  end
  actions.mobile.disconnect()
  utils.wait(1000)
end

--[[ @ignitionOff: Ignition Off sequence
--! @parameters:
--! pParam: name of the VD parameter
--! @return: none
--]]
function m.ignitionOff(pParam)
  local isOnSDLCloseSent = false
  m.getHMIConnection():SendNotification("BasicCommunication.OnExitAllApplications", { reason = "SUSPEND" })
  m.getHMIConnection():ExpectNotification("BasicCommunication.OnSDLPersistenceComplete")
  :Do(function()
    m.getHMIConnection():ExpectRequest("VehicleInfo.UnsubscribeVehicleData", { [pParam] = true })
    m.getHMIConnection():SendNotification("BasicCommunication.OnExitAllApplications", { reason = "IGNITION_OFF" })
    m.getHMIConnection():ExpectNotification("BasicCommunication.OnSDLClose")
    :Do(function()
      isOnSDLCloseSent = true
      SDL.DeleteFile()
    end)
  end)
  m.wait(3000)
  :Do(function()
    if isOnSDLCloseSent == false then m.cprint(color.magenta, "BC.OnSDLClose was not sent") end
    for i = 1, actions.mobile.getAppsCount() do
      actions.mobile.deleteSession(i)
    end
    StopSDL()
  end)
end

--[[ @registerAppWithResumption: Successful app registration with resumption
--! @parameters:
--! pParam: name of the VD parameter
--! pAppId: application number (1, 2, etc.)
--! isRequestOnHMIExpected: if true VD.SubscribeVehicleData request is expected on HMI, otherwise - not expected
--! @return: none
--]]
function m.registerAppWithResumption(pParam, pAppId, isRequestOnHMIExpected)
  if not pAppId then pAppId = 1 end
  local response = {
    dataType = m.vd[pParam],
    resultCode = "SUCCESS"
  }
  local responseParam = pParam
  if pParam == "clusterModeStatus" then responseParam = "clusterModes" end
  m.getMobileSession(pAppId):StartService(7)
  :Do(function()
    local appParams = utils.cloneTable(actions.app.getParams(pAppId))
    appParams.hashID = m.getHashId(pAppId)
    local corId = m.getMobileSession(pAppId):SendRPC("RegisterAppInterface", appParams)
    m.getHMIConnection():ExpectNotification("BasicCommunication.OnAppRegistered")
    :Do(function()
      if isRequestOnHMIExpected == true then
        m.getHMIConnection():ExpectRequest("VehicleInfo.SubscribeVehicleData", { [pParam] = true })
        :Do(function(_, data)
          m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { [responseParam] = response })
        end)
      else
        m.getHMIConnection():ExpectRequest("VehicleInfo.SubscribeVehicleData"):Times(0)
      end
    end)
    m.getMobileSession(pAppId):ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
    :Do(function()
      m.getMobileSession(pAppId):ExpectNotification("OnPermissionsChange")
    end)
  end)
end

--[[ @setAppVersion: Set application version based on VD parameter version
--! @parameters:
--! pParamVersion: version of the VD parameter
--! pOperator: operator to get target app version (increase or decrease)
--! @return: none
--]]
function m.setAppVersion(pParamVersion, pOperator)
  m.cprint(color.magenta, "Param version:", pParamVersion)
  local major = tonumber(utils.splitString(pParamVersion)[1], ".") or 0
  local minor = tonumber(utils.splitString(pParamVersion)[2], ".") or 0
  local patch = tonumber(utils.splitString(pParamVersion)[3], ".") or 0
  local ver = (major*100 + minor*10 + patch) + pOperator
  if ver < 450 then ver = 450 end
  ver = tostring(ver)
  major = tonumber(string.sub(ver, 1, 1))
  minor = tonumber(string.sub(ver, 2, 2))
  patch = tonumber(string.sub(ver, 3, 3))
  m.cprint(color.magenta, "App version:", major .. "." .. minor .. "." .. patch)
  actions.app.getParams().syncMsgVersion.majorVersion = major
  actions.app.getParams().syncMsgVersion.minorVersion = minor
  actions.app.getParams().syncMsgVersion.patchVersion = patch
end

--[[ Local Variables ]]-----------------------------------------------------------------------------
local rpc
local rpcType
local testType
local paramName

--[[ Local Constants ]]-----------------------------------------------------------------------------
local boundValueTypeMap = {
  [m.testType.UPPER_IN_BOUND] = tdg.valueType.UPPER_IN_BOUND,
  [m.testType.LOWER_IN_BOUND] = tdg.valueType.LOWER_IN_BOUND,
  [m.testType.UPPER_OUT_OF_BOUND] = tdg.valueType.UPPER_OUT_OF_BOUND,
  [m.testType.LOWER_OUT_OF_BOUND] = tdg.valueType.LOWER_OUT_OF_BOUND
}

--[[ Params Generator Functions ]]------------------------------------------------------------------
local function getParamsValidDataTestForRequest(pGraph)
  local request = { [paramName] = true }
  local hmiResponse = tdg.getParamValues(pGraph)
  local mobileResponse = utils.cloneTable(hmiResponse)
  mobileResponse.success = true
  mobileResponse.resultCode = "SUCCESS"
  local params = {
    mobile = {
      name = rpc,
      request = request,
      response = mobileResponse
    },
    hmi = {
      name = m.rpcHMIMap[rpc],
      request = request,
      response = hmiResponse
    }
  }
  return params
end

local function getParamsInvalidDataTestForRequest(pGraph)
  local request = { [paramName] = true }
  local hmiResponse = tdg.getParamValues(pGraph)
  local params = {
    mobile = {
      name = rpc,
      request = request,
      response = { success = false, resultCode = "GENERIC_ERROR" }
    },
    hmi = {
      name = m.rpcHMIMap[rpc],
      request = request,
      response = hmiResponse
    }
  }
  return params
end

local function getParamsAnyDataTestForNotification(pGraph)
  local notification = tdg.getParamValues(pGraph)
  local params = {
    mobile = {
      name = rpc,
      notification = { [paramName] = notification[paramName] }
    },
    hmi = {
      name = m.rpcHMIMap[rpc],
      notification = { [paramName] = notification[paramName] }
    }
  }
  return params
end

local getParamsFuncMap = {
  VALID = {
   [ah.eventType.RESPONSE] = getParamsValidDataTestForRequest,
   [ah.eventType.NOTIFICATION] = getParamsAnyDataTestForNotification
  },
  INVALID = {
   [ah.eventType.RESPONSE] = getParamsInvalidDataTestForRequest,
   [ah.eventType.NOTIFICATION] = getParamsAnyDataTestForNotification
  }
}

--[[ Test Cases Generator Function ]]---------------------------------------------------------------
local function createTestCases(pAPIType, pFuncType, pFuncName, pIsMandatory, pIsArray, pIsVersion, pDataTypes)

  local graph = ah.getGraph(pAPIType, pFuncType, pFuncName)

  local function getParents(pGraph, pId)
    local out = {}
    pId = pGraph[pId].parentId
    while pId do
      out[pId] = true
      pId = pGraph[pId].parentId
    end
    return out
  end

  local function getMandatoryNeighbors(pGraph, pId, pParentIds)
    local pIds = utils.cloneTable(pParentIds)
    pIds[pId] = true
    local out = {}
    for p in pairs(pIds) do
      for k, v in pairs(pGraph) do
        if v.parentId == pGraph[p].parentId and v.mandatory and p ~= k then
          out[k] = true
        end
      end
    end
    return out
  end

  local function getMandatoryChildren(pGraph, pId, pChildreIds)
    for k, v in pairs(pGraph) do
      if v.parentId == pId and v.mandatory then
        pChildreIds[k] = true
        getMandatoryChildren(pGraph, k, pChildreIds)
      end
    end
    return pChildreIds
  end

  local function getTCParamsIds(pId, ...)
    local ids = {}
    ids[pId] = true
    for _, arg in pairs({...}) do
      if type(arg) == "table" then
        for p in pairs(arg) do
          ids[p] = true
        end
      end
    end
    return ids
  end

  local function getUpdatedParams(pGraph, pParamIds)
    for k in pairs(pGraph) do
      if not pParamIds[k] then
        pGraph[k] = nil
      end
    end
    return pGraph
  end

  local function getTestCases(pGraph)
    local function getMandatoryCondition(pMandatory)
      if pIsMandatory == m.isMandatory.ALL then return true
      else return pIsMandatory == pMandatory
      end
    end
    local function getArrayCondition(pArray)
      if pIsArray == m.isArray.ALL then return true
      else return pIsArray == pArray
      end
    end
    local function getVersionCondition(pSince, pDeprecated)
      if pIsVersion == m.isVersion.ALL then return true end
      if pSince ~= nil and pDeprecated ~= true then return true end
      return false
    end
    local function getTypeCondition(pType)
      if pDataTypes == nil or #pDataTypes == 0 then return true
      elseif utils.tableContains(pDataTypes, pType) then return true
      else return false
      end
    end
    local function getParamNameCondition(pName)
      if paramName == nil or paramName == "" then return true end
      if (pName == paramName) or (string.find(pName .. ".", paramName .. "%.") == 1) then return true end
      return false
    end
    local tcs = {}
    for k, v in pairs(pGraph) do
      local paramFullName = ah.getFullParamName(graph, k)
      if getMandatoryCondition(v.mandatory) and getArrayCondition(v.array)
        and getTypeCondition(v.type) and getParamNameCondition(paramFullName)
        and getVersionCondition(v.since, v.deprecated) then
        local parentIds = getParents(graph, k)
        local childrenIds = getMandatoryChildren(graph, k, {})
        local neighborsIds = getMandatoryNeighbors(graph, k, parentIds)
        local neighborsChildrenIds = {}
        for id in pairs(neighborsIds) do
          getMandatoryChildren(graph, id, neighborsChildrenIds)
        end
        local tcParamIds = getTCParamsIds(k, parentIds, neighborsIds, childrenIds, neighborsChildrenIds)
        if not (v.type == ah.dataType.STRUCT.type and utils.getTableSize(childrenIds) == 0) then
          local tc = {
            paramId = k,
            graph = getUpdatedParams(utils.cloneTable(graph), tcParamIds)
          }
          table.insert(tcs, tc)
        end
      end
    end
    return tcs
  end

  local tcs = getTestCases(graph)

  return tcs
end

--[[ Tests Generator Functions ]]-------------------------------------------------------------------
local function getValidRandomTests()
  local tcs = createTestCases(ah.apiType.HMI, rpcType, m.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.ALL, m.isVersion.ALL, {})
  local tests = {}
  for _, tc in pairs(tcs) do
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
        params = getParamsFuncMap.VALID[rpcType](tc.graph),
      })
  end
  return tests
end

local function getOnlyMandatoryTests()
  local function isTCExist(pExistingTCs, pTC)
    local tc = utils.cloneTable(pTC)
    tc.paramId = nil
    for _, e in pairs(pExistingTCs) do
      local etc = utils.cloneTable(e)
      etc.paramId = nil
      if utils.isTableEqual(etc, tc) then return true end
    end
    return false
  end
  local function filterDuplicates(pTCs)
    local existingTCs = {}
    for _, tc in pairs(pTCs) do
      if not isTCExist(existingTCs, tc) then
        tc.paramId = tc.graph[tc.paramId].parentId
        table.insert(existingTCs, tc)
      end
    end
    return existingTCs
  end
  local tcs = createTestCases(ah.apiType.HMI, rpcType, m.rpcHMIMap[rpc],
    m.isMandatory.YES, m.isArray.ALL, m.isVersion.ALL, {})
  tcs = filterDuplicates(tcs)
  local tests = {}
  for _, tc in pairs(tcs) do
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
        params = getParamsFuncMap.VALID[rpcType](tc.graph),
        paramId = tc.paramId,
        graph = tc.graph
      })
  end
  return tests
end

local function getInBoundTests()
  local tests = {}
  -- tests simple data types
  local dataTypes = { ah.dataType.INTEGER.type, ah.dataType.FLOAT.type, ah.dataType.DOUBLE.type, ah.dataType.STRING.type }
  local tcs = createTestCases(ah.apiType.HMI, rpcType, m.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.ALL, m.isVersion.ALL, dataTypes)
  for _, tc in pairs(tcs) do
    tc.graph[tc.paramId].valueType = boundValueTypeMap[testType]
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
        params = getParamsFuncMap.VALID[rpcType](tc.graph),
      })
  end
  -- tests for arrays
  tcs = createTestCases(ah.apiType.HMI, rpcType, m.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.YES, m.isVersion.ALL, {})
  for _, tc in pairs(tcs) do
    tc.graph[tc.paramId].valueTypeArray = boundValueTypeMap[testType]
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_ARRAY",
        params = getParamsFuncMap.VALID[rpcType](tc.graph),
      })
  end
  return tests
end

local function getOutOfBoundTests()
  local tests = {}
  -- tests for simple data types
  local dataTypes = { ah.dataType.INTEGER.type, ah.dataType.FLOAT.type, ah.dataType.DOUBLE.type, ah.dataType.STRING.type }
  local tcs = createTestCases(ah.apiType.HMI, rpcType, m.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.ALL, m.isVersion.ALL, dataTypes)
  for _, tc in pairs(tcs) do
    local function isSkipped()
      local paramData = tc.graph[tc.paramId]
      if paramData.type == ah.dataType.STRING.type then
        if (testType == m.testType.LOWER_OUT_OF_BOUND and paramData.minlength == 0)
        or (testType == m.testType.UPPER_OUT_OF_BOUND and paramData.maxlength == nil) then
          return true
        end
      else
        if (testType == m.testType.LOWER_OUT_OF_BOUND and paramData.minvalue == nil)
        or (testType == m.testType.UPPER_OUT_OF_BOUND and paramData.maxvalue == nil) then
          return true
        end
      end
      return false
    end
    if not isSkipped() then
      tc.graph[tc.paramId].valueType = boundValueTypeMap[testType]
      table.insert(tests, {
          name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
            params = getParamsFuncMap.INVALID[rpcType](tc.graph),
        })
    end
  end
  -- tests for arrays
  tcs = createTestCases(ah.apiType.HMI, rpcType, m.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.YES, m.isVersion.ALL, {})
  for _, tc in pairs(tcs) do
    tc.graph[tc.paramId].valueTypeArray = boundValueTypeMap[testType]
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_ARRAY",
        params = getParamsFuncMap.INVALID[rpcType](tc.graph),
      })
  end
  -- tests for enums
  tcs = createTestCases(ah.apiType.HMI, rpcType, m.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.ALL, m.isVersion.ALL, { ah.dataType.ENUM.type })
  for _, tc in pairs(tcs) do
    local function isSkipped()
      local paramData = tc.graph[tc.paramId]
      if paramData.type == ah.dataType.ENUM.type and testType == m.testType.LOWER_OUT_OF_BOUND then
        return true
      end
      return false
    end
    local function getMandatoryValues(pId, pLevel, pOut)
      pOut[pLevel] = tc.graph[pId].mandatory
      local parentId = tc.graph[pId].parentId
      if parentId then return getMandatoryValues(parentId, pLevel+1, pOut) end
      return pOut
    end
    local mandatoryValues = getMandatoryValues(tc.paramId, 1, {})
    if not isSkipped() and (#mandatoryValues == 1 or mandatoryValues[#mandatoryValues-1]) then
      local invalidValue = "INVALID_VALUE"
      tc.graph[tc.paramId].data = { invalidValue }
      local params = getParamsFuncMap.INVALID[rpcType](tc.graph)
      table.insert(tests, {
          name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_" .. invalidValue,
          params = params
        })
    end
  end
  return tests
end

local function getEnumItemsTests()
  local tests = {}
  local dataTypes = { ah.dataType.ENUM.type }
  local tcs = createTestCases(ah.apiType.HMI, rpcType, m.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.ALL, m.isVersion.ALL, dataTypes)
  for _, tc in pairs(tcs) do
    for _, item in pairs(tc.graph[tc.paramId].data) do
      local tcUpd = utils.cloneTable(tc)
      tcUpd.graph[tc.paramId].data = { item }
      table.insert(tests, {
          name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_" .. item,
          params = getParamsFuncMap.VALID[rpcType](tcUpd.graph)
        })
    end
  end
  return tests
end

local function getBoolItemsTests()
  local tests = {}
  local dataTypes = { ah.dataType.BOOLEAN.type }
  local tcs = createTestCases(ah.apiType.HMI, rpcType, m.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.ALL, m.isVersion.ALL, dataTypes)
  for _, tc in pairs(tcs) do
    for _, item in pairs({true, false}) do
      local tcUpd = utils.cloneTable(tc)
      tcUpd.graph[tc.paramId].data = { item }
      table.insert(tests, {
          name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_" .. tostring(item),
          params = getParamsFuncMap.VALID[rpcType](tcUpd.graph)
        })
    end
  end
  return tests
end

local function getVersionTests()
  local tests = {}
  local dataTypes = { }
  local tcs = createTestCases(ah.apiType.MOBILE, ah.eventType.REQUEST, rpc,
    m.isMandatory.ALL, m.isArray.ALL, m.isVersion.YES, dataTypes)
  for _, tc in pairs(tcs) do
    table.insert(tests, {
        param = tc.graph[tc.paramId].name,
        version = tc.graph[tc.paramId].since
      })
  end
  return tests
end

local function getValidRandomAllTests()
  local tests = {}
  local graph = ah.getGraph(ah.apiType.HMI, rpcType, m.rpcHMIMap[rpc])
  local function getParamId(pGraph, pName)
    for k, v in pairs(pGraph) do
      if v.parentId == nil and v.name == pName then return k end
    end
    return nil
  end
  local paramId = getParamId(graph, paramName)

  local paramIds = ah.getBranch(graph, paramId, {})
  local function getUpdatedGraph(pGraph, pParamIds)
    for k in pairs(pGraph) do
      if not pParamIds[k] then
        pGraph[k] = nil
      end
    end
    return pGraph
  end
  graph = getUpdatedGraph(graph, paramIds)
  local tc = { graph = graph, paramId = paramId }
  table.insert(tests, {
      name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
      params = getParamsFuncMap.VALID[rpcType](tc.graph),
      paramId = tc.paramId,
      graph = tc.graph
    })
  return tests
end

local function getMandatoryMissingTests()
  local tests = {}
  local mndTests = getOnlyMandatoryTests()
  local randomAllTests = getValidRandomAllTests()
  if #mndTests == 0 or #randomAllTests == 0 then return tests end
  for testId in pairs(mndTests) do
    for paramId in pairs(mndTests[testId].graph) do
      local graph = utils.cloneTable(randomAllTests[1].graph)
      if graph[paramId].parentId ~= nil and graph[paramId].mandatory == true then
        local name = ah.getFullParamName(graph, paramId)
        local idsToDelete = ah.getBranch(graph, paramId, {})
        for id in pairs(graph) do
          if idsToDelete[id] == true then graph[id] = nil end
        end
        table.insert(tests, {
          name = "Param_missing_" .. name,
          params = getParamsFuncMap.INVALID[rpcType](graph),
        })
      end
    end
  end
  return tests
end

--[[ Test Getter Function ]]------------------------------------------------------------------------
function m.getTests(pRPC, pTestType, pParamName)
  local rpcTypeMap = {
    [m.rpc.get] = ah.eventType.RESPONSE,
    [m.rpc.on] = ah.eventType.NOTIFICATION
  }
  rpc = pRPC
  rpcType = rpcTypeMap[pRPC]
  testType = pTestType
  paramName = pParamName

  local testTypeMap = {
    [m.testType.VALID_RANDOM] = getValidRandomTests,
    [m.testType.MANDATORY_ONLY] = getOnlyMandatoryTests,
    [m.testType.LOWER_IN_BOUND] = getInBoundTests,
    [m.testType.UPPER_IN_BOUND] = getInBoundTests,
    [m.testType.LOWER_OUT_OF_BOUND] = getOutOfBoundTests,
    [m.testType.UPPER_OUT_OF_BOUND] = getOutOfBoundTests,
    [m.testType.ENUM_ITEMS] = getEnumItemsTests,
    [m.testType.BOOL_ITEMS] = getBoolItemsTests,
    [m.testType.PARAM_VERSION] = getVersionTests,
    [m.testType.VALID_RANDOM_ALL] = getValidRandomAllTests,
    [m.testType.MANDATORY_MISSING] = getMandatoryMissingTests
  }
  if testTypeMap[testType] then return testTypeMap[testType]() end
  return {}
end

function m.processRequest(pParams)
  local cid = m.getMobileSession():SendRPC(pParams.mobile.name, pParams.mobile.request)
  m.getHMIConnection():ExpectRequest(pParams.hmi.name, pParams.hmi.request)
  :Do(function(_, data)
      m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", pParams.hmi.response)
    end)
  m.getMobileSession():ExpectResponse(cid, pParams.mobile.response)
end

function m.processNotification(pParams, pTestType, pVDParam)
  local function SendNotification()
    local times = m.isExpected
    if pTestType == m.testType.LOWER_OUT_OF_BOUND
      or pTestType == m.testType.UPPER_OUT_OF_BOUND
      or pTestType == m.testType.MANDATORY_MISSING
      or not m.isSubscribable(pVDParam) then
      times = m.isNotExpected
    end
    m.getHMIConnection():SendNotification(pParams.hmi.name, pParams.hmi.notification)
    m.getMobileSession():ExpectNotification(pParams.mobile.name, pParams.mobile.notification)
    :Times(times)
  end
  if not isSubscribed[pVDParam] and m.isSubscribable(pVDParam) then
    m.processSubscriptionRPC(m.rpc.sub, pVDParam)
    :Do(function()
        SendNotification()
      end)
    isSubscribed[pVDParam] = true
  else
    SendNotification()
  end
end

function m.getTestsForGetVD(pTestTypes)
  for param in m.spairs(m.getVDParams()) do
    m.Title("VD parameter: " .. param)
    for _, tt in pairs(pTestTypes) do
      local tests = m.getTests(m.rpc.get, tt, param)
      if m.getTableSize(tests) > 0 then
        m.Title("Test type: " .. m.getKeyByValue(m.testType, tt))
        for _, t in pairs(tests) do
          m.Step(t.name, m.processRequest, { t.params })
        end
      end
    end
  end
end

function m.getTestsForOnVD(pTestTypes)
  for param in m.spairs(m.getVDParams()) do
    m.Title("VD parameter: " .. param)
    for _, tt in pairs(pTestTypes) do
      local tests = m.getTests(m.rpc.on, tt, param)
      if m.getTableSize(tests) > 0 then
        m.Title("Test type: " .. m.getKeyByValue(m.testType, tt))
        for _, t in pairs(tests) do
          m.Step(t.name, m.processNotification, { t.params, tt, param })
        end
      end
    end
  end
end

return m
