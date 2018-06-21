---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary:
-- TBD
--
-- Description:
-- In case:
-- 1) Application is registered with PROJECTION appHMIType
-- 2) and starts audio streaming
-- 3)user performs 'user exit'
-- SDL must:
-- 1) stop service
-- 2) after activation start service successfully
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/MobileProjection/Phase1/common')
local runner = require('user_modules/script_runner')
local events = require('events')
local constants = require('protocol_handler/ford_protocol_constants')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local appHMIType = "PROJECTION"
local FileForStreaming = "files/MP3_4555kb.mp3"
local Service = 10

--[[ General configuration parameters ]]
config.application1.registerAppInterfaceParams.appHMIType = { appHMIType }

--[[ Local Functions ]]
local function ptUpdate(pTbl)
  pTbl.policy_table.app_policies[common.getAppID()].AppHMIType = { appHMIType }
end

local function EndServiceByUserExit()
  local EndServiceEvent = events.Event()
  EndServiceEvent.matches =
	function(_, data)
      return data.frameType == constants.FRAME_TYPE.CONTROL_FRAME and
      data.serviceType == constants.SERVICE_TYPE.PCM and
      data.sessionId == common.getMobileSession().sessionId and
      data.frameInfo == constants.FRAME_INFO.END_SERVICE
	end
  common.getMobileSession():ExpectEvent(EndServiceEvent, "Expect EndServiceEvent")
  :Do(function( )
	  common.getMobileSession():Send({
	  frameType = constants.FRAME_TYPE.CONTROL_FRAME,
	  serviceType = constants.SERVICE_TYPE.PCM,
	  frameInfo = constants.FRAME_INFO.END_SERVICE_ACK
	})
  end)
  common.getHMIConnection():SendNotification("BasicCommunication.OnExitApplication",
	{ appID = common.getHMIAppId(), reason = "USER_EXIT" })
  common.getMobileSession():ExpectNotification("OnHMIStatus",
	{ systemContext = "MAIN", hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE" })
  EXPECT_HMICALL("Navigation.StopAudioStream")
	:Do(function(_,data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { })
  end)
  EXPECT_HMINOTIFICATION("Navigation.OnAudioDataStreaming", { available = false })
end

local function RestoreService()
  common.getMobileSession():StartService(Service)
  EXPECT_HMICALL("Navigation.StartAudioStream")
  :Do(function(_,data)
	common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS",  {})
  end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("Register App", common.registerApp)
runner.Step("PolicyTableUpdate with HMI types", common.policyTableUpdate, { ptUpdate })
runner.Step("Activate App", common.activateApp)
runner.Step("Start audio service", common.startService, { Service })
runner.Step("Start audio streaming", common.StartStreaming, { Service, FileForStreaming })

runner.Title("Test")
runner.Step("EndService by USER_EXIT", EndServiceByUserExit)
runner.Step("Activate App after user exit", common.activateApp)
runner.Step("Restoring audio service", RestoreService)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
