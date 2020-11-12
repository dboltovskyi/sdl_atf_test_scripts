----------------------------------------------------------------------------------------------------
-- API Test Data Generator module
----------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]-------------------------------------------------------------------
local ah = require('test_scripts/API2/APIHelper')

--[[ Module ]]--------------------------------------------------------------------------------------
local m = {}

--[[ Constants ]]-----------------------------------------------------------------------------------
m.valueType = {
  LOWER_IN_BOUND = 1,
  UPPER_IN_BOUND = 2,
  LOWER_OUT_OF_BOUND = 3,
  UPPER_OUT_OF_BOUND = 4,
  VALID_RANDOM = 5
}

--[[ Value generators ]]----------------------------------------------------------------------------
local function getStringValue(pTypeData, pValueType)
  local length
  if pValueType == m.valueType.LOWER_IN_BOUND then
    length = pTypeData.minlength
    if not length or length == 0 then length = ah.dataType.STRING.min end
  elseif pValueType == m.valueType.UPPER_IN_BOUND then
    length = pTypeData.maxlength
    if not length or length == 0 then length = ah.dataType.STRING.max end
  elseif pValueType == m.valueType.LOWER_OUT_OF_BOUND then
    length = pTypeData.minlength
    if not length or length == 0 then length = ah.dataType.STRING.min end
    length = length - 1
  elseif pValueType == m.valueType.UPPER_OUT_OF_BOUND then
    length = pTypeData.maxlength
    if not length or length == 0 then length = ah.dataType.STRING.max end
    length = length + 1
  elseif pValueType == m.valueType.VALID_RANDOM then
    local min = pTypeData.minlength
    local max = pTypeData.maxlength
    if not min or min == 0 then min = ah.dataType.STRING.min end
    if not max or max == 0 then max = ah.dataType.STRING.max end
    length = math.random(min, max)
  end
  return string.rep("a", length)
end

local function getIntegerValue(pTypeData, pValueType)
  local value
  if pValueType == m.valueType.LOWER_IN_BOUND then
    value = pTypeData.minvalue
    if not value then value = ah.dataType.INTEGER.min end
  elseif pValueType == m.valueType.UPPER_IN_BOUND then
    value = pTypeData.maxvalue
    if not value then value = ah.dataType.INTEGER.max end
  elseif pValueType == m.valueType.LOWER_OUT_OF_BOUND then
    value = pTypeData.minvalue
    if not value then value = ah.dataType.INTEGER.min end
    value = value - 1
  elseif pValueType == m.valueType.UPPER_OUT_OF_BOUND then
    value = pTypeData.maxvalue
    if not value then value = ah.dataType.INTEGER.max end
    value = value + 1
  elseif pValueType == m.valueType.VALID_RANDOM then
    local min = pTypeData.minvalue
    local max = pTypeData.maxvalue
    if not min then min = ah.dataType.INTEGER.min end
    if not max then max = ah.dataType.INTEGER.max end
    value = math.random(min, max)
  end
  return value
end

local function getFloatValue(pTypeData, pValueType)
  local value
  if pValueType == m.valueType.LOWER_IN_BOUND then
    value = pTypeData.minvalue
    if not value then value = ah.dataType.FLOAT.min end
  elseif pValueType == m.valueType.UPPER_IN_BOUND then
    value = pTypeData.maxvalue
    if not value then value = ah.dataType.FLOAT.max end
  elseif pValueType == m.valueType.LOWER_OUT_OF_BOUND then
    value = pTypeData.minvalue
    if not value then value = ah.dataType.FLOAT.min end
    value = value - 1
  elseif pValueType == m.valueType.UPPER_OUT_OF_BOUND then
    value = pTypeData.maxvalue
    if not value then value = ah.dataType.FLOAT.max end
    value = value + 1
  elseif pValueType == m.valueType.VALID_RANDOM then
    local min = pTypeData.minvalue
    local max = pTypeData.maxvalue
    if not min then min = ah.dataType.FLOAT.min end
    if not max then max = ah.dataType.FLOAT.max end
    value = tonumber(string.format('%.02f', math.random() + math.random(min, max-1)))
  end
  return value
end

local function getDoubleValue(pTypeData, pValueType)
  local value
  if pValueType == m.valueType.LOWER_IN_BOUND then
    value = pTypeData.minvalue
    if not value then value = ah.dataType.DOUBLE.min end
  elseif pValueType == m.valueType.UPPER_IN_BOUND then
    value = pTypeData.maxvalue
    if not value then value = ah.dataType.DOUBLE.max end
  elseif pValueType == m.valueType.LOWER_OUT_OF_BOUND then
    value = pTypeData.minvalue
    if not value then value = ah.dataType.DOUBLE.min end
    value = value - 1
  elseif pValueType == m.valueType.UPPER_OUT_OF_BOUND then
    value = pTypeData.maxvalue
    if not value then value = ah.dataType.DOUBLE.max end
    value = value + 1
  elseif pValueType == m.valueType.VALID_RANDOM then
    local min = pTypeData.minvalue
    local max = pTypeData.maxvalue
    if not min then min = ah.dataType.DOUBLE.min end
    if not max then max = ah.dataType.DOUBLE.max end
    value = tonumber(string.format('%.02f', math.random() + math.random(min, max-1)))
  end
  return value
end

local function getBooleanValue(_, pValueType)
  if pValueType == m.valueType.VALID_RANDOM then
    return math.random(0, 1) == 1
  end
  return true
end

local function getEnumTypeValue(pTypeData, pValueType)
  if pValueType == m.valueType.UPPER_OUT_OF_BOUND then
    return #pTypeData.data + 1
  elseif pValueType == m.valueType.VALID_RANDOM then
    return pTypeData.data[math.random(1, #pTypeData.data)]
  end
  return pTypeData.data[1]
end

local function getStructValues(pTypeData, pValueTypesMap, pArrayValueTypesMap)
  local out = {}
  for k, v in pairs(pTypeData.data) do
    out[k] = m.getValue(k, v, pValueTypesMap, pArrayValueTypesMap)
  end
  return out
end

local function getTypeValue(pParamName, pTypeData, pValueTypesMap, pArrayValueTypesMap)
  local valueType = m.valueType.LOWER_IN_BOUND
  if pValueTypesMap[pParamName] then valueType = pValueTypesMap[pParamName] end
  if pTypeData.type == ah.dataType.INTEGER.type then
    return getIntegerValue(pTypeData, valueType)
  elseif pTypeData.type == ah.dataType.FLOAT.type then
    return getFloatValue(pTypeData, valueType)
  elseif pTypeData.type == ah.dataType.DOUBLE.type then
    return getDoubleValue(pTypeData, valueType)
  elseif pTypeData.type == ah.dataType.STRING.type then
    return getStringValue(pTypeData, valueType)
  elseif pTypeData.type == ah.dataType.BOOLEAN.type then
    return getBooleanValue()
  elseif pTypeData.type == ah.dataType.ENUM.type then
    return getEnumTypeValue(pTypeData, valueType)
  elseif pTypeData.type == ah.dataType.STRUCT.type then
    return getStructValues(pTypeData, pValueTypesMap, pArrayValueTypesMap)
  end
end

local function getNumOfItems(pParamName, pTypeData, pArrayValueTypesMap)
  local arrayValueType = m.valueType.LOWER_IN_BOUND
  if pArrayValueTypesMap[pParamName] then arrayValueType = pArrayValueTypesMap[pParamName] end
  local numOfItems = -1
  if pTypeData.array == true then
    if arrayValueType == m.valueType.LOWER_IN_BOUND then
      numOfItems = pTypeData.minsize
      if not numOfItems or numOfItems == 0 then numOfItems = 1 end
    elseif arrayValueType == m.valueType.UPPER_IN_BOUND then
      numOfItems = pTypeData.maxsize
      if not numOfItems or numOfItems == 0 then numOfItems = 1 end
    elseif arrayValueType == m.valueType.LOWER_OUT_OF_BOUND then
      numOfItems = pTypeData.minsize
      if not numOfItems or numOfItems == 0 then numOfItems = 1 end
      numOfItems = numOfItems - 1
    elseif arrayValueType == m.valueType.UPPER_OUT_OF_BOUND then
      numOfItems = pTypeData.maxsize
      if not numOfItems or numOfItems == 0 then numOfItems = 1 end
      numOfItems = numOfItems + 1
    elseif arrayValueType == m.valueType.VALID_RANDOM then
      local min = pTypeData.minsize
      local max = pTypeData.maxsize
      if not min or min == 0 then min = 1 end
      if not max or max == 0 then max = 5 end
      numOfItems = math.random(min, max)
    end
  end
  return numOfItems
end

function m.getValue(pParamName, pTypeData, pValueTypesMap, pArrayValueTypesMap)
  local numOfItems = getNumOfItems(pParamName, pTypeData, pArrayValueTypesMap)
  if numOfItems == -1 then
    return getTypeValue(pParamName, pTypeData, pValueTypesMap, pArrayValueTypesMap)
  else
    local out = {}
    for _ = 1, numOfItems do
      table.insert(out, getTypeValue(pParamName, pTypeData, pValueTypesMap, pArrayValueTypesMap))
   end
    return out
  end
end

function m.getParamValues(pParamsData, pValueTypesMap, pArrayValueTypesMap)
  if not pValueTypesMap then pValueTypesMap = {} end
  if not pArrayValueTypesMap then pArrayValueTypesMap = {} end
  local out = {}
  for k, v in pairs(pParamsData) do
    out[k] = m.getValue(k, v, pValueTypesMap, pArrayValueTypesMap)
  end
  return out
end

return m
