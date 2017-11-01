---------------------------------------------------------------------------------------------------
-- API Test Generator module
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local ah = require('test_scripts/API2/APIHelper')
local cmn = require('test_scripts/API2/APICommon')
local tdg = require('test_scripts/API2/APITestDataGen')

--[[ Module ]]--------------------------------------------------------------------------------------
local m = {}

--[[ Constants ]]-----------------------------------------------------------------------------------
m.testType = {
  DEBUG = 1,
  ONLY_MANDATORY_PARAMS = 2,
  UPPER_IN_BOUND = 3,
  LOWER_IN_BOUND = 4,
  UPPER_OUT_OF_BOUND = 5,
  LOWER_OUT_OF_BOUND = 6
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

--[[ Local Constants ]]-----------------------------------------------------------------------------
local valueTypeMap = {
  [m.testType.UPPER_IN_BOUND] = tdg.valueType.UPPER_IN_BOUND,
  [m.testType.LOWER_IN_BOUND] = tdg.valueType.LOWER_IN_BOUND,
  [m.testType.UPPER_OUT_OF_BOUND] = tdg.valueType.UPPER_OUT_OF_BOUND,
  [m.testType.LOWER_OUT_OF_BOUND] = tdg.valueType.LOWER_OUT_OF_BOUND,
}

--[[ Local Variables ]]-----------------------------------------------------------------------------
local rpc
local testType
local paramName

--[[ Utility Functions ]]---------------------------------------------------------------------------
local function isPresentUnexpectedParams(pExpected, pActual)
  local isFailed = false
  local isNotFirst = false
  local msg = "Unexpected params: "
  for k in pairs(pActual) do
    if not pExpected[k] then
      if isNotFirst then
        msg = msg .. ", "
      else
        isNotFirst = true
      end
      msg = msg .. k
      isFailed = true
    end
  end
  if isFailed then
    return false, msg
  end
  return true
end

--[[ Specific Param Values Updater Functions ]]-----------------------------------------------------
local function addHMIAppId(pHMIRpc, pEventType, pParamValues)
  local hmiParamsData = ah.getParamsData(ah.apiType.HMI, pEventType, pHMIRpc)
  if hmiParamsData["appID"] then pParamValues.appID = 0 end
end

local function updateHMIAppId(pPV)
  if pPV.appID then pPV.appID = cmn.getHMIAppId(1) end
end

local function updateImageType(pPV)
  for k, v in pairs(pPV) do
    if type(v) == "table" then
      updateImageType(v)
    else
      if k == "imageType" then pPV[k] = "STATIC" end
    end
  end
end

m.paramValuesUpdaters = {
  { apiType = ah.apiType.HMI, eventType = ah.eventType.REQUEST, func = updateHMIAppId },
  { apiType = ah.apiType.HMI, eventType = ah.eventType.RESPONSE, func = updateHMIAppId },
  { eventType = ah.eventType.REQUEST, func = updateImageType }
}

local function updateParamValues(pParams)
  for _, apiType in pairs(ah.apiType) do
    for _, eventType in pairs(ah.eventType) do
      for _, u in pairs(m.paramValuesUpdaters) do
        if (u.apiType == nil or u.apiType == apiType)
          and (u.eventType == nil or u.eventType == eventType)
          and (u.rpc == nil or u.rpc == rpc) then
            local p = pParams[apiType][eventType]
            if p then u.func(p) end
        end
      end
    end
  end
end

--[[ Processing Functions ]]------------------------------------------------------------------------
local function processRPCSuccess(pParams, self)
  updateParamValues(pParams)

  local cid = self.mobileSession1:SendRPC(pParams.mobile.name, pParams.mobile.request)
  EXPECT_HMICALL(pParams.hmi.name, pParams.hmi.request)
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", pParams.hmi.response)
    end)
  :ValidIf(function(_, data)
      return isPresentUnexpectedParams(pParams.hmi.request, data.params)
    end)
  self.mobileSession1:ExpectResponse(cid, pParams.mobile.response)
end

local function processRPCInvalidRequest(pParams, self)
  updateParamValues(pParams)

  local cid = self.mobileSession1:SendRPC(pParams.mobile.name, pParams.mobile.request)
  EXPECT_HMICALL(pParams.hmi.name):Times(0)
  self.mobileSession1:ExpectResponse(cid, pParams.mobile.response)
  cmn.Delay()
end

--[[ Params Generator Functions ]]------------------------------------------------------------------
local function getParamsSuccessTest(pParamData, pValueTypesMap, pArrayValueTypesMap)
  local mobileParamsValues = tdg.getParamValues(pParamData, pValueTypesMap, pArrayValueTypesMap)
  local hmiParamsValues = cmn.cloneTable(mobileParamsValues)
  local params = {
    mobile = {
      name = cmn.getKeyByValue(ah.rpc, rpc),
      request = mobileParamsValues,
      response = { success = true, resultCode = "SUCCESS" }
    },
    hmi = {
      name = ah.rpcHMIMap[rpc],
      request = hmiParamsValues,
      response = {}
    }
  }
  addHMIAppId(params.hmi.name, ah.eventType.REQUEST, params.hmi.request)
  addHMIAppId(params.hmi.name, ah.eventType.RESPONSE, params.hmi.response)
  return params
end

local function getParamsInvalidDataTest(pParamData, pValueTypesMap, pArrayValueTypesMap)
  local mobileParamsValues = tdg.getParamValues(pParamData, pValueTypesMap, pArrayValueTypesMap)
  local params = {
    mobile = {
      name = cmn.getKeyByValue(ah.rpc, rpc),
      request = mobileParamsValues,
      response = { success = false, resultCode = "INVALID_DATA" }
    },
    hmi = {
      name = ah.rpcHMIMap[rpc]
    }
  }
  return params
end

--[[ Test Cases Generator Function ]]---------------------------------------------------------------
local function createTestCases(pIsMandatory, pIsArray, pDataTypes)
  local mobileParamsData = ah.getParamsData(ah.apiType.MOBILE, ah.eventType.REQUEST, cmn.getKeyByValue(ah.rpc, rpc))

  local function getGraph(pParams, pGraph, pParentId)
    for k, v in cmn.spairs(pParams) do
      local item = cmn.cloneTable(v)
      if item.data then item.data = nil end
      item.parentId = pParentId
      item.name = k
      table.insert(pGraph, item)
      v.id = #pGraph
      if v.type == ah.dataType.STRUCT.type then
        getGraph(v.data, pGraph, #pGraph)
      end
    end
    return pGraph
  end

  local graph = getGraph(mobileParamsData, {})

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
    local pIds = cmn.cloneTable(pParentIds)
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

  local function getTCParamsIds(pId, pParentIds, pNeighborsIds, pChildrenIds)
    local ids = {}
    ids[pId] = true
    for p in pairs(pParentIds) do
      ids[p] = true
    end
    for p in pairs(pNeighborsIds) do
      ids[p] = true
    end
    for p in pairs(pChildrenIds) do
      ids[p] = true
    end
    return ids
  end

  local function getFullParamName(pGraph, pId)
    local out = pGraph[pId].name
    pId = pGraph[pId].parentId
    while pId do
      out = pGraph[pId].name .. "." .. out
      pId = pGraph[pId].parentId
    end
    return out
  end

  local function getUpdatedParams(pParams, pParamIds)
    for k, v in pairs(pParams) do
      if not pParamIds[v.id] then
        pParams[k] = nil
      end
      if v.type == ah.dataType.STRUCT.type then
        getUpdatedParams(v.data, pParamIds)
      end
    end
    return pParams
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
    local function getTypeCondition(pType)
      if pDataTypes == nil or #pDataTypes == 0 then return true
      elseif cmn.tableContains(pDataTypes, pType) then return true
      else return false
      end
    end
    local function getParamNameCondition(pName)
      if paramName == nil or paramName == "" then return true
      else return pName == paramName
      end
    end
    local tcs = {}
    for k, v in pairs(pGraph) do
      local paramFullName = getFullParamName(graph, k)
      if getMandatoryCondition(v.mandatory) and getArrayCondition(v.array)
        and getTypeCondition(v.type) and getParamNameCondition(paramFullName) then
        local parentIds = getParents(graph, k)
        local neighborsIds = getMandatoryNeighbors(graph, k, parentIds)
        local childrenIds = getMandatoryChildren(graph, k, {})
        local tcParamIds = getTCParamsIds(k, parentIds, neighborsIds, childrenIds)
        if not (v.type == ah.dataType.STRUCT.type and cmn.getTableSize(childrenIds) == 0) then
          table.insert(tcs, {
              -- pId = k,
              -- parentIds = parentIds,
              -- neighborsIds = neighborsIds,
              -- childrenIds = childrenIds,
              paramIds = tcParamIds,
              paramName = graph[k].name,
              paramFullName = paramFullName,
              paramData = graph[k],
              params = getUpdatedParams(cmn.cloneTable(mobileParamsData), tcParamIds)
            })
        end
      end
    end
    return tcs
  end

  local tcs = getTestCases(graph)

  return tcs
end

--[[ Tests Generator Functions ]]-------------------------------------------------------------------
local function getDebugTests()
  local tcs = createTestCases(m.isMandatory.ALL, m.isArray.ALL, {})
  local tests = {}
  for _, tc in pairs(tcs) do
    table.insert(tests, {
        name = "Param " .. tc.paramFullName,
        func = processRPCSuccess,
        params = getParamsSuccessTest(tc.params)
      })
  end
  return tests
end

local function getOnlyMandatoryTests()
  local tcs = createTestCases(m.isMandatory.YES, m.isArray.ALL, {})
  local tests = {}
  for _, tc in pairs(tcs) do
    table.insert(tests, {
        name = "Param " .. tc.paramFullName,
        func = processRPCSuccess,
        params = getParamsSuccessTest(tc.params)
      })
  end
  return tests
end

local function getInBoundTests()
  local tests = {}
  -- tests simple data types
  local dataTypes = { ah.dataType.INTEGER.type, ah.dataType.FLOAT.type, ah.dataType.DOUBLE.type, ah.dataType.STRING.type}
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.ALL, dataTypes)) do
    local valueTypesMap = { [tc.paramName] = valueTypeMap[testType] }
    table.insert(tests, {
        name = "Param_" .. tc.paramFullName,
        func = processRPCSuccess,
        params = getParamsSuccessTest(tc.params, valueTypesMap, { })
      })
  end
  -- tests for arrays
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.YES, {})) do
    local valueTypesMap = { [tc.paramName] = tdg.valueType.LOWER_IN_BOUND }
    local arrayValueTypesMap = { [tc.paramName] = valueTypeMap[testType] }
    table.insert(tests, {
        name = "Param_" .. tc.paramFullName .. "_array_value_LOWER",
        func = processRPCSuccess,
        params = getParamsSuccessTest(tc.params, valueTypesMap, arrayValueTypesMap)
      })
  end
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.YES, {})) do
    local valueTypesMap = { [tc.paramName] = tdg.valueType.UPPER_IN_BOUND }
    local arrayValueTypesMap = { [tc.paramName] = valueTypeMap[testType] }
    table.insert(tests, {
        name = "Param_" .. tc.paramFullName .. "_array_value_UPPER",
        func = processRPCSuccess,
        params = getParamsSuccessTest(tc.params, valueTypesMap, arrayValueTypesMap)
      })
  end
  return tests
end

local function getOutOfBoundTests()
  local tests = {}
  local dataTypes
  -- tests for simple data types
  dataTypes = { ah.dataType.INTEGER.type, ah.dataType.FLOAT.type, ah.dataType.DOUBLE.type, ah.dataType.STRING.type }
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.ALL, dataTypes)) do
    local function isSkipped()
      if tc.paramData.type == ah.dataType.STRING.type then
        if (testType == m.testType.LOWER_OUT_OF_BOUND and tc.paramData.minlength == 0)
        or (testType == m.testType.UPPER_OUT_OF_BOUND and tc.paramData.maxlength == nil) then
          return true
        end
      else
        if (testType == m.testType.LOWER_OUT_OF_BOUND and tc.paramData.minvalue == nil)
        or (testType == m.testType.UPPER_OUT_OF_BOUND and tc.paramData.maxvalue == nil) then
          return true
        end
      end
      return false
    end
    if not isSkipped() then
      local valueTypesMap = { [tc.paramName] = valueTypeMap[testType] }
      table.insert(tests, {
          name = "Param_" .. tc.paramFullName,
          func = processRPCInvalidRequest,
          params = getParamsInvalidDataTest(tc.params, valueTypesMap, { })
        })
    end
  end
  -- tests for arrays
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.YES, {})) do
    local valueTypesMap = { [tc.paramName] = tdg.valueType.LOWER_IN_BOUND }
    local arrayValueTypesMap = { [tc.paramName] = valueTypeMap[testType] }
    table.insert(tests, {
        name = "Param_" .. tc.paramFullName .. "_array_value_LOWER",
        func = processRPCInvalidRequest,
        params = getParamsInvalidDataTest(tc.params, valueTypesMap, arrayValueTypesMap)
      })
  end
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.YES, {})) do
    local valueTypesMap = { [tc.paramName] = tdg.valueType.UPPER_IN_BOUND }
    local arrayValueTypesMap = { [tc.paramName] = valueTypeMap[testType] }
    table.insert(tests, {
        name = "Param_" .. tc.paramFullName .. "_array_value_UPPER",
        func = processRPCInvalidRequest,
        params = getParamsInvalidDataTest(tc.params, valueTypesMap, arrayValueTypesMap)
      })
  end
  return tests
end

--[[ Test Getter Function ]]------------------------------------------------------------------------
function m.getTests(pRPC, pTestType, pParamName)
  rpc = pRPC
  testType = pTestType
  paramName = pParamName
  local testTypeMap = {
    [m.testType.DEBUG] = getDebugTests,
    [m.testType.ONLY_MANDATORY_PARAMS] = getOnlyMandatoryTests,
    [m.testType.UPPER_IN_BOUND] = getInBoundTests,
    [m.testType.LOWER_IN_BOUND] = getInBoundTests,
    [m.testType.UPPER_OUT_OF_BOUND] = getOutOfBoundTests,
    [m.testType.LOWER_OUT_OF_BOUND] = getOutOfBoundTests
  }
  if testTypeMap[testType] then return testTypeMap[testType]() end
  return {}
end

return m
