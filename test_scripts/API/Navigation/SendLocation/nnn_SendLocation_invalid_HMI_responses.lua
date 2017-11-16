---------------------------------------------------------------------------------------------
-- Requirements: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/TRS/embedded_navi/SendLocation_TRS.md
--
-- Requirement summary:
-- 1. HMI sends invalid response to SDL
-- 2. SDL responds GENERIC_ERROR, success:false
--
-- Description:
-- SDL responds GENERIC_ERROR, success:false in case of receiving invalid response from HMI
--
-- Steps:
-- App requests SendLocation
-- HMI responds with invalid respone(mandatory missing, invalid json, invalid value of parametes)
--
-- Expected:
-- SDL responds GENERIC_ERROR, success:false
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonSendLocation = require('test_scripts/API/Navigation/commonSendLocation')
local json = require("json")

--[[ Local Variables ]]
local HMIresponses = {
    method_Missing = { jsonrpc = "2.0", result = { code = 0 }},
    method_WrongType = { jsonrpc = "2.0", result = { method = 3 ,code = 0 }},
    method_WrongValue = { jsonrpc = "2.0", result = { method = "ANY" ,code = 0 }},
    method_AnotherRPC = { jsonrpc = "2.0", result = { method = "Navigation.ShowConstantTBT", code = 0 }},
    code_Missing = { jsonrpc = "2.0", result = { method = "Navigation.SendLocation" }},
    code_WrongType = { jsonrpc = "2.0", result = { method = "Navigation.SendLocation", code = "0" }},
    code_WrongValue = { jsonrpc = "2.0", result = { method = "Navigation.SendLocation", code = 1111 }},
    result_Missing = { jsonrpc = "2.0" },
    result_WrongType = { jsonrpc = "2.0", result = 0 }
}

local HMIresponsesIdCheck = {
    id_Missing = { jsonrpc = "2.0", result = { method = "Navigation.SendLocation", code = 0 }},
    id_WrongType = { jsonrpc = "2.0", id = "35", result = { method = "Navigation.SendLocation", code = 0 }},
    id_WrongValue = { jsonrpc = "2.0", id = 1111, result = { method = "Navigation.SendLocation", code = 0 }},
}

--[[ Local Functions ]]
local function sendLocation(paramsResponse, idValue, self)
    local params = {
        longitudeDegrees = 1.1,
        latitudeDegrees = 1.1
    }

    local cid = self.mobileSession1:SendRPC("SendLocation", params)

    EXPECT_HMICALL("Navigation.SendLocation")
    :Do(function(_,data)
        if idValue == true then
            paramsResponse.id = data.id
        end
        local text
        if type(paramsResponse) ~= "string" then
            text = json.encode(paramsResponse)
        else
            text = paramsResponse
        end
        self.hmiConnection:Send(text)
    end)

    self.mobileSession1:ExpectResponse(cid, { success = false, resultCode = "GENERIC_ERROR" })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonSendLocation.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonSendLocation.start)
runner.Step("RAI, PTU first app", commonSendLocation.registerApplicationWithPTU)
runner.Step("Activate first App", commonSendLocation.activateApp)

runner.Title("Test")
for key, value in pairs(HMIresponses) do
    runner.Step("SendLocation_" .. tostring(key), sendLocation, { value, true })
end

runner.Step("SendLocation_invalid_json", sendLocation,
    { '"jsonrpc":"2.0","result":{"method""Navigation.SendLocation"}', false })

for key, value in pairs(HMIresponsesIdCheck) do
    runner.Step("SendLocation_" .. tostring(key), sendLocation, { value, false })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", commonSendLocation.postconditions)
