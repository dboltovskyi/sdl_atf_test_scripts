---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0160-rc-radio-parameter-update.md
-- User story: TBD
--
-- Requirement summary:
-- TBD
--
-- Description:
-- In case:
-- 1) Application is registered with REMOTE_CONTROL appHMIType
-- 2) and sends valid SetInteriorVehicleData RPC with max value for hdChannel
-- 3) HMI sends OnInteriorVehicleData with max value for availableHDs
-- SDL must:
-- 1) Transfer this request to HMI
-- 2) Respond with <result_code> received from HMI
-- 3) Transfer notification to mobile application
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')

--[[ Local Variables ]]
local Module = "RADIO"

--[[ Local Functions ]]
local function setVehicleData(self)
  local requestParams = commonRC.getSettableModuleControlData(Module)
  requestParams.radioControlData.hdChannel = 7

  local cid = self.mobileSession1:SendRPC("SetInteriorVehicleData", {
	moduleData = requestParams
  })

  EXPECT_HMICALL("RC.SetInteriorVehicleData",	{
	appID = self.applications["Test Application"],
	moduleData = requestParams
  })
  :Do(function(_, data)
	self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {
	  moduleData = requestParams
	})
  end)

  self.mobileSession1:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
end

local function onVehicleData(self)
  local notificationParams = commonRC.getHMIResponseParams("OnInteriorVehicleData", Module)
  notificationParams.moduleData.radioControlData.availableHDs = 7

  self.hmiConnection:SendNotification(commonRC.getHMIEventName("OnInteriorVehicleData"), notificationParams)
  self.mobileSession1:ExpectNotification(commonRC.getAppEventName("OnInteriorVehicleData"), notificationParams)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI, PTU", commonRC.rai_ptu)
runner.Step("Activate App", commonRC.activate_app)
runner.Step("Subscribe app to " .. Module, commonRC.subscribeToModule, { Module })

runner.Title("Test")

runner.Step("SetInteriorVehicleData with max value for hdChannel", setVehicleData)
runner.Step("OnInteriorVehicleData with max value for availableHDs", onVehicleData)

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
