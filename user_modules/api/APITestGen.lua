---------------------------------------------------------------------------------------------------
-- API Test Generator module
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local utils = require("user_modules/utils")
local ah = require("user_modules/api/APIHelper")
local tdg = require("user_modules/api/APITestDataGen")

--[[ Module ]]--------------------------------------------------------------------------------------
local m = {}

--[[ Constants ]]-----------------------------------------------------------------------------------
m.testType = {
  DEBUG = 0,
  VALID_RANDOM = 1,
  ONLY_MANDATORY_PARAMS = 2,
  UPPER_IN_BOUND = 3,
  LOWER_IN_BOUND = 4,
  UPPER_OUT_OF_BOUND = 5,
  LOWER_OUT_OF_BOUND = 6,
  ENUM_ITEMS = 7
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

m.iterateEnumItems = {
  YES = true,
  NO = false
}

--[[ Local Variables ]]-----------------------------------------------------------------------------
local rpc
local testType
local paramName

--[[ Local Constants ]]-----------------------------------------------------------------------------
local valueTypeMap = {
  [m.testType.UPPER_IN_BOUND] = tdg.valueType.UPPER_IN_BOUND,
  [m.testType.LOWER_IN_BOUND] = tdg.valueType.LOWER_IN_BOUND,
  [m.testType.UPPER_OUT_OF_BOUND] = tdg.valueType.UPPER_OUT_OF_BOUND,
  [m.testType.LOWER_OUT_OF_BOUND] = tdg.valueType.LOWER_OUT_OF_BOUND,
  [m.testType.VALID_RANDOM] = tdg.valueType.VALID_RANDOM,
}

--[[ Params Generator Functions ]]------------------------------------------------------------------
local function getParamsValidDataTestForRequest(pTC)
  local mainParerntName = ah.getMainParentName(pTC.graph, pTC.paramId)
  local request = { [mainParerntName] = true }
  local hmiResponse = tdg.getParamValues(pTC.graph)
  local mobileResponse = utils.cloneTable(hmiResponse)
  mobileResponse.success = true
  mobileResponse.resultCode = "SUCCESS"
  local params = {
    mobile = {
      name = utils.getKeyByValue(ah.rpc, rpc),
      request = request,
      response = mobileResponse
    },
    hmi = {
      name = ah.rpcHMIMap[rpc],
      request = request,
      response = hmiResponse
    }
  }
  return params
end

local function getParamsInvalidDataTestForRequest(pTC)
  local mainParerntName = ah.getMainParentName(pTC.graph, pTC.paramId)
  local request = { [mainParerntName] = true }
  local hmiResponse = tdg.getParamValues(pTC.graph)
  local params = {
    mobile = {
      name = utils.getKeyByValue(ah.rpc, rpc),
      request = request,
      response = { success = false, resultCode = "GENERIC_ERROR" }
    },
    hmi = {
      name = ah.rpcHMIMap[rpc],
      request = request,
      response = hmiResponse
    }
  }
  return params
end

local function getParamsAnyDataTestForNotification(pTC)
  local param = ah.getMainParentName(pTC.graph, pTC.paramId)
  local notification = tdg.getParamValues(pTC.graph)
  local params = {
    mobile = {
      name = utils.getKeyByValue(ah.rpc, rpc),
      notification = { [param] = notification[param] }
    },
    hmi = {
      name = ah.rpcHMIMap[rpc],
      notification = { [param] = notification[param] }
    }
  }
  return params
end

local function getParamsValidDataTest(...)
  if ah.getRPCType(rpc) == ah.eventType.RESPONSE then
    return getParamsValidDataTestForRequest(...)
  elseif ah.getRPCType(rpc) == ah.eventType.NOTIFICATION then
    return getParamsAnyDataTestForNotification(...)
  end
end

local function getParamsInvalidDataTest(...)
  if ah.getRPCType(rpc) == ah.eventType.RESPONSE then
    return getParamsInvalidDataTestForRequest(...)
  elseif ah.getRPCType(rpc) == ah.eventType.NOTIFICATION then
    return getParamsAnyDataTestForNotification(...)
  end
end

--[[ Processing Functions ]]------------------------------------------------------------------------


--[[ Test Cases Generator Function ]]---------------------------------------------------------------
local function createTestCases(pIsMandatory, pIsArray, pDataTypes)

  local graph = ah.getGraph(ah.apiType.HMI, ah.getRPCType(rpc), ah.rpcHMIMap[rpc])

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
        and getTypeCondition(v.type) and getParamNameCondition(paramFullName) then
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
  local tcs = createTestCases(m.isMandatory.ALL, m.isArray.ALL, {})
  local tests = {}
  for _, tc in pairs(tcs) do
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
        params = getParamsValidDataTest(tc)
      })
  end
  return tests
end

local function getOnlyMandatoryTests()
  local tcs = createTestCases(m.isMandatory.YES, m.isArray.ALL, {})
  local tests = {}
  for _, tc in pairs(tcs) do
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
        params = getParamsValidDataTest(tc)
      })
  end
  return tests
end

local function getInBoundTests()
  local tests = {}
  -- tests simple data types
  local dataTypes = { ah.dataType.INTEGER.type, ah.dataType.FLOAT.type, ah.dataType.DOUBLE.type, ah.dataType.STRING.type}
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.ALL, dataTypes)) do
    tc.graph[tc.paramId].valueType = valueTypeMap[testType]
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
        params = getParamsValidDataTest(tc)
      })
  end
  -- tests for arrays
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.YES, {})) do
    tc.graph[tc.paramId].valueTypeArray = valueTypeMap[testType]
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_ARRAY",
        params = getParamsValidDataTest(tc)
      })
  end
  return tests
end

local function getOutOfBoundTests()
  local tests = {}
  -- tests for simple data types
  local dataTypes = { ah.dataType.INTEGER.type, ah.dataType.FLOAT.type, ah.dataType.DOUBLE.type, ah.dataType.STRING.type }
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.ALL, dataTypes)) do
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
      tc.graph[tc.paramId].valueType = valueTypeMap[testType]
      table.insert(tests, {
          name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
            params = getParamsInvalidDataTest(tc)
        })
    end
  end
  -- tests for arrays
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.YES, {})) do
    tc.graph[tc.paramId].valueTypeArray = valueTypeMap[testType]
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_ARRAY",
        params = getParamsInvalidDataTest(tc)
      })
  end
  return tests
end

local function getEnumItemsTests()
  local tests = {}
  local dataTypes = { ah.dataType.ENUM.type }
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.ALL, dataTypes)) do
    for _, item in pairs(tc.graph[tc.paramId].data) do
      local tcUpd = utils.cloneTable(tc)
      tcUpd.graph[tc.paramId].data = { item }
      table.insert(tests, {
          name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_" .. item,
          params = getParamsValidDataTest(tcUpd)
        })
    end
  end
  return tests
end

local function getDebugTests()
  local tests = {}
  local dataTypes = { ah.dataType.ENUM.type }
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.ALL, dataTypes)) do
    for _, item in pairs(tc.graph[tc.paramId].data) do
      local tcUpd = utils.cloneTable(tc)
      tcUpd.graph[tc.paramId].data = { item }
      table.insert(tests, {
          name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_" .. item,
          params = getParamsValidDataTest(tcUpd)
        })
    end
  end
  return tests
end

--[[ Test Getter Function ]]------------------------------------------------------------------------
function m.getTests(pRPC, pTestType, pParamName)
  rpc = ah.rpc[pRPC]
  testType = pTestType
  paramName = pParamName
  local testTypeMap = {
    [m.testType.VALID_RANDOM] = getValidRandomTests,
    [m.testType.ONLY_MANDATORY_PARAMS] = getOnlyMandatoryTests,
    [m.testType.LOWER_IN_BOUND] = getInBoundTests,
    [m.testType.UPPER_IN_BOUND] = getInBoundTests,
    [m.testType.LOWER_OUT_OF_BOUND] = getOutOfBoundTests,
    [m.testType.UPPER_OUT_OF_BOUND] = getOutOfBoundTests,
    [m.testType.ENUM_ITEMS] = getEnumItemsTests,
    [m.testType.DEBUG] = getDebugTests
  }
  if testTypeMap[testType] then return testTypeMap[testType]() end
  return {}
end

return m
