---------------------------------------------------------------------------------------------
-- Requirements summary:
-- [PerformAudioPassThru] requested "ttsChunks" is NOT supported
-- [HMI API] UI.PerformAudioPassThru request/response
-- [HMI API] TTS.Speak request/response
-- [Mobile API] PerformAudioPassThru request/response
-- [HMI_API] [MOBILE_API] The "audioPassThruIcon" param at "ImageFieldName" struct
--
-- Description:
-- In case mobile app requests "ttsChunks" with type is different from "TEXT" 
-- (SAPI_PHONEMES, LHPLUS_PHONEMES, PRE_RECORDED or SILENCE), 
-- SDL must: transfer this "ttsChunks" to HMI and respond with 
-- "WARNINGS, success:true" + info: <message_from_HMI> to mobile app
-- IN CASE HMI respond with UNSUPPORTED_RESOURCE (Note: TTS interface is supported)
--
-- 1. Used preconditions
-- 1.1. PerformAudioPassThru RPC is allowed by policy
-- 1.2. All parameters are present and within bounds speech capabilities is sent with type = "SILENCE"
-- 1.3. AudioPassThruIcon exists at apps sub-directory of AppStorageFolder (value from ini file)
--
-- 2. Performed steps
-- Send PerformAudioPassThru (audioPassThruIcon, other params, ttsChunksType = "SILENCE") from mobile to SDL and check:
-- 2.1 SDL sends UI.PerformAudioPassThru (audioPassThruIcon, other params) to HMI
-- 2.2 SDL sends TTS.Speak (ttsChunksType = "SILENCE")to HMI
-- 2.3 HMI sends UI.PerformAudioPassThru (SUCCESS) to SDL
-- 2.4 HMI sends TTS.Speak (WARNINGS, <message>) to SDL
--
-- Expected result:
-- SDL sends PerformAudioPassThru (WARNINGS, success:true, info: <message>)to mobile app
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonFunctions = require('user_modules/shared_testcases/commonFunctions')
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local commonPostconditions = require('user_modules/shared_testcases/commonPreconditions')
local testCasesForPerformAudioPassThru = require('user_modules/shared_testcases/testCasesForPerformAudioPassThru')
local testCasesForPolicyTable = require('user_modules/shared_testcases/testCasesForPolicyTable')

--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFiles()
config.defaultProtocolVersion = 2

testCasesForPolicyTable:precondition_updatePolicy_AllowFunctionInHmiLeves({"BACKGROUND", "FULL", "LIMITED"},"PerformAudioPassThru")

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

commonSteps:PutFile("Precondition_PutFile_With_Icon","icon.png")

function Test:Precondition_Check_audioPassThruIcon_Existence()
  testCasesForPerformAudioPassThru:Check_audioPassThruIcon_Existence(self)
end

function Test:Precondition_ActivateApp()
  testCasesForPerformAudioPassThru:ActivateAppDiffPolicyFlag(self, config.application1.registerAppInterfaceParams.appName, config.deviceMAC)
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:TestStep_PerformAudioPassThru_SILENCE_WARNINGS()
    local CorIdPerformAudioPassThruSpeechCap = self.mobileSession:SendRPC("PerformAudioPassThru",
      {
        initialPrompt = {{text = "SILENCE",type = "SILENCE"}},
        audioPassThruDisplayText1 = "DisplayText1",
        audioPassThruDisplayText2 = "DisplayText2",
        samplingRate = "8KHZ",
        maxDuration = 2000,
        bitsPerSample = "8_BIT",
        audioType = "PCM",
        muteAudio = true,
	      audioPassThruIcon =
	        { 
            value = "icon.png",
	        	imageType = "STATIC"
	        }
      })

    EXPECT_HMICALL("TTS.Speak",
      {
        speakType = "AUDIO_PASS_THRU",
        ttsChunks =
          {{
              text = SILENCE,
              type = SILENCE
          }}
      })
    :Do(function(_,data)
        self.hmiConnection:SendResponse(data.id, "TTS.Speak", "WARNINGS", {})
      end)

    EXPECT_HMICALL("UI.PerformAudioPassThru",
      {
        appID = self.applications[config.application1.registerAppInterfaceParams.appName],
        audioPassThruDisplayTexts = {
          {fieldName = "audioPassThruDisplayText1", fieldText = "DisplayText1"},
          {fieldName = "audioPassThruDisplayText2", fieldText = "DisplayText2"},
        },
        maxDuration = 2000,
        muteAudio = true,
        audioPassThruIcon = 
          { 
            value = "icon.png",
            imageType = "STATIC"          
          }
      })
    :Do(function(_,data)
        self.hmiConnection:SendResponse(data.id, "UI.PerformAudioPassThru", "SUCCESS", {})
    end)

    self.mobileSession:ExpectResponse(CorIdPerformAudioPassThruSpeechCap, {success = true, resultCode = "WARNINGS"})

end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test.Postcondition_Restore_preloaded_pt_File()
	commonPostconditions:RestoreFile("sdl_preloaded_pt.json")
end

function Test.Postcondition_Stop_SDL()
  StopSDL()
end

return Test
