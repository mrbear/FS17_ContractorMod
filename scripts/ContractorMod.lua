source(Utils.getFilename("scripts/ContractorModWorker.lua", g_currentModDirectory))

-- ContractorMod        update attached to update event of the map
-- ContractorModWorker  no event, only called when interacting with ContractorMod

ContractorMod = {};
ContractorMod.myCurrentModDirectory = g_currentModDirectory;

debug = false --true --

function ContractorMod:loadMap(name)
  if debug then print("ContractorMod:loadMap(name)") end
  self.initializing = true
  if self.initialized then
    return;
  end;
  self.initialized = true;
end;

function ContractorMod:deleteMap()
  self.initialized = false;
  self.workers = nil;
end;

function ContractorMod:init()
  if debug then print("ContractorMod:init()") end
  -- Forbid switching between vehicles
  g_currentMission.isToggleVehicleAllowed = false;
    
  self.currentID = 1.
  self.numWorkers = 4.
  self.workers = {}
  self.initializing = true
  self.shouldExit = false       --Enable to forbid having 2 workers in the same vehicle
  self.shouldStopWorker = true  --Enable to distinguish LeaveVehicle when switchingWorker and when leaving due to player request
  self.enableSeveralDrivers = false
  self.switching = false
  
  local savegameDir;
  if g_currentMission.missionInfo.savegameDirectory then
    savegameDir = g_currentMission.missionInfo.savegameDirectory;
  end;
  if not savegameDir and g_careerScreen.currentSavegame and g_careerScreen.currentSavegame.savegameIndex then
    savegameDir = ('%ssavegame%d'):format(getUserProfileAppPath(), g_careerScreen.currentSavegame.savegameIndex);
  end;
  if not savegameDir and g_currentMission.missionInfo.savegameIndex ~= nil then
    savegameDir = ('%ssavegame%d'):format(getUserProfileAppPath(), g_careerScreen.missionInfo.savegameIndex);
  end;
  self.savegameFolderPath = savegameDir;
  self.ContractorModXmlFilePath = self.savegameFolderPath .. '/ContractorMod.xml';
  
  if not self:initFromSave() or #self.workers <= 0 then
    if not self:initFromParam() or #self.workers <= 0 then
      -- default values
      if debug then print("ContractorMod: No savegame: set default values") end
      local worker = ContractorModWorker:new("Alex", 1)
      table.insert(self.workers,worker)
      worker = ContractorModWorker:new("Bob", 2)
      table.insert(self.workers,worker)
      worker = ContractorModWorker:new("Chris", 3)
      table.insert(self.workers,worker)
      worker = ContractorModWorker:new("David", 4)
      table.insert(self.workers,worker)
    end
  end
end

function ContractorMod:initFromSave()
  if debug then print("ContractorMod:initFromSave") end
  if g_currentMission ~= nil and g_currentMission:getIsServer() then
    if self.savegameFolderPath and self.ContractorModXmlFilePath then
      createFolder(self.savegameFolderPath);
      local xmlFile;
      if fileExists(self.ContractorModXmlFilePath) then
        xmlFile = loadXMLFile('ContractorMod', self.ContractorModXmlFilePath);
      else
        xmlFile = createXMLFile('ContractorMod', self.ContractorModXmlFilePath, 'ContractorMod');
        saveXMLFile(xmlFile);
        delete(xmlFile);
        return false;
      end;

      if xmlFile ~= nil then
        local xmlKey = "ContractorMod.workers"
        local numWorkers = 0
        numWorkers = getXMLInt(xmlFile, xmlKey .. string.format("#numWorkers"));
        if numWorkers ~= nil then
          --print("numWorkers " .. tostring(numWorkers))
          for i = 1, numWorkers do
            key = xmlKey .. string.format(".worker(%d)",i-1)
            local workerName = getXMLString(xmlFile, key.."#name");
            if debug then print(workerName) end
            local worker = ContractorModWorker:new(workerName, i)
            if debug then print(getXMLString(xmlFile, key.."#position")) end
            local x,y,z = Utils.getVectorFromString(getXMLString(xmlFile, key.."#position"));
            if debug then print("x "..tostring(x)) end
            local xRot,yRot,zRot = Utils.getVectorFromString(getXMLString(xmlFile, key.."#rotation"));
            if x ~= nil and y ~= nil and z ~= nil and xRot ~= nil and yRot ~= nil and zRot ~= nil then
              ret = true
              worker.x = x
              worker.y = y
              worker.z = z
              worker.dx = xRot
              worker.dy = yRot
              worker.dz = zRot
              local vehicleID = getXMLFloat(xmlFile, key.."#vehicleID");
              if vehicleID > 0 then
                local vehicle = networkGetObject(vehicleID)
                if vehicle ~= nil then
                  if debug then print("ContractorMod: vehicle not nil") end
                  worker.currentVehicle = vehicle
                  local isPassenger = getXMLBool(xmlFile, key.."#isPassenger");
                  if isPassenger then
                    worker.isPassenger = isPassenger
                    local passengerPlace = getXMLFloat(xmlFile, key.."#passengerPlace");
                    if passengerPlace > 0 then
                      worker.passengerPlace = passengerPlace
                    end
                  end
                end
              end
            end;
            table.insert(self.workers,worker)
          end
          local enableSeveralDrivers = getXMLBool(xmlFile, xmlKey .. string.format("#enableSeveralDrivers"));
          if enableSeveralDrivers ~= nil then
            self.enableSeveralDrivers = enableSeveralDrivers
          else
            self.enableSeveralDrivers = false
          end
        end
        self.numWorkers = numWorkers
        return true
      end
    end
  end
end

function ContractorMod:initFromParam()
  if debug then print("ContractorMod:initFromParam") end
  if g_currentMission ~= nil and g_currentMission:getIsServer() then
    if ContractorMod.myCurrentModDirectory then
      local xmlFilePath = ContractorMod.myCurrentModDirectory .. "../ContractorMod.xml"
      local xmlFile;
      if fileExists(xmlFilePath) then
        xmlFile = loadXMLFile('ContractorMod', xmlFilePath);
      else
        return false;
      end;

      if xmlFile ~= nil then
        local xmlKey = "ContractorMod.workers"
        local numWorkers = 0
        numWorkers = getXMLInt(xmlFile, xmlKey .. string.format("#numWorkers"));
        if numWorkers ~= nil then
          if debug then print("ContractorMod: numWorkers " .. tostring(numWorkers)) end
          for i = 1, numWorkers do
            key = xmlKey .. string.format(".worker(%d)",i-1)
            local workerName = getXMLString(xmlFile, key.."#name");
            if debug then print(workerName) end
            local worker = ContractorModWorker:new(workerName, i)
            if debug then print(getXMLString(xmlFile, key.."#position")) end
            local x,y,z = Utils.getVectorFromString(getXMLString(xmlFile, key.."#position"));
            if debug then print("x "..tostring(x)) end
            local xRot,yRot,zRot = Utils.getVectorFromString(getXMLString(xmlFile, key.."#rotation"));
            if x ~= nil and y ~= nil and z ~= nil and xRot ~= nil and yRot ~= nil and zRot ~= nil then
              worker.x = x
              worker.y = y
              worker.z = z
              worker.dx = xRot
              worker.dy = yRot
              worker.dz = zRot
            end;
            table.insert(self.workers,worker)
          end
          local enableSeveralDrivers = getXMLBool(xmlFile, xmlKey .. string.format("#enableSeveralDrivers"));
          if enableSeveralDrivers ~= nil then
            self.enableSeveralDrivers = enableSeveralDrivers
          else
            self.enableSeveralDrivers = false
          end          
        end
        self.numWorkers = numWorkers
        return true
      end
    end
  end
end

function ContractorMod:ManageSoldVehicle(vehicle)
  --print("ContractorMod:ManageSoldVehicle " .. vehicle.name)
  if self.workers ~= nil then
    if #self.workers > 0 then
      for i = 1, self.numWorkers do
        local worker = self.workers[i]
        if worker.currentVehicle == vehicle then
          if debug then print("ContractorMod: This worker was in a vehicle that has been removed : " .. worker.name) end
          worker.x, worker.y, worker.z = getWorldTranslation(worker.currentVehicle.rootNode);
          if worker.y ~= nil then
            worker.y = worker.y + 2 --to avoid being under the ground
          end
          worker.dx, worker.dy, worker.dz = localDirectionToWorld(worker.currentVehicle.rootNode, 0, 0, 1);
          worker.currentVehicle = nil
          break
        end
      end
    end
  end
end
function ContractorMod:removeVehicle(vehicle, callDelete)
  ContractorMod:ManageSoldVehicle(vehicle)
end
BaseMission.removeVehicle = Utils.prependedFunction(BaseMission.removeVehicle, ContractorMod.removeVehicle);

function ContractorMod:ManageEnterVehicle(vehicle)
  local vehicleName = ""
  if vehicle ~= nil then
    if vehicle.name ~= nil then
      vehicleName = vehicle.name
    end
  end
  if debug then print("ContractorMod:appendedEnterVehicle >>" .. vehicleName) end
  
  local doExit = false
  if self.workers ~= nil then
    if #self.workers > 0 and not self.initializing and not self.enableSeveralDrivers then
      for i = 1, self.numWorkers do
        local worker = self.workers[i]
        if worker.currentVehicle == vehicle then
          if worker.name ~= self.workers[self.currentID].name then
            if debug then print("ContractorMod: "..worker.name .. " already in ") end
            if worker.isPassenger == false then
              if debug then print("as driver") end
              doExit = true
            else
              if debug then print("as passenger") end
              doExit = false
            end
          else
            doExit = false
          end
        end
      end
    end
  end
  if doExit then
    if debug then print("ContractorMod: Player will leave " ) end
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, g_i18n:getText("ContractorMod_VEHICLE_NOT_FREE"))
    self.shouldExit = true
  end
  if self.switching and vehicle.steeringEnabled then  -- true and false
    -- Switching and no AI
    if SpecializationUtil.hasSpecialization(AIVehicle, vehicle.specializations) then
      -- Stop AI if vehicle can be hired (else will crash on cars)
      vehicle:stopAIVehicle();
    end
    vehicle.isHired = false
    --HelperUtil.releaseHelper(vehicle.currentHelper)
    if debug then print("ContractorMod: switching-noAI " .. tostring(vehicle.isHired)) end
    if debug then print("ContractorMod: switching-noAI " .. tostring(vehicle.vehicleCharacter)) end
  else
    if debug then print("ContractorMod: 253 " .. tostring(vehicle.isHired)) end
  end
  
  if debug then print("ContractorMod: 251 " .. tostring(self.switching) .. " : " .. tostring(vehicle.steeringEnabled)) end
  if debug then print("ContractorMod:appendedEnterVehicle <<" .. vehicleName) end
  if vehicle ~= nil then
    if debug then print("isHired " .. tostring(vehicle.isHired) .. " disableChar " .. tostring(vehicle.disableCharacterOnLeave) .. " steering " .. tostring(vehicle.steeringEnabled)) end
  end
end
function ContractorMod:onEnterVehicle(vehicle)
  --print("ContractorMod:onEnterVehicle " .. vehicle.name)
  ContractorMod:ManageEnterVehicle(vehicle)
end
BaseMission.onEnterVehicle = Utils.appendedFunction(BaseMission.onEnterVehicle, ContractorMod.onEnterVehicle);

-- Steerable:enter()        => loadCharacter if isHired == false
-- Steerable:leaveVehicle() => deleteCharacter if disableCharacterOnLeave == true

-- KO when entering a vehicle. Seen as hired

function ContractorMod:ManageBeforeEnterVehicle(vehicle)
  local vehicleName = ""
  if vehicle ~= nil then
    if vehicle.name ~= nil then
      vehicleName = vehicle.name
    end
  end
  if debug then print("ContractorMod:prependedEnterVehicle >>" .. vehicleName) end
  
  local doExit = false
  if self.workers ~= nil then
    if #self.workers > 0 and not self.initializing and not self.enableSeveralDrivers then
      for i = 1, self.numWorkers do
        local worker = self.workers[i]
        if worker.currentVehicle == vehicle then
          if worker.name ~= self.workers[self.currentID].name then
            if debug then print("ContractorMod: "..worker.name .. " already in ") end
            if worker.isPassenger == false then
              if debug then print("as driver") end
              doExit = true
            else
              if debug then print("as passenger") end
              doExit = false
            end
          else
            doExit = false
          end
        end
      end
    end
  end
  if doExit then
    if debug then print("ContractorMod: Player will leave before enter" ) end
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, g_i18n:getText("ContractorMod_VEHICLE_NOT_FREE"))
    if vehicle.vehicleCharacter ~= nil then
      vehicle.vehicleCharacter:delete();
    end
  end

  if self.switching then
    if not self.initializing then
      vehicle.isHired = true
    end
    -- Needed ??
    vehicle.currentHelper = HelperUtil.getRandomHelper()
    if debug then print("ContractorMod: switching " .. tostring(vehicle.isHired)) end
  else
    vehicle.isHired = false
  end
  
  if debug then print("ContractorMod: 268 " .. tostring(vehicle.isHired)) end
    -- vehicle.disableCharacterOnLeave = false;
  -- else
  vehicle.disableCharacterOnLeave = true;
  -- end
  
  if debug then print("ContractorMod:prependedEnterVehicle <<" .. vehicle.typeName) end
  if vehicle ~= nil then
    if debug then print("isHired " .. tostring(vehicle.isHired) .. " disableChar " .. tostring(vehicle.disableCharacterOnLeave) .. " steering " .. tostring(vehicle.steeringEnabled)) end
  end
end
function ContractorMod:beforeEnterVehicle(vehicle)
  if debug then print("ContractorMod:beforeEnterVehicle " .. vehicle.typeName) end
  ContractorMod:ManageBeforeEnterVehicle(vehicle)
end
BaseMission.onEnterVehicle = Utils.prependedFunction(BaseMission.onEnterVehicle, ContractorMod.beforeEnterVehicle);

function ContractorMod:preOnStopAiVehicle()
  if debug then print("ContractorMod:preOnStopAiVehicle ") end
  --backup character
  self.tmpCharacter = self.vehicleCharacter;
  --won't be deleted next if nil
  self.vehicleCharacter = nil
end
AIVehicle.onStopAiVehicle = Utils.prependedFunction(AIVehicle.onStopAiVehicle, ContractorMod.preOnStopAiVehicle);

function ContractorMod:appOnStopAiVehicle()
  if debug then print("ContractorMod:appOnStopAiVehicle ") end
  --restore character
  self.vehicleCharacter = self.tmpCharacter ;
  self.tmpCharacter = nil
end
AIVehicle.onStopAiVehicle = Utils.appendedFunction(AIVehicle.onStopAiVehicle, ContractorMod.appOnStopAiVehicle);

-- Still seen as hired when onStopFollowMe. Need to setWorker/RemoveWorker 
-- function ContractorMod:appOnStopFollowMe()
  -- print("ContractorMod:appOnStopFollowMe ")
  -- if g_currentMission.controlledVehicle ~= nil then
    -- if debug then print("isHired " .. tostring(g_currentMission.controlledVehicle.isHired) .. " disableChar " .. tostring(g_currentMission.controlledVehicle.disableCharacterOnLeave) .. " steering " .. tostring(g_currentMission.controlledVehicle.steeringEnabled)) end
  -- end
-- end
-- FollowMe.onStopFollowMe = Utils.appendedFunction(FollowMe.onStopFollowMe, ContractorMod.appOnStopFollowMe);

function ContractorMod:ManageLeaveVehicle(controlledVehicle)
  if debug then print("ContractorMod:prependedLeaveVehicle >>") end
  if controlledVehicle ~= nil then
    if debug then print("isHired " .. tostring(controlledVehicle.isHired) .. " disableChar " .. tostring(controlledVehicle.disableCharacterOnLeave) .. " steering " .. tostring(controlledVehicle.steeringEnabled)) end
  end

  if controlledVehicle ~= nil then
    if self.shouldStopWorker then
    
      --Leaving vehicle
      if debug then print("controlled vehicle " .. controlledVehicle.typeName) end
      if not controlledVehicle.steeringEnabled then
        --Leaving and AI activated
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, g_i18n:getText("ContractorMod_WORKER__STOP"))
        --Manage CoursePlay vehicles
        if controlledVehicle.cp ~= nil then
          if controlledVehicle.cp.isDriving then
            -- Try to stop the CP vehicle
            if debug then print("setCourseplayFunc stop") end
            controlledVehicle:setCourseplayFunc('stop', nil, false, 1);
          else
            controlledVehicle:stopAIVehicle();
          end
        else
          controlledVehicle:stopAIVehicle();
        end
      else
        --Leaving and no AI activated
        controlledVehicle.disableCharacterOnLeave = true;
      end
    else
    
      --Switching
      if controlledVehicle.steeringEnabled then
        if debug then print("ContractorMod: steeringEnabled TRUE") end
        --No AI activated
        --controlledVehicle.isHired = true;
        --controlledVehicle.currentHelper = HelperUtil.getRandomHelper()
        controlledVehicle.disableCharacterOnLeave = false;
        controlledVehicle.isHirableBlocked = true;
        controlledVehicle.forceIsActive = true;
        controlledVehicle.stopMotorOnLeave = false;
      else
        if debug then print("ContractorMod: steeringEnabled FALSE") end
        controlledVehicle.isHired = true;
        controlledVehicle.currentHelper = HelperUtil.getRandomHelper()
        controlledVehicle.disableCharacterOnLeave = false;
      end
    end
    -- if self.switching then
      -- controlledVehicle.disableCharacterOnLeave = false;
    -- else
      -- controlledVehicle.disableCharacterOnLeave = true;
    -- end
    if debug then print("ContractorMod:prependedLeaveVehicle <<" .. controlledVehicle.typeName) end
  end
  if controlledVehicle ~= nil then
    if debug then print("isHired " .. tostring(controlledVehicle.isHired) .. " disableChar " .. tostring(controlledVehicle.disableCharacterOnLeave) .. " steering " .. tostring(controlledVehicle.steeringEnabled)) end
  end
end
function ContractorMod:onLeaveVehicle()
  if debug then print("ContractorMod:onLeaveVehicle ") end
  local controlledVehicle = g_currentMission.controlledVehicle
  if controlledVehicle ~= nil then
    ContractorMod:ManageLeaveVehicle(controlledVehicle)
  end
end
BaseMission.onLeaveVehicle = Utils.prependedFunction(BaseMission.onLeaveVehicle, ContractorMod.onLeaveVehicle);

-- DONE: Manage case when worker stops => character 
-- TODO: Manage case when stopping FollowMe => vehicle seen as AI controlled, need to leave it + activate/deactivate follow me
-- DONE: Character always looking at south (0,0,1) orientation

function ContractorMod:onSaveCareerSavegame()
  if self.workers ~= nil then
    local xmlFile;
    if fileExists(self.ContractorModXmlFilePath) then
      xmlFile = loadXMLFile('ContractorMod', self.ContractorModXmlFilePath);
    else
      xmlFile = createXMLFile('ContractorMod', self.ContractorModXmlFilePath, 'ContractorMod');
      saveXMLFile(xmlFile);
    end;

    if xmlFile ~= nil then
      local rootXmlKey = "ContractorMod"

      -- update current worker position
      local currentWorker = self.workers[self.currentID]
      if currentWorker ~=nil then
        currentWorker:beforeSwitch(true)
      end
      
      local workerKey = rootXmlKey .. ".workers"
      setXMLInt(xmlFile, workerKey.."#numWorkers", self.numWorkers);
      setXMLBool(xmlFile, workerKey .."#enableSeveralDrivers", self.enableSeveralDrivers);
        
      for i = 1, self.numWorkers do
        local worker = self.workers[i]
        local key = string.format(rootXmlKey .. ".workers.worker(%d)", i-1);
        setXMLString(xmlFile, key.."#name", worker.name);
        local pos = worker.x..' '..worker.y..' '..worker.z
        setXMLString(xmlFile, key.."#position", pos);
        local rot = worker.dx..' '..worker.dy..' '..worker.dz
        setXMLString(xmlFile, key.."#rotation", rot);
        local vehicleID = 0.
        local isPassenger = false
        local passengerPlace = 0.
        if worker.currentVehicle ~= nil then
          vehicleID = networkGetObjectId(worker.currentVehicle)
          isPassenger = worker.isPassenger
          if isPassenger then
            passengerPlace = worker.passengerPlace
          end
        end
        setXMLFloat(xmlFile, key.."#vehicleID", vehicleID);
        setXMLBool(xmlFile, key.."#isPassenger", isPassenger);
        setXMLFloat(xmlFile, key.."#passengerPlace", passengerPlace);
      end
      saveXMLFile(xmlFile);
    end
  end
end

FSCareerMissionInfo.saveToXML = Utils.prependedFunction(FSCareerMissionInfo.saveToXML, function(self)
    if self.isValid and self.xmlKey ~= nil then
        ContractorMod:onSaveCareerSavegame()
    end
end);

function ContractorMod:mouseEvent(posX, posY, isDown, isUp, button)
end;

function ContractorMod:keyEvent(unicode, sym, modifier, isDown)
end;

function ContractorMod:draw()
  --Display current worker name
  if self.workers ~= nil then
    if #self.workers > 0 and g_currentMission.showHudEnv then
      local currentWorker = self.workers[self.currentID]
      if currentWorker ~=nil then
        --Display current worker name
        currentWorker:displayName()
      end
      for i = 1, self.numWorkers do
        local worker = self.workers[i]
        if worker.mapHotSpot ~= nil then
          g_currentMission.ingameMap:deleteMapHotspot(worker.mapHotSpot)
          worker.mapHotSpot = nil
        end
        --Display workers on the minimap
        if worker.currentVehicle == nil then
          worker.mapHotSpot = g_currentMission.ingameMap:createMapHotspot(tostring(worker.name), tostring(worker.name), ContractorMod.myCurrentModDirectory .. "images/worker" .. tostring(i) .. ".dds", nil, nil, worker.x, worker.z, g_currentMission.ingameMap.mapArrowWidth / 3, g_currentMission.ingameMap.mapArrowHeight / 3, false, false, false, 0);
        else
          worker.mapHotSpot = g_currentMission.ingameMap:createMapHotspot(tostring(worker.name), tostring(worker.name), ContractorMod.myCurrentModDirectory .. "images/worker" .. tostring(i) .. ".dds", nil, nil, worker.x, worker.z, g_currentMission.ingameMap.mapArrowWidth / 3, g_currentMission.ingameMap.mapArrowHeight / 3, false, false, false, 0);
        end
      end
    end
  end
end

function ContractorMod:update(dt)
  if self.workers == nil then
    -- default values
    self:init()
    if #self.workers > 0 then
      self.switching = true
      self.shouldStopWorker = false
      -- Activate each vehicle once to show farmer in them
       for i = 2, self.numWorkers do
         local worker = self.workers[i]
         if worker.currentVehicle ~= nil then
           if debug then print("sendEvent VehicleEnterRequestEvent " .. worker.name .. " : " .. worker.currentVehicle.typeName) end
           g_client:getServerConnection():sendEvent(VehicleEnterRequestEvent:new(worker.currentVehicle, g_settingsNickname, worker.playerIndex, worker.playerColorIndex));
           g_currentMission:onLeaveVehicle()
         end
       end
      self.switching = false
      self.shouldStopWorker = true
    end
    local firstWorker = self.workers[self.currentID]
    if g_currentMission.player and g_currentMission.player ~= nil then
      if debug then print("ContractorMod: moveToAbsolute"); end
      setTranslation(g_currentMission.player.rootNode, firstWorker.x,firstWorker.y,firstWorker.z);
      g_currentMission.player:moveToAbsolute(firstWorker.x,firstWorker.y,firstWorker.z);
      g_client:getServerConnection():sendEvent(PlayerTeleportEvent:new(firstWorker.x,firstWorker.y,firstWorker.z));
      g_currentMission.player.rotY = firstWorker.rotY --Utils.getYRotationFromDirection(firstWorker.dx, firstWorker.dz) + math.pi;
      if firstWorker.currentVehicle ~= nil then
        firstWorker:afterSwitch()
      end
    end
    self.initializing = false
  end
  
  if #self.workers > 0 then
    for i = 1, self.numWorkers do
      worker = self.workers[i]
      if i == self.currentID then
        -- For current player character
        if g_currentMission.controlledVehicle == nil then
          local passengerHoldingVehicle = g_currentMission.passengerHoldingVehicle;
          if passengerHoldingVehicle ~= nil then
            worker.isPassenger = true
            worker.currentVehicle = passengerHoldingVehicle;
            worker.passengerPlace = g_currentMission.passengerPlace
          else
            -- not in a vehicle
            worker.x, worker.y, worker.z = getWorldTranslation(g_currentMission.player.rootNode);
            worker.isPassenger = false
            worker.passengerPlace = 0
            worker.currentVehicle = nil;
          end
        else
          -- in a vehicle
          worker.x, worker.y, worker.z = getWorldTranslation(g_currentMission.controlledVehicle.rootNode); -- for miniMap update
          worker.currentVehicle = g_currentMission.controlledVehicle;
          -- Trick to make FollowMe work as expected when stopping it
          if worker.currentVehicle.followMeIsStarted ~= nil then
            if worker.currentVehicle.followMeIsStarted then
              if worker.currentVehicle.followMeIsStarted ~= worker.followMeIsStarted then
                --Starting FollowMe
                if debug then print("FollowMe has been started") end
                worker.followMeIsStarted = worker.currentVehicle.followMeIsStarted
              end
            else
              if worker.currentVehicle.followMeIsStarted ~= worker.followMeIsStarted then
                --Stopping FollowMe
                if debug then print("FollowMe has been stopped") end
                worker.currentVehicle.isHired = false;
                worker.followMeIsStarted = worker.currentVehicle.followMeIsStarted
              end
            end
          end
        end
      else
        -- For other characters
        if worker.currentVehicle ~= nil and worker.currentVehicle.rootNode ~= nil then
          -- update if in a vehicle
          worker.x, worker.y, worker.z = getWorldTranslation(worker.currentVehicle.rootNode); -- for miniMap update
        end
      end
    end
    if self.shouldExit then
      if debug then print("ContractorMod: Player leaving the vehicle") end
      g_currentMission:onLeaveVehicle()
      self.shouldExit = false
    end
  end
  
  if InputBinding.hasEvent(InputBinding.ContractorMod_NEXTWORKER) then
    if debug then print("ContractorMod:update(dt) ContractorMod_NEXTWORKER") end
    local nextID = 0
    if debug then print("ContractorMod: self.currentID " .. tostring(self.currentID)) end
    if debug then print("ContractorMod: self.numWorkers " .. tostring(self.numWorkers)) end
    if self.currentID < self.numWorkers then
      nextID = self.currentID + 1
    else
      nextID = 1
    end
    if debug then print("ContractorMod: nextID " .. tostring(nextID)) end
    self:setCurrentContractorModWorker(nextID)
  elseif InputBinding.hasEvent(InputBinding.ContractorMod_PREVWORKER) then
    if debug then print("ContractorMod:update(dt) ContractorMod_PREVWORKER") end
    local prevID = 0
    if self.currentID > 1 then
      prevID = self.currentID - 1
    else
      prevID = self.numWorkers
    end    
    self:setCurrentContractorModWorker(prevID)
  end
end

function ContractorMod:setCurrentContractorModWorker(setID)
  if debug then print("ContractorMod:setCurrentContractorModWorker(setID) " .. tostring(setID)) end
  local currentWorker = self.workers[self.currentID]
  if currentWorker ~=nil then
    self.shouldStopWorker = false
    self.switching = true
    currentWorker:beforeSwitch()
  end
  self.currentID = setID
  currentWorker = self.workers[self.currentID]
  if currentWorker ~=nil then
    currentWorker:afterSwitch()
    self.shouldStopWorker = true
    self.switching = false
  end
end

addModEventListener(ContractorMod);