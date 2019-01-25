---------------------------------------------------------------------------------------------------
-- Proposal:
-- User story: TBD
--
-- Requirement summary:
-- TBD
--
-- Description:
-- Preconditions:
-- Mobile app is registered with SyncMsgVersion = 5.1
-- SDL got RC.GetCapabilities for CLIMATE module with new ("climateEnableAvailable" = true) parameter from HMI
-- In case:
-- 1) Mobile app sends SetInteriorVehicleData with parameter ("climateEnable" = false) to SDL
-- 2) HMI sends response RC.SetInteriorVehicleData ("climateEnable" = false)
-- SDL must:
-- 1) sends RC.SetInteriorVehicleData (CLIMATE ("climateEnable" = false)) to HMI
-- 2) send SetInteriorVehicleData  with ("resultCode" = SUCCESS) to Mobile
--
-- In case:
-- 1) Mobile app sends SetInteriorVehicleData  request parameter ("climateEnable" = true) to SDL
-- 2) HMI sends RC.SetInteriorVehicleData response ("climateEnable" = true)
-- SDL must:
-- 1) sends RC.SetInteriorVehicleData request (CLIMATE ("climateEnable" = true)) to HMI
-- 2) sends SetInteriorVehicleData response with ("resultCode" = SUCCESS) to Mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

local params = {
  true,
  false
}

local function setVehicleData(pParams)
  local mobSession = commonRC.getMobileSession()
  local cid = mobSession:SendRPC("SetInteriorVehicleData", {
    moduleData = {
      moduleType = "CLIMATE",
      climateControlData = { climateEnable = pParams}
    }
  })

  EXPECT_HMICALL("RC.SetInteriorVehicleData", {
  moduleData = {
    moduleType = "CLIMATE",
    climateControlData = { climateEnable = pParams}
  },
  appID = commonRC.getHMIAppId()
  })
  :Do(function(_, data)
  commonRC.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {
    moduleData = {
      moduleType = "CLIMATE",
      climateControlData = { climateEnable = pParams}
    }
  })
  end)

  mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI", commonRC.registerAppWOPTU)
runner.Step("Activate App", commonRC.activateApp)

runner.Title("Test")

for _, v in pairs(params) do
  runner.Step("SetInteriorVehicleData climateEnable " .. _, setVehicleData, { v })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
