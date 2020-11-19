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
local function getParamsValidDataTestForRequest(pGraph)
  local request = { [paramName] = true }
  local hmiResponse = tdg.getParamValues(pGraph)
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

local function getParamsInvalidDataTestForRequest(pGraph)
  local request = { [paramName] = true }
  local hmiResponse = tdg.getParamValues(pGraph)
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

local function getParamsAnyDataTestForNotification(pGraph)
  local notification = tdg.getParamValues(pGraph)
  local params = {
    mobile = {
      name = utils.getKeyByValue(ah.rpc, rpc),
      notification = { [paramName] = notification[paramName] }
    },
    hmi = {
      name = ah.rpcHMIMap[rpc],
      notification = { [paramName] = notification[paramName] }
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
  local tcs = createTestCases(ah.apiType.HMI, ah.getRPCType(rpc), ah.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.ALL, m.isVersion.ALL, {})
  local tests = {}
  for _, tc in pairs(tcs) do
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
        params = getParamsValidDataTest(tc.graph)
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
  local tcs = createTestCases(ah.apiType.HMI, ah.getRPCType(rpc), ah.rpcHMIMap[rpc],
    m.isMandatory.YES, m.isArray.ALL, m.isVersion.ALL, {})
  tcs = filterDuplicates(tcs)
  local tests = {}
  for _, tc in pairs(tcs) do
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
        params = getParamsValidDataTest(tc.graph),
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
  local tcs = createTestCases(ah.apiType.HMI, ah.getRPCType(rpc), ah.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.ALL, m.isVersion.ALL, dataTypes)
  for _, tc in pairs(tcs) do
    tc.graph[tc.paramId].valueType = valueTypeMap[testType]
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
        params = getParamsValidDataTest(tc.graph)
      })
  end
  -- tests for arrays
  tcs = createTestCases(ah.apiType.HMI, ah.getRPCType(rpc), ah.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.YES, m.isVersion.ALL, {})
  for _, tc in pairs(tcs) do
    tc.graph[tc.paramId].valueTypeArray = valueTypeMap[testType]
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_ARRAY",
        params = getParamsValidDataTest(tc.graph)
      })
  end
  return tests
end

local function getOutOfBoundTests()
  local tests = {}
  -- tests for simple data types
  local dataTypes = { ah.dataType.INTEGER.type, ah.dataType.FLOAT.type, ah.dataType.DOUBLE.type, ah.dataType.STRING.type }
  local tcs = createTestCases(ah.apiType.HMI, ah.getRPCType(rpc), ah.rpcHMIMap[rpc],
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
      tc.graph[tc.paramId].valueType = valueTypeMap[testType]
      table.insert(tests, {
          name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId),
            params = getParamsInvalidDataTest(tc.graph)
        })
    end
  end
  -- tests for arrays
  tcs = createTestCases(ah.apiType.HMI, ah.getRPCType(rpc), ah.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.YES, m.isVersion.ALL, {})
  for _, tc in pairs(tcs) do
    tc.graph[tc.paramId].valueTypeArray = valueTypeMap[testType]
    table.insert(tests, {
        name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_ARRAY",
        params = getParamsInvalidDataTest(tc.graph)
      })
  end
  -- tests for enums
  tcs = createTestCases(ah.apiType.HMI, ah.getRPCType(rpc), ah.rpcHMIMap[rpc],
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
      local params = getParamsInvalidDataTest(tc.graph)
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
  local tcs = createTestCases(ah.apiType.HMI, ah.getRPCType(rpc), ah.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.ALL, m.isVersion.ALL, dataTypes)
  for _, tc in pairs(tcs) do
    for _, item in pairs(tc.graph[tc.paramId].data) do
      local tcUpd = utils.cloneTable(tc)
      tcUpd.graph[tc.paramId].data = { item }
      table.insert(tests, {
          name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_" .. item,
          params = getParamsValidDataTest(tcUpd.graph)
        })
    end
  end
  return tests
end

local function getBoolItemsTests()
  local tests = {}
  local dataTypes = { ah.dataType.BOOLEAN.type }
  local tcs = createTestCases(ah.apiType.HMI, ah.getRPCType(rpc), ah.rpcHMIMap[rpc],
    m.isMandatory.ALL, m.isArray.ALL, m.isVersion.ALL, dataTypes)
  for _, tc in pairs(tcs) do
    for _, item in pairs({true, false}) do
      local tcUpd = utils.cloneTable(tc)
      tcUpd.graph[tc.paramId].data = { item }
      table.insert(tests, {
          name = "Param_" .. ah.getFullParamName(tc.graph, tc.paramId) .. "_" .. tostring(item),
          params = getParamsValidDataTest(tcUpd.graph)
        })
    end
  end
  return tests
end

local function getVersionTests()
  local tests = {}
  local dataTypes = { }
  local tcs = createTestCases(ah.apiType.MOBILE, ah.eventType.REQUEST, utils.getKeyByValue(ah.rpc, rpc),
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
  local graph = ah.getGraph(ah.apiType.HMI, ah.getRPCType(rpc), ah.rpcHMIMap[rpc])
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
      params = getParamsValidDataTest(tc.graph),
      paramId = tc.paramId,
      graph = tc.graph
    })
  return tests
end

local function getMandatoryMissingTests()
  local tests = {}
  local mndTests = getOnlyMandatoryTests()
  local randomAllTest = getValidRandomAllTests()
  if #mndTests == 0 or #randomAllTest == 0 then return tests end
  for testId in pairs(mndTests) do
    for paramId in pairs(mndTests[testId].graph) do
      local graph = utils.cloneTable(randomAllTest[1].graph)
      if graph[paramId].parentId ~= nil and graph[paramId].mandatory == true then
        local name = ah.getFullParamName(graph, paramId)
        local idsToDelete = ah.getBranch(graph, paramId, {})
        for id in pairs(graph) do
          if idsToDelete[id] == true then graph[id] = nil end
        end
        table.insert(tests, {
          name = "Param_missing_" .. name,
          params = getParamsInvalidDataTest(graph)
        })
      end
    end
  end
  return tests
end

local function getDebugTests()
  local tests = {}
  return tests
end

--[[ Test Getter Function ]]------------------------------------------------------------------------
function m.getTests(pRPC, pTestType, pParamName)
  rpc = ah.rpc[pRPC]
  testType = pTestType
  paramName = pParamName
  local testTypeMap = {
    [m.testType.DEBUG] = getDebugTests,
    [m.testType.VALID_RANDOM] = getValidRandomTests,
    [m.testType.ONLY_MANDATORY_PARAMS] = getOnlyMandatoryTests,
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

return m
