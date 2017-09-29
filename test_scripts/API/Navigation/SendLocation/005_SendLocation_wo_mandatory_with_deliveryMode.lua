---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/24
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/TRS/embedded_navi/SendLocation_TRS.md
-- Item: Use Case 1: Main Flow
--
-- Requirement summary:
-- App requests SendLocation with deliveryMode, other valid and allowed parameters and without address, latitudeDegrees and longitudeDegrees
--
-- Description:
-- App sends SendLocation without addrress, longitudeDegrees or latitudeDegrees parameters.

-- Pre-conditions:
-- a. HMI and SDL are started
-- b. appID is registered on SDL

-- Steps:
-- appID requests SendLocation with address, longitudeDegrees, latitudeDegrees, deliveryMode and other parameters

-- Expected:

-- SDL validates parameters of the request
-- SDL respond to the App with resultCode=INVALID_DATA, success=false

---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonSendLocation = require('test_scripts/API/SendLocation/commonSendLocation')

--[[ Local Variables ]]
local request_params = {
    longitudeDegrees = 1.1,
    latitudeDegrees = 1.1,
    addressLines = 
    { 
        "line1",
        "line2",
    },
    timeStamp = {
        millisecond = 0,
        second = 40,
        minute = 30,
        hour = 14,
        day = 25,
        month = 5,
        year = 2017,
        tz_hour = 5,
        tz_minute = 30
    },
    locationName = "location Name",
    locationDescription = "location Description",
    phoneNumber = "phone Number",
    deliveryMode = "PROMPT",
    locationImage = 
    { 
        value = "icon.png",
        imageType = "DYNAMIC",
    }
}

--[[ Local Functions ]]
local function sendLocation(params, parametersToCut, self)
    for _,paramToCutOff in pairs(parametersToCut) do
        params[paramToCutOff] = nil
    end
    local cid = self.mobileSession1:SendRPC("SendLocation", params)

    params.appID = commonSendLocation.getHMIAppId()
    local deviceID = commonSendLocation.getDeviceMAC()
    params.locationImage.value = commonSendLocation.getPathToSDL() .. "storage/"
        .. commonSendLocation.getMobileAppId(1) .. "_" .. deviceID .. "/icon.png"


    EXPECT_HMICALL("Navigation.SendLocation", params)
    :Times(0)

    self.mobileSession1:ExpectResponse(cid, { success = false, resultCode = "INVALID_DATA" })

    commonSendLocation.delayedExp()
end

local function put_file(self)
    local CorIdPutFile = self.mobileSession1:SendRPC(
      "PutFile",
      {syncFileName = "icon.png", fileType = "GRAPHIC_PNG", persistentFile = false, systemFile = false},
      "files/icon.png")

    self.mobileSession1:ExpectResponse(CorIdPutFile, { success = true, resultCode = "SUCCESS"})
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonSendLocation.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonSendLocation.start)
runner.Step("RAI, PTU", commonSendLocation.registerApplicationWithPTU)
runner.Step("Activate App", commonSendLocation.activateApp)
runner.Step("Upload file", put_file)

runner.Title("Test")
runner.Step("SendLocation witout mandatory longitudeDegrees", sendLocation, {request_params, {"longitudeDegrees"}})
runner.Step("SendLocation witout mandatory latitudeDegrees", sendLocation, {request_params, {"latitudeDegrees"}})
runner.Step("SendLocation witout both mandatory params", sendLocation, {request_params, {"longitudeDegrees", "latitudeDegrees"}})

runner.Title("Postconditions")
runner.Step("Stop SDL", commonSendLocation.postconditions)
