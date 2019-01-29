--  Requirement summary:
--  [RegisterAppInterface] SUCCESS
--  [RegisterAppInterface] RegisterAppInterface and HMILevel
--
--  Description:
--  Check that it is able to register up to 5 Apps on different connections via one transport.
--
--  1. Used precondition
--  SDL, HMI are running on system.
--
--  2. Performed steps
--  1st mobile device connect to system
--  appID_1->RegisterAppInterface(params)
--  2nd mobile device connect to system
--  appID_2->RegisterAppInterface(params)
--  3rd mobile device connect to system
--  appID_3->RegisterAppInterface(params)
--  4th mobile device connect to system
--  appID_4->RegisterAppInterface(params)
--  5th mobile device connect to system
--  appID_5->RegisterAppInterface(params)
--
--  Expected behavior:
--  1. SDL successfully registers all five applications and notifies HMI and mobile
--     SDL->HMI: OnAppRegistered(params)
--     SDL->appID: SUCCESS, success:"true":RegisterAppInterface()
--  2. SDL assignes HMILevel after application registering:
--     SDL->appID: OnHMIStatus(HMlLevel, audioStreamingState, systemContext)
---------------------------------------------------------------------------------------------------

--[[ Required Shared Libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Smoke/commonSmoke')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local devices = {
  [1] = "1.0.0.1",
  [2] = "192.168.100.199",
  [3] = "10.42.0.1",
  [4] = "2.0.0.2",
  [5] = "8.8.8.8"
}

--[[ Local Variables ]]
local function start()
  local event = common.createEvent()
  common.init.SDL()
  :Do(function()
      common.init.HMI()
      :Do(function()
          common.init.HMI_onReady()
          :Do(function()
              common.getHMIConnection():RaiseEvent(event, "Start event")
            end)
        end)
    end)
  return common.getHMIConnection():ExpectEvent(event, "Start event")
end

local function getDeviceName(pDevice)
  return pDevice .. ":" .. config.mobilePort
end

local function getDeviceMAC(pDevice)
  return common.execCmd("echo -n " .. getDeviceName(pDevice) .. " | sha256sum | awk '{printf $1}'")
end

local function registerApp(pAppId)
  common.createMobileSession(pAppId, nil, pAppId)
  common.getMobileSession(pAppId):StartService(7)
  :Do(function()
      local corId = common.getMobileSession(pAppId):SendRPC("RegisterAppInterface", common.getConfigAppParams(pAppId))
      common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppRegistered",
        { application = {
          appName = common.getConfigAppParams(pAppId).appName,
          appID = common.getHMIAppId(pAppId),
          deviceInfo = {
            name = getDeviceName(devices[pAppId]),
            id = getDeviceMAC(devices[pAppId])
          }
        }
      })
      common.getMobileSession(pAppId):ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
      :Do(function()
          common.getMobileSession(pAppId):ExpectNotification("OnHMIStatus",
            { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
        end)
    end)
end

local function preconditions()
  common.preconditions()
  for i = 1, #devices do
    common.dummyConnection.add(i, devices[i])
  end
end

local function postconditions()
  common.postconditions()
  for i = 1, #devices do
    common.dummyConnection.delete(i)
  end
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", preconditions)
runner.Step("Start SDL, HMI, connect Mobile", start)

runner.Title("Test")
for i = 1, #devices do
  runner.Step("Create connection " .. i, common.createConnection, { i, devices })
  runner.Step("Register App " .. i, registerApp, { i })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", postconditions)
