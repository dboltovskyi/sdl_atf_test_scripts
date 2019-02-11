---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: The attempt to open the protected Video, Audio, RPC services with unsuccessful
--  OnStatusUpdate(REQUEST_REJECTED, INVALID_TIME) notification by receiving GetSystemTime response with invalid result
--  code from HMI and services are not force protected and not force unprotected
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (Video encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (VIDEO, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- In case: HMI provides invalid GetSystemTime_Res()
-- SDL does:
-- 1) send OnServiceUpdate (RPC, INVALID_TIME) to HMI (for RPC ServiceType)
-- 2) send StartServiceNACK (RPC, encryption = false) to mobile app
-- 3) send OnServiceUpdate (SERVICETYPE, REQUEST_ACCEPTED) to HMI (for Audio, Video ServiceType)
-- 4) send StartServiceACK (SERVICETYPE, encryption = false) to mobile app (for Audio, Video ServiceType)
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
function common.sendGetSystemTimeResponse(pId, pMethod)
  common.getHMIConnection():SendError(pId, pMethod, "DATA_NOT_AVAILABLE", "Time is not provided")
end

function common.onServiceUpdateFunc(pServiceTypeValue)
  if pServiceTypeValue == "RPC" then
    common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
      { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() },
      { serviceEvent = "REQUEST_REJECTED", serviceType = pServiceTypeValue, appID = common.getHMIAppId(),
        reason = "INVALID_TIME" })
    :Times(2)
  else
    common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
      { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() },
      { serviceEvent = "REQUEST_ACCEPTED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() })
    :Times(2)
  end
end

function common.serviceResponseFunc(pServiceId, pStreamingFunc)
  common.serviceResponseWithACKandNACK(pServiceId, pStreamingFunc, 11000)
end

function common.policyTableUpdateFunc()
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("App activation", common.activateApp)

runner.Title("Test")
runner.Step("Start Video Service protected with invalid response to GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 11, 0, 1 })
runner.Step("Start Audio Service protected with invalid response to GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 10, 0, 1 })
runner.Step("Start RPC Service protected with invalid response to GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 7, 0, 1 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
