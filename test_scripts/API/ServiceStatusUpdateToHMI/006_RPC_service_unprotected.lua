---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: Opening of the not protected RPC service with succeeded OnStatusUpdate notifications
-- Precondition:
-- 1) App is connected with NAVIGATION appHMIType
-- In case:
-- 1) Mobile app requests StartService (RPC, encryption = false)
-- SDL does:
-- 1) send OnServiceUpdate (RPC, REQUEST_RECEIVED) to HMI
-- 2) send OnServiceUpdate (RPC, REQUEST_ACCEPTED) to HMI
-- 3) send StartServiceACK(RPC, encryption = false) to mobile app
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
function common.startServiceFunc(pServiceId)
  local msg = {
    frameType = common.const.FRAME_TYPE.CONTROL_FRAME,
    serviceType = pServiceId,
    frameInfo = common.const.FRAME_INFO.START_SERVICE,
    encryption = false
  }
  common.getMobileSession():Send(msg)
end

function common.serviceResponseFunc(pServiceId)
  common.getMobileSession():ExpectControlMessage(pServiceId, {
    frameInfo = common.const.FRAME_INFO.START_SERVICE_ACK,
    encryption = false
  })
end

function common.policyTableUpdateFunc()
  -- common.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate")
  -- :Times(0) -- There is an issue: SDL sends 'UPDATE_NEEDED' if it was build in EXTERNAL_PROPRIETARY mode
end

function common.onServiceUpdateFunc(pServiceTypeValue)
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
    { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue },
    { serviceEvent = "REQUEST_ACCEPTED", serviceType = pServiceTypeValue })
  :Times(2)
  :ValidIf(function(_, data)
    if data.params.appID then
      return false, "OnServiceUpdate notification contains unexpected appID"
    end
    return true
  end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Test")
runner.Step("Start RPC Service unprotected", common.startServiceWithOnServiceUpdate, { 7, 0, 0 } )

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
