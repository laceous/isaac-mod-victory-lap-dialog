local mod = RegisterMod('Victory Lap Dialog', 1)
local json = require('json')
local game = Game()

mod.shaderName = 'VictoryLapDialog_DummyShader'
mod.rngShiftIdx = 35

mod.sprite = Sprite()
mod.doRender = false
mod.isYes = false
mod.handleInput = false

mod.state = {}
mod.state.enableDialog = true

function mod:onGameStart()
  if mod:HasData() then
    local _, state = pcall(json.decode, mod:LoadData())
    
    if type(state) == 'table' then
      if type(state.enableDialog) == 'boolean' then
        mod.state.enableDialog = state.enableDialog
      end
    end
  end
end

function mod:onGameExit()
  mod:save()
  mod:resetVars()
end

function mod:save()
  mod:SaveData(json.encode(mod.state))
end

function mod:onNewRoom()
  mod:resetVars()
end

function mod:onUpdate()
  if mod.doRender and not game:IsPaused() then
    mod.sprite:Update()
  end
end

function mod:onRender(shaderName)
  if shaderName ~= mod.shaderName then
    return
  end
  
  if mod.doRender then
    if game:IsPaused() then
      mod:initDialog()
    else
      mod:closeOtherMods()
      mod.sprite:Render(Isaac.WorldToRenderPosition(Vector(320,280)), Vector.Zero, Vector.Zero)
      
      if mod.sprite:IsFinished('Appear') then
        mod.handleInput = true
      elseif mod.sprite:IsFinished('Dissappear') then
        mod.doRender = false
        if mod.isYes then
          mod:doVictoryLap()
        end
      end
      
      if mod.handleInput then
        local buttonAction = mod:getButtonAction()
        
        if buttonAction == ButtonAction.ACTION_LEFT or buttonAction == ButtonAction.ACTION_RIGHT then
          mod:toggleYesNo()
        elseif buttonAction == ButtonAction.ACTION_MENUCONFIRM then
          mod.sprite:Play('Dissappear', true) -- sp?
          mod.handleInput = false
        end
      end
    end
  end
end

-- filtered to PICKUP_BIGCHEST
function mod:onPickupInit(pickup)
  if not mod.state.enableDialog then
    return
  end
  
  local room = game:GetRoom()
  
  -- room:IsClear doesn't work with mega satan
  if not game:IsGreedMode() and not mod:isAnyChallenge() and (room:GetType() == RoomType.ROOM_BOSS or mod:isDogma()) then
    if not (mod:isIsaac() and mod:hasCollectible(CollectibleType.COLLECTIBLE_POLAROID)) and
       not (mod:isSatan() and mod:hasCollectible(CollectibleType.COLLECTIBLE_NEGATIVE)) and
       not mod:isTheLamb()
    then
      mod:initDialog()
    end
  end
end

-- filtered to ENTITY_THE_LAMB and ENTITY_ATTACKFLY
-- 273.0.0 (The Lamb) will come through here, but 273.10.0 (Lamb Body) will not
function mod:onNpcDeath(entityNpc)
  if mod.state.enableDialog then
    return
  end
  
  if mod:isTheLamb() then
    mod:doLambLogic()
  end
end

-- filtered to ENTITY_THE_LAMB
-- we can check 273.10.0 (Lamb Body) from here
-- this fires off before onNpcDeath
function mod:onEntityKill(entity)
  if mod.state.enableDialog then
    return
  end
  
  if mod:isTheLamb() and entity.Variant == 10 then -- lamb body
    mod:doLambLogic()
  end
end

-- this isn't perfect, it can't block keyboard inputs that other mods might be listening to (e.g. mod config menu)
function mod:onInputAction(entity, inputHook, buttonAction)
  if mod.doRender and not game:IsPaused() then
    if inputHook == InputHook.IS_ACTION_PRESSED or inputHook == InputHook.IS_ACTION_TRIGGERED then
      return false
    else -- GET_ACTION_VALUE
      return 0
    end
  end
end

-- filtered to ENTITY_PLAYER
function mod:onEntityTakeDmg()
  if mod.doRender and not game:IsPaused() then
    return false -- ignore damage (just in case)
  end
end

function mod:getButtonAction()
  local keyboard = 0
  
  if Input.IsButtonTriggered(Keyboard.KEY_LEFT, keyboard) then
    return ButtonAction.ACTION_LEFT
  elseif Input.IsButtonTriggered(Keyboard.KEY_RIGHT, keyboard) then
    return ButtonAction.ACTION_RIGHT
  elseif Input.IsButtonTriggered(Keyboard.KEY_SPACE, keyboard) or Input.IsButtonTriggered(Keyboard.KEY_ENTER, keyboard) then
    return ButtonAction.ACTION_MENUCONFIRM
  end
  
  for i = 0, game:GetNumPlayers() - 1 do
    local controller = game:GetPlayer(i).ControllerIndex
    
    if controller > keyboard then
      if Input.IsActionTriggered(ButtonAction.ACTION_LEFT, controller) then
        return ButtonAction.ACTION_LEFT
      elseif Input.IsActionTriggered(ButtonAction.ACTION_RIGHT, controller) then
        return ButtonAction.ACTION_RIGHT
      elseif Input.IsActionTriggered(ButtonAction.ACTION_MENUCONFIRM, controller) then
        return ButtonAction.ACTION_MENUCONFIRM
      end
    end
  end
  
  return -1
end

function mod:resetVars()
  mod.doRender = false
  mod.isYes = false
  mod.handleInput = false
end

function mod:initDialog()
  if not mod.sprite:IsLoaded() then
    mod:loadSprite()
  end
  
  mod.sprite:Play('Appear', true)
  mod.doRender = true
  mod.isYes = false
  mod.handleInput = false
end

function mod:toggleYesNo()
  if mod.isYes then
    mod.sprite:SetFrame('Idle', 0)
    mod.isYes = false
  else
    mod.sprite:SetFrame('Idle', 1)
    mod.isYes = true
  end
end

function mod:loadSprite()
  mod.sprite:Load('gfx/ui/prompt_yesno.anm2', false)
  mod.sprite:ReplaceSpritesheet(2, 'gfx/ui/prompt_victoryrun.png')
  mod.sprite:LoadGraphics()
end

function mod:doVictoryLap()
  game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT, false)
  game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH, false)
  game:SetStateFlag(GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED, false)
  game:NextVictoryLap()
end

function mod:hasCollectible(collectible)
  for i = 0, game:GetNumPlayers() - 1 do
    local player = game:GetPlayer(i)
    
    if player:HasCollectible(collectible, false) then
      return true
    end
  end
  
  return false
end

function mod:doLambLogic()
  if not mod:hasActiveLambEnemy() then
    local room = game:GetRoom()
    room:SetClear(true) -- short circuit the room logic, including spawning the chest, void portal, and victory lap dialog
    
    local centerIdx = room:GetGridIndex(room:GetCenterPos())
    mod:spawnBigChest(room:GetGridPosition(centerIdx))
    
    local rng = RNG()
    rng:SetSeed(room:GetSpawnSeed(), mod.rngShiftIdx) -- GetAwardSeed, GetDecorationSeed
    if rng:RandomFloat() < 0.2 then -- 20%
      mod:spawnVoidPortal(room:GetGridPosition(centerIdx + (2 * 15))) -- 2 spaces lower
    end
  end
end

function mod:hasActiveLambEnemy()
  for _, v in ipairs(Isaac.GetRoomEntities()) do
    if v:IsActiveEnemy(false) then
      if v.Type == EntityType.ENTITY_THE_LAMB and v.Variant == 10 then -- lamb body needs special handling
        if v.HitPoints > 0 then
          return true
        end
      else
        return true
      end
    end
  end
  
  return false
end

function mod:spawnBigChest(pos)
  Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BIGCHEST, 0, pos, Vector.Zero, nil)
end

function mod:spawnVoidPortal(pos)
  local portal = Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 1, pos, true)
  portal.VarData = 1
  portal:GetSprite():Load('gfx/grid/voidtrapdoor.anm2', true)
end

function mod:isAnyChallenge()
  return Isaac.GetChallenge() ~= Challenge.CHALLENGE_NULL
end

function mod:isIsaac()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  
  return level:GetStage() == LevelStage.STAGE5 and
         level:IsAltStage() and
         roomDesc.Data.Type == RoomType.ROOM_BOSS and
         roomDesc.GridIndex >= 0
end

function mod:isSatan()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  
  return level:GetStage() == LevelStage.STAGE5 and
         not level:IsAltStage() and
         roomDesc.Data.Type == RoomType.ROOM_BOSS and
         roomDesc.GridIndex >= 0
end

function mod:isTheLamb()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  
  return level:GetStage() == LevelStage.STAGE6 and
         not level:IsAltStage() and
         roomDesc.Data.Type == RoomType.ROOM_BOSS and
         roomDesc.GridIndex >= 0
end

-- type is ROOM_DEFAULT
function mod:isDogma()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  
  return level:GetStage() == LevelStage.STAGE8 and
         roomDesc.Data.Shape == RoomShape.ROOMSHAPE_1x2 and
         roomDesc.GridIndex == 109 -- living room
end

function mod:closeOtherMods()
  -- mod config menu
  if ModConfigMenu and ModConfigMenu.IsVisible then
    ModConfigMenu.CloseConfigMenu()
  end
  
  -- encyclopedia
  if DeadSeaScrollsMenu and DeadSeaScrollsMenu.IsOpen() then
    DeadSeaScrollsMenu.CloseMenu(true, true)
  end
end

-- start ModConfigMenu --
function mod:setupModConfigMenu()
  for _, v in ipairs({ 'Settings' }) do
    ModConfigMenu.RemoveSubcategory(mod.Name, v)
  end
  ModConfigMenu.AddSetting(
    mod.Name,
    'Settings',
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return mod.state.enableDialog
      end,
      Display = function()
        return (mod.state.enableDialog and 'Enable' or 'Disable') .. ' victory lap dialog'
      end,
      OnChange = function(b)
        mod.state.enableDialog = b
        mod:save()
      end,
      Info = { 'Enable: show dialog after a big chest drops', 'Disable: disable everywhere including The Lamb' }
    }
  )
end
-- end ModConfigMenu --

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, mod.onRender) -- MC_GET_SHADER_PARAMS draws over the HUD, MC_POST_RENDER draws under the HUD
mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, mod.onPickupInit, PickupVariant.PICKUP_BIGCHEST)
mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.onNpcDeath, EntityType.ENTITY_THE_LAMB)     -- lamb
mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.onNpcDeath, EntityType.ENTITY_ATTACKFLY)    -- lamb body can spawn flies
mod:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, mod.onEntityKill, EntityType.ENTITY_THE_LAMB) -- lamb body
mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, mod.onInputAction)
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.onEntityTakeDmg, EntityType.ENTITY_PLAYER) -- MC_PRE_PLAYER_COLLISION

if ModConfigMenu then
  mod:setupModConfigMenu()
end