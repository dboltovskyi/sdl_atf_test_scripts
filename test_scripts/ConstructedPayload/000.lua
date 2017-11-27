---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary:
-- TBD
--
-- Description:
-- In case:
-- TBD
-- SDL must:
-- TBD
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/ConstructedPayload/commonConstructedPayload')
local bson = require('bson4lua')

--[[ Local Variables ]]
local hashId = {
  [common.serviceType.RPC] = 0,
  [common.serviceType.PCM] = 0,
  [common.serviceType.VIDEO] = 0
}

local testCases = {}
testCases[1] = {
  name = "Start Service RPC ACK",
  service = common.serviceType.RPC,
  request = {
    frameInfo = common.frameInfo.START_SERVICE,
    params = {
      protocolVersion = {
        type = common.bsonType.STRING,
        value = "5.0.0"
      }
    }
  },
  response = {
    frameInfo = common.frameInfo.START_SERVICE_ACK,
    params = {
      hashId = {
        type = common.bsonType.INT32,
        value = 65537
      },
      mtu = {
        type = common.bsonType.INT64,
        value = 131072
      },
      protocolVersion = {
        type = common.bsonType.STRING,
        value = "5.0.0"
      }
    }
  }
}

testCases[2] = {
  name = "Start Service RPC NACK",
  service = common.serviceType.RPC,
  request = {
    frameInfo = common.frameInfo.START_SERVICE,
    params = {
      protocolVersion = {
        type = common.bsonType.STRING,
        value = "5.0.0"
      }
    }
  },
  response = {
    frameInfo = common.frameInfo.START_SERVICE_NACK,
    params = { }
  }
}

testCases[3] = {
  name = "Start Service Audio ACK",
  service = common.serviceType.PCM,
  request = {
    frameInfo = common.frameInfo.START_SERVICE,
    params = { }
  },
  response = {
    frameInfo = common.frameInfo.START_SERVICE_ACK,
    params = {
      hashId = {
        type = common.bsonType.INT32,
        value = 65537
      },
      mtu = {
        type = common.bsonType.INT64,
        value = 131072
      }
    }
  }
}

testCases[4] = {
  name = "Start Service Audio NACK",
  service = common.serviceType.PCM,
  request = {
    frameInfo = common.frameInfo.START_SERVICE,
    params = { }
  },
  response = {
    frameInfo = common.frameInfo.START_SERVICE_NACK,
    params = { }
  }
}

testCases[5] = {
  name = "Start Service Video ACK",
  service = common.serviceType.VIDEO,
  request = {
    frameInfo = common.frameInfo.START_SERVICE,
    params = {
      height = {
        type = common.bsonType.INT32,
        value = 240
      },
      width = {
        type = common.bsonType.INT32,
        value = 320
      },
      videoProtocol = {
        type = common.bsonType.STRING,
        value = "RAW"
      },
      videoCodec = {
        type = common.bsonType.STRING,
        value = "H264"
      }
    }
  },
  response = {
    frameInfo = common.frameInfo.START_SERVICE_ACK,
    params = {
      hashId = {
        type = common.bsonType.INT32,
        value = 65537
      },
      mtu = {
        type = common.bsonType.INT64,
        value = 131072
      },
      height = {
        type = common.bsonType.INT32,
        value = 240
      },
      width = {
        type = common.bsonType.INT32,
        value = 320
      },
      videoProtocol = {
        type = common.bsonType.STRING,
        value = "RAW"
      },
      videoCodec = {
        type = common.bsonType.STRING,
        value = "H264"
      }
    }
  }
}

testCases[6] = {
  name = "Start Service Video NACK",
  service = common.serviceType.VIDEO,
  request = {
    frameInfo = common.frameInfo.START_SERVICE,
    params = {
      height = {
        type = common.bsonType.INT32,
        value = 240
      },
      width = {
        type = common.bsonType.INT32,
        value = 320
      },
      videoProtocol = {
        type = common.bsonType.STRING,
        value = "RAW"
      },
      videoCodec = {
        type = common.bsonType.STRING,
        value = "H264"
      }
    }
  },
  response = {
    frameInfo = common.frameInfo.START_SERVICE_NACK,
    params = { }
  }
}

testCases[7] = {
  name = "Stop Service Audio ACK",
  service = common.serviceType.PCM,
  request = {
    frameInfo = common.frameInfo.END_SERVICE,
    params = {
      hashId = {
        type = common.bsonType.INT32,
        value = hashId[common.serviceType.PCM]
      }
    }
  },
  response = {
    frameInfo = common.frameInfo.END_SERVICE_ACK,
    params = { }
  }
}

testCases[8] = {
  name = "Stop Service Audio NACK",
  service = common.serviceType.PCM,
  request = {
    frameInfo = common.frameInfo.END_SERVICE,
    params = {
      hashId = {
        type = common.bsonType.INT32,
        value = hashId[common.serviceType.PCM]
      }
    }
  },
  response = {
    frameInfo = common.frameInfo.END_SERVICE_NACK,
    params = { }
  }
}

testCases[9] = {
  name = "Stop Service Video ACK",
  service = common.serviceType.VIDEO,
  request = {
    frameInfo = common.frameInfo.END_SERVICE,
    params = {
      hashId = {
        type = common.bsonType.INT32,
        value = hashId[common.serviceType.VIDEO]
      }
    }
  },
  response = {
    frameInfo = common.frameInfo.END_SERVICE_ACK,
    params = { }
  }
}

testCases[10] = {
  name = "Stop Service Video NACK",
  service = common.serviceType.VIDEO,
  request = {
    frameInfo = common.frameInfo.END_SERVICE,
    params = {
      hashId = {
        type = common.bsonType.INT32,
        value = hashId[common.serviceType.VIDEO]
      }
    }
  },
  response = {
    frameInfo = common.frameInfo.END_SERVICE_NACK,
    params = { }
  }
}

testCases[11] = {
  name = "Stop Service RPC ACK",
  service = common.serviceType.RPC,
  request = {
    frameInfo = common.frameInfo.END_SERVICE,
    params = {
      hashId = {
        type = common.bsonType.INT32,
        value = hashId[common.serviceType.RPC]
      }
    }
  },
  response = {
    frameInfo = common.frameInfo.END_SERVICE_ACK,
    params = { }
  }
}

testCases[12] = {
  name = "Stop Service RPC NACK",
  service = common.serviceType.RPC,
  request = {
    frameInfo = common.frameInfo.END_SERVICE,
    params = {
      hashId = {
        type = common.bsonType.INT32,
        value = hashId[common.serviceType.RPC]
      }
    }
  },
  response = {
    frameInfo = common.frameInfo.END_SERVICE_NACK,
    params = { }
  }
}

--[[ Local Functions ]]
local function startService(pServiceType, pRequest, pResponse)
  local protocolVersion = 5
  common.sendControlMessage(pServiceType, pRequest.frameInfo, protocolVersion, pRequest.params)
  common.expectControlMessage(pServiceType, pResponse.frameInfo, protocolVersion, pResponse.params)
  :Do(function(_, data)
      if data.version == 5 and data.frameInfo == common.frameInfo.START_SERVICE_ACK then
        if data.binaryData then
          local payload = bson.to_table(data.binaryData)
          if payload.hashId then
            hashId[pServiceType] = payload.hashId.value
          end
        end
      end
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, Connect Mobile", common.start)
runner.Step("Start Mobile Session", common.startMobileSession)

runner.Title("Test")

for k, tc in pairs(testCases) do
  runner.Step(tc.name, startService, { tc.service, tc.request, tc.response })
  if k == 2 then
    runner.Step("Register Application", common.registerApp)
    runner.Step("Activate Application", common.activateApp)
   end
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
