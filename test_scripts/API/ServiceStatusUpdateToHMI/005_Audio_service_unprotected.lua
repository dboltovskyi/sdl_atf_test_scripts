---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: Opening of the not protected Audio service with succeeded OnStatusUpdate notifications
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (Audio, encryption = false)
-- SDL does:
-- 1) send StartAudioStream() to HMI
-- 2) send OnServiceUpdate (AUDIO, REQUEST_RECEIVED) to HMI
-- 3) send StartServiceACK(Audio, encryption = false) to mobile app
-- 3) send OnServiceUpdate (AUDIO, REQUEST_ACCEPTED) to HMI
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

function common.serviceResponseFunc(pServiceId, pStreamingFunc)
  common.getMobileSession():ExpectControlMessage(pServiceId, {
    frameInfo = common.const.FRAME_INFO.START_SERVICE_ACK,
    encryption = false
  })
  :Do(function(_, data)
    if data.frameInfo == common.const.FRAME_INFO.START_SERVICE_ACK then
      pStreamingFunc()
    end
  end)
end

function common.policyTableUpdateFunc()
  common.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate")
  :Times(0)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("App activation", common.activateApp)

runner.Title("Test")
runner.Step("Start Audio Service unprotected", common.startServiceWithOnServiceUpdate, { 10, 0, 0 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
