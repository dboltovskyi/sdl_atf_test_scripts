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
  LOWER_OUT_OF_BOUND = 6,
  VALID_RANDOM = 7,
  ENUM_ITEMS = 8
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

--[[ Local Constants ]]-----------------------------------------------------------------------------
local valueTypeMap = {
  [m.testType.UPPER_IN_BOUND] = tdg.valueType.UPPER_IN_BOUND,
  [m.testType.LOWER_IN_BOUND] = tdg.valueType.LOWER_IN_BOUND,
  [m.testType.UPPER_OUT_OF_BOUND] = tdg.valueType.UPPER_OUT_OF_BOUND,
  [m.testType.LOWER_OUT_OF_BOUND] = tdg.valueType.LOWER_OUT_OF_BOUND,
  [m.testType.VALID_RANDOM] = tdg.valueType.VALID_RANDOM,
}

--[[ Local Variables ]]-----------------------------------------------------------------------------
local rpc
local testType
local paramName

--[[ Processing Functions ]]------------------------------------------------------------------------
local function processRPCSuccess(pParams)
  local cid = cmn.getMobileSession():SendRPC(pParams.mobile.name, pParams.mobile.request)
  cmn.getHMIConnection():ExpectRequest(pParams.hmi.name, pParams.hmi.request)
  :Do(function(_, data)
      cmn.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", pParams.hmi.response)
    end)
  cmn.getMobileSession():ExpectResponse(cid, pParams.mobile.response)
end

--[[ Params Generator Functions ]]------------------------------------------------------------------
local function getParamsSuccessTest(pParamData, pValueTypesMap, pArrayValueTypesMap)
  local request = { [next(pParamData)] = true }
  local hmiResponse = tdg.getParamValues(pParamData, pValueTypesMap, pArrayValueTypesMap)
  local mobileResponse = cmn.cloneTable(hmiResponse)
  mobileResponse.success = true
  mobileResponse.resultCode = "SUCCESS"
  local params = {
    mobile = {
      name = cmn.getKeyByValue(ah.rpc, rpc),
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

local function getParamsInvalidDataTest(pParamData, pValueTypesMap, pArrayValueTypesMap)
  local request = { [next(pParamData)] = true }
  local hmiResponse = tdg.getParamValues(pParamData, pValueTypesMap, pArrayValueTypesMap)
  local params = {
    mobile = {
      name = cmn.getKeyByValue(ah.rpc, rpc),
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

--[[ Test Cases Generator Function ]]---------------------------------------------------------------
local function createTestCases(pIsMandatory, pIsArray, pDataTypes, pIterateEnumItems)
  local apiParamsData = ah.getParamsData(ah.apiType.HMI, ah.eventType.RESPONSE, ah.rpcHMIMap[rpc])
  -- local apiParamsData = ah.getParamsData(ah.apiType.MOBILE, ah.eventType.RESPONSE, cmn.getKeyByValue(ah.rpc, rpc))

  local function getGraph(pParams, pGraph, pParentId)
    for k, v in cmn.spairs(pParams) do
      local item = cmn.cloneTable(v)
      if v.type == ah.dataType.ENUM.type then
        item.items = cmn.cloneTable(v.data)
      end
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

  local graph = getGraph(apiParamsData, {})

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

  local function getFullParamName(pGraph, pId)
    local out = pGraph[pId].name
    pId = pGraph[pId].parentId
    while pId do
      out = pGraph[pId].name .. "." .. out
      pId = pGraph[pId].parentId
    end
    return out
  end

  local function getUpdatedParams(pParams, pParamIds, pEnumParamId, pEnumParamItem)
    for k, v in pairs(pParams) do
      if not pParamIds[v.id] then
        pParams[k] = nil
      end
      if v.id == pEnumParamId then
        v.data = { pEnumParamItem }
      end
      if v.type == ah.dataType.STRUCT.type then
        getUpdatedParams(v.data, pParamIds, pEnumParamId, pEnumParamItem)
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
      else return string.find(pName, paramName) == 1
      end
    end
    local function getDisabledParamCondition(pName)
      local parentName = cmn.splitString(pName, ".")[1]
      if cmn.vd[parentName] == nil then
        cmn.cprint(cmn.color.magenta, "Disabled VD parameter:", pName)
        return false
      end
      return true
    end
    local tcs = {}
    for k, v in pairs(pGraph) do
      local paramFullName = getFullParamName(graph, k)
      if getMandatoryCondition(v.mandatory) and getArrayCondition(v.array)
        and getTypeCondition(v.type) and getParamNameCondition(paramFullName)
        and getDisabledParamCondition(paramFullName) then
        local parentIds = getParents(graph, k)
        local childrenIds = getMandatoryChildren(graph, k, {})
        local neighborsIds = getMandatoryNeighbors(graph, k, parentIds)
        local neighborsChildrenIds = {}
        for id in pairs(neighborsIds) do
          getMandatoryChildren(graph, id, neighborsChildrenIds)
        end
        local tcParamIds = getTCParamsIds(k, parentIds, neighborsIds, childrenIds, neighborsChildrenIds)
        if not (v.type == ah.dataType.STRUCT.type and cmn.getTableSize(childrenIds) == 0) then
          local tc = {
            paramName = graph[k].name,
            paramFullName = paramFullName,
            paramData = graph[k]
          }
          if pIterateEnumItems == true and v.type == ah.dataType.ENUM.type then
            for _, item in pairs(v.items) do
              local tcUpd = cmn.cloneTable(tc)
              tcUpd.params = getUpdatedParams(cmn.cloneTable(apiParamsData), tcParamIds, k, item)
              tcUpd.item = item
              table.insert(tcs, tcUpd)
            end
          else
            tc.params = getUpdatedParams(cmn.cloneTable(apiParamsData), tcParamIds)
            table.insert(tcs, tc)
          end
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
  -- tests for simple data types
  local dataTypes = { ah.dataType.INTEGER.type, ah.dataType.FLOAT.type, ah.dataType.DOUBLE.type, ah.dataType.STRING.type }
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
          func = processRPCSuccess,
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
        func = processRPCSuccess,
        params = getParamsInvalidDataTest(tc.params, valueTypesMap, arrayValueTypesMap)
      })
  end
  for _, tc in pairs(createTestCases(m.isMandatory.ALL, m.isArray.YES, {})) do
    local valueTypesMap = { [tc.paramName] = tdg.valueType.UPPER_IN_BOUND }
    local arrayValueTypesMap = { [tc.paramName] = valueTypeMap[testType] }
    table.insert(tests, {
        name = "Param_" .. tc.paramFullName .. "_array_value_UPPER",
        func = processRPCSuccess,
        params = getParamsInvalidDataTest(tc.params, valueTypesMap, arrayValueTypesMap)
      })
  end
  return tests
end

local function getValidRandomTests()
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

local function getEnumItemsTests()
  local tcs = createTestCases(m.isMandatory.ALL, m.isArray.ALL, { ah.dataType.ENUM.type }, m.iterateEnumItems.YES)
  local tests = {}
  for _, tc in pairs(tcs) do
    table.insert(tests, {
        name = "Param " .. tc.paramFullName .. "_" .. tc.item,
        func = processRPCSuccess,
        params = getParamsSuccessTest(tc.params)
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
    -- [m.testType.DEBUG] = getDebugTests,
    [m.testType.ONLY_MANDATORY_PARAMS] = getOnlyMandatoryTests,
    [m.testType.LOWER_IN_BOUND] = getInBoundTests,
    [m.testType.UPPER_IN_BOUND] = getInBoundTests,
    [m.testType.LOWER_OUT_OF_BOUND] = getOutOfBoundTests,
    [m.testType.UPPER_OUT_OF_BOUND] = getOutOfBoundTests,
    [m.testType.VALID_RANDOM] = getValidRandomTests,
    [m.testType.ENUM_ITEMS] = getEnumItemsTests
  }
  if testTypeMap[testType] then return testTypeMap[testType]() end
  return {}
end

return m
