---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: The attempt to open the protected AUDIO service with unsuccessful OnStatusUpdate(REQUEST_REJECTED,
-- PTU_FAILED) notification by unsuccessful PTU
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (AUDIO, encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (AUDIO, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- 4) send OnStatusUpdate(UPDATE_NEEDED)
-- In case:
-- 2) Policy Table Update is Failed (Time out)
-- SDL does:
-- 1) send OnServiceUpdate (AUDIO, PTU_FAILED) to HMI
-- 2) send StartServiceNACK(AUDIO, encryption = false) to mobile app
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Constants ]]
local serviceId = 10
local numOfIter = 2
local tollerance = 200 -- ms

--[[ Local Variables ]]
local timeout = 10000 * numOfIter
local expOccur = numOfIter * 2 + 1
local retryFinishedTime = 0
local serviceNackTime = 0

--[[ Local Functions ]]
function common.onServiceUpdateFunc(pServiceTypeValue)
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
    { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() },
    { serviceEvent = "REQUEST_REJECTED", serviceType = pServiceTypeValue, appID = common.getHMIAppId(),
      reason = "PTU_FAILED" })
  :Times(2)
  :Timeout(timeout)
end

function common.serviceResponseFunc(pServiceId)
  common.getMobileSession():ExpectControlMessage(pServiceId, {
    frameInfo = common.frameInfo.START_SERVICE_NACK,
    encryption = false
  })
  :Do(function(_, data)
      if data.frameInfo == common.frameInfo.START_SERVICE_NACK then
        serviceNackTime = timestamp()
      end
    end)
  :Timeout(timeout)
end

local function ptUpdate(pTbl)
  local retries = {}
  for _ = 1, numOfIter do
    table.insert(retries, 1)
  end
  pTbl.policy_table.module_config.timeout_after_x_seconds = 5
  pTbl.policy_table.module_config.seconds_between_retries = retries
end

function common.policyTableUpdateFunc()
  function common.policyTableUpdate()
    local cid = common.getHMIConnection():SendRequest("SDL.GetURLS", { service = 7 })
    common.getHMIConnection():ExpectResponse(cid)
    :Do(function()
        common.getHMIConnection():SendNotification("BasicCommunication.OnSystemRequest",
          { requestType = "PROPRIETARY", fileName = "files/ptu.json" })
        common.getMobileSession():ExpectNotification("OnSystemRequest", { requestType = "PROPRIETARY" })
      end)
  end
  local expRes = {}
  for _ = 1, numOfIter do
    table.insert(expRes, { status = "UPDATE_NEEDED" })
    table.insert(expRes, { status = "UPDATING" })
  end
  table.insert(expRes, { status = "UPDATE_NEEDED" })
  common.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate", unpack(expRes))
  :Times(expOccur)
  :Do(function(e, d)
      common.log("SDL->HMI:", d.method, d.params.status)
      if e.occurences == expOccur then
        retryFinishedTime = timestamp()
      end
    end)
  :Timeout(timeout)
  common.policyTableUpdateUnsuccess()
  common.wait(timeout)
end

local function validateResult()
  common.cprint(35, "serviceNackTime:", serviceNackTime)
  common.cprint(35, "retryFinishedTime:", retryFinishedTime)
  if serviceNackTime == 0 then
    common.failTestCase("START_SERVICE_NACK was not sent by SDL")
  elseif retryFinishedTime == 0 then
    common.failTestCase("Retry sequence was not finished")
  else
    local delay = math.abs(serviceNackTime - retryFinishedTime)
    common.cprint(35, "Delay (ms):", delay)
    if math.abs(delay - tollerance) > tollerance then
      common.failTestCase("There to much delay between START_SERVICE_NACK and finishing of Retry sequence")
    end
  end
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions, { common.serviceData[serviceId].forceCode })
runner.Step("Init SDL certificates", common.initSDLCertificates,
  { "./files/Security/client_credential_expired.pem", false })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate, { ptUpdate })
runner.Step("App activation", common.activateApp)

runner.Title("Test")
runner.Step("Start " .. common.serviceData[serviceId].serviceType .. " service protected",
  common.startServiceWithOnServiceUpdate, { serviceId, 0, 1 })
runner.Step("Validate Result", validateResult)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
