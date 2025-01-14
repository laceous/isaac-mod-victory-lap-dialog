local mod = RegisterMod('Victory Lap Dialog', 1)
local json = require('json')
local game = Game()

mod.shaderName = 'VictoryLapDialog_DummyShader'
mod.rngShiftIdx = 35

mod.onRenderHasRun = false
mod.secondRendererRemoved = false

mod.sprite = Sprite()
mod.doRender = false
mod.isYes = false
mod.handleInput = false

mod.input = {}

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

function mod:onHudRender()
  mod:doRenderLogic()
end

-- MC_POST_RENDER runs before MC_GET_SHADER_PARAMS
-- if shaders.xml doesn't exist then we'll use onRender to draw under the HUD
function mod:onRender()
  if not mod.onRenderHasRun then
    mod.onRenderHasRun = true
  elseif not mod.secondRendererRemoved then
    mod:RemoveCallback(ModCallbacks.MC_GET_SHADER_PARAMS, mod.onRenderShader)
    mod.secondRendererRemoved = true
  else
    mod:doRenderLogic()
  end
end

-- if shaders.xml exists then we'll use onRenderShader to draw over the HUD
function mod:onRenderShader(shaderName)
  if shaderName ~= mod.shaderName then
    return
  end
  
  if not mod.secondRendererRemoved then
    mod:RemoveCallback(ModCallbacks.MC_POST_RENDER, mod.onRender)
    mod.secondRendererRemoved = true
  else
    mod:doRenderLogic()
  end
end

function mod:doRenderLogic()
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
  
  if not pickup:Exists() then
    return
  end
  
  local room = game:GetRoom()
  
  -- room:IsClear doesn't work with mega satan
  if not game:IsGreedMode() and not mod:isAnyChallenge() and (room:GetType() == RoomType.ROOM_BOSS or room:IsCurrentRoomLastBoss()) then
    local hasPolaroid = mod:hasCollectible(CollectibleType.COLLECTIBLE_POLAROID)
    local hasNegative = mod:hasCollectible(CollectibleType.COLLECTIBLE_NEGATIVE)
    
    -- support switch tracks mod
    if not (mod:isIsaac() and (hasPolaroid or (switchtracks_1888830246 and hasNegative))) and
       not (mod:isSatan() and (hasNegative or (switchtracks_1888830246 and hasPolaroid))) and
       not mod:isTheLamb()
    then
      mod:initDialog()
    end
  end
end

function mod:onPreSpawnAward()
  if game:IsGreedMode() or mod:isAnyChallenge() then
    return
  end
  
  if mod.state.enableDialog then
    return
  end
  
  if mod:isTheLamb() then
    mod:doLambLogic()
    return true
  end
end

-- filtered to ENTITY_PLAYER
function mod:onEntityTakeDmg()
  if mod.doRender and not game:IsPaused() then
    return false -- ignore damage (just in case)
  end
end

function mod:onPrePlayerCollision()
  if mod.doRender and not game:IsPaused() then
    return true -- ignore collision
  end
end

-- block game input
function mod:onInputAction(entity, inputHook, buttonAction)
  if mod.doRender and not game:IsPaused() then
    if inputHook == InputHook.IS_ACTION_PRESSED or inputHook == InputHook.IS_ACTION_TRIGGERED then
      return false
    else -- GET_ACTION_VALUE
      return 0
    end
  end
end

-- block mod input
function mod:overrideInput()
  mod.input.getActionValue = Input.GetActionValue
  mod.input.getButtonValue = Input.GetButtonValue
  mod.input.getMousePosition = Input.GetMousePosition
  mod.input.isActionPressed = Input.IsActionPressed
  mod.input.isActionTriggered = Input.IsActionTriggered
  mod.input.isButtonPressed = Input.IsButtonPressed
  mod.input.isButtonTriggered = Input.IsButtonTriggered
  mod.input.isMouseBtnPressed = Input.IsMouseBtnPressed
  
  Input.GetActionValue = function(action, controllerId)
    if mod.doRender and not game:IsPaused() then
      return 0
    end
    
    return mod.input.getActionValue(action, controllerId)
  end
  
  Input.GetButtonValue = function(button, controllerId)
    if mod.doRender and not game:IsPaused() then
      return 0
    end
    
    return mod.input.getButtonValue(button, controllerId)
  end
  
  Input.GetMousePosition = function(gameCoords)
    if mod.doRender and not game:IsPaused() then
      return Vector.Zero
    end
    
    return mod.input.getMousePosition(gameCoords)
  end
  
  Input.IsActionPressed = function(action, controllerId)
    if mod.doRender and not game:IsPaused() then
      return false
    end
    
    return mod.input.isActionPressed(action, controllerId)
  end
  
  Input.IsActionTriggered = function(action, controllerId)
    if mod.doRender and not game:IsPaused() then
      return false
    end
    
    return mod.input.isActionTriggered(action, controllerId)
  end
  
  Input.IsButtonPressed = function(button, controllerId)
    if mod.doRender and not game:IsPaused() then
      return false
    end
    
    return mod.input.isButtonPressed(button, controllerId)
  end
  
  Input.IsButtonTriggered = function(button, controllerId)
    if mod.doRender and not game:IsPaused() then
      return false
    end
    
    return mod.input.isButtonTriggered(button, controllerId)
  end
  
  Input.IsMouseBtnPressed = function(button)
    if mod.doRender and not game:IsPaused() then
      return false
    end
    
    return mod.input.isMouseBtnPressed(button)
  end
end

function mod:getButtonAction()
  local keyboard = 0
  
  if mod.input.isButtonTriggered(Keyboard.KEY_LEFT, keyboard) then
    return ButtonAction.ACTION_LEFT
  elseif mod.input.isButtonTriggered(Keyboard.KEY_RIGHT, keyboard) then
    return ButtonAction.ACTION_RIGHT
  elseif mod.input.isButtonTriggered(Keyboard.KEY_SPACE, keyboard) or mod.input.isButtonTriggered(Keyboard.KEY_ENTER, keyboard) then
    return ButtonAction.ACTION_MENUCONFIRM
  end
  
  for i = 0, game:GetNumPlayers() - 1 do
    local controller = game:GetPlayer(i).ControllerIndex
    
    if controller > keyboard then
      if mod.input.isActionTriggered(ButtonAction.ACTION_LEFT, controller) then
        return ButtonAction.ACTION_LEFT
      elseif mod.input.isActionTriggered(ButtonAction.ACTION_RIGHT, controller) then
        return ButtonAction.ACTION_RIGHT
      elseif mod.input.isActionTriggered(ButtonAction.ACTION_MENUCONFIRM, controller) then
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
  local room = game:GetRoom()
  local centerIdx = room:GetGridIndex(room:GetCenterPos())
  mod:spawnBigChest(room:GetGridPosition(centerIdx))
  
  local rng = RNG()
  rng:SetSeed(room:GetAwardSeed(), mod.rngShiftIdx) -- GetSpawnSeed, GetDecorationSeed
  if rng:RandomFloat() < 0.2 then -- 20%
    mod:spawnVoidPortal(room:GetGridPosition(centerIdx + (2 * room:GetGridWidth()))) -- 2 spaces lower
  end
  
  if REPENTOGON and game:GetVictoryLap() == 0 then
    local gameData = Isaac.GetPersistentGameData()
    gameData:IncreaseEventCounter(EventCounter.LAMB_KILLS, 1)
    game:RecordPlayerCompletion(CompletionType.LAMB)
  end
end

function mod:spawnBigChest(pos)
  Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BIGCHEST, 0, pos, Vector.Zero, nil)
end

function mod:spawnVoidPortal(pos)
  local room = game:GetRoom()
  
  local portal = Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 1, pos, true)
  if portal:GetType() ~= GridEntityType.GRID_TRAPDOOR then
    mod:removeGridEntity(room:GetGridIndex(pos), 0, false, true)
    portal = Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 1, pos, true)
  end
  
  portal.VarData = 1
  portal:GetSprite():Load('gfx/grid/voidtrapdoor.anm2', true)
end

function mod:removeGridEntity(gridIdx, pathTrail, keepDecoration, update)
  local room = game:GetRoom()
  
  if REPENTOGON then
    room:RemoveGridEntityImmediate(gridIdx, pathTrail, keepDecoration)
  else
    room:RemoveGridEntity(gridIdx, pathTrail, keepDecoration)
    if update then
      room:Update()
    end
  end
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

function mod:closeOtherMods()
  -- mod config menu
  if ModConfigMenu and ModConfigMenu.IsVisible then
    ModConfigMenu.CloseConfigMenu()
  end
  
  -- encyclopedia / dss
  if DeadSeaScrollsMenu and DeadSeaScrollsMenu.IsOpen() then
    DeadSeaScrollsMenu.CloseMenu(true, true)
  end
  
  -- salem (will come back in the next room)
  -- this could be extended to all NPCs / projectiles
  local salemType = Isaac.GetEntityTypeByName('Salem')       -- 894
  local salemVariant = Isaac.GetEntityVariantByName('Salem') -- 1626
  if salemType > 0 and salemVariant > -1 then
    for _, v in ipairs(Isaac.FindByType(salemType, salemVariant, -1, false, false)) do
      local salem = v:ToNPC()
      if salem then
        salem:Remove()
      end
    end
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

mod:overrideInput()
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
if REPENTOGON then
  mod:AddCallback(ModCallbacks.MC_POST_HUD_RENDER, mod.onHudRender)      -- MC_POST_HUD_RENDER draws over the HUD w/o a shader
else
  mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.onRender)             -- MC_POST_RENDER draws under the HUD
  mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, mod.onRenderShader) -- MC_GET_SHADER_PARAMS draws over the HUD
end
mod:AddPriorityCallback(ModCallbacks.MC_POST_PICKUP_INIT, CallbackPriority.LATE, mod.onPickupInit, PickupVariant.PICKUP_BIGCHEST)
mod:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, mod.onPreSpawnAward)
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.onEntityTakeDmg, EntityType.ENTITY_PLAYER)
mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_COLLISION, mod.onPrePlayerCollision)
mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, mod.onInputAction)

if ModConfigMenu then
  mod:setupModConfigMenu()
end