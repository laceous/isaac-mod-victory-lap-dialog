local mod = RegisterMod('Victory Lap Dialog', 1)
local json = require('json')
local game = Game()

mod.shaderName = 'VictoryLapDialog_DummyShader'

mod.allowInitDialog = false
mod.doRender = false
mod.isYes = false
mod.handleInput = false
mod.blockInput = false
mod.sprite = Sprite()

function mod:onGameExit()
  mod:resetVars()
end

function mod:onNewRoom()
  local room = game:GetRoom()
  
  mod:resetVars()
  
  if not room:IsClear() then
    mod.allowInitDialog = true
  end
end

function mod:onUpdate()
  if not game:IsGreedMode() and Isaac.GetChallenge() == Challenge.CHALLENGE_NULL and mod.allowInitDialog then
    local level = game:GetLevel()
    local room = level:GetCurrentRoom()
    local roomDesc = level:GetCurrentRoomDesc()
    local stage = level:GetStage()
    
    if room:GetType() == RoomType.ROOM_BOSS and room:IsClear() then
      if not (stage == LevelStage.STAGE5 and     level:IsAltStage() and roomDesc.GridIndex >= 0 and mod:hasCollectible(CollectibleType.COLLECTIBLE_POLAROID)) and -- isaac w/ polaroid
         not (stage == LevelStage.STAGE5 and not level:IsAltStage() and roomDesc.GridIndex >= 0 and mod:hasCollectible(CollectibleType.COLLECTIBLE_NEGATIVE)) and -- satan w/ negative
         not (stage == LevelStage.STAGE6 and not level:IsAltStage() and roomDesc.GridIndex >= 0) then                                                             -- the lamb
           if mod:hasBigChest() then
             mod:initDialog()
           end
           mod.allowInitDialog = false
      end
    end
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
      mod.sprite:Update()
      mod.sprite:Render(Isaac.WorldToRenderPosition(Vector(320,280)), Vector(0,0), Vector(0,0))
      
      if mod.sprite:IsFinished('Appear') then
        mod.handleInput = true
      elseif mod.sprite:IsFinished('Dissappear') then
        mod.doRender = false
        mod.blockInput = false
        if mod.isYes then
          game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT, false)
          game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH, false)
          game:SetStateFlag(GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED, false)
          game:NextVictoryLap()
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

-- this isn't perfect, it can't block keyboard inputs that other mods might be listening to (e.g. mod config menu)
function mod:onInputAction(entity, inputHook, buttonAction)
  if mod.blockInput then
    if inputHook == InputHook.IS_ACTION_PRESSED or inputHook == InputHook.IS_ACTION_TRIGGERED then
      return false
    else -- GET_ACTION_VALUE
      return 0
    end
  end
end

-- filtered to ENTITY_PLAYER
function mod:onEntityTakeDmg()
  if mod.blockInput then
    return false -- ignore damage (just in case)
  end
end

function mod:isCurseOftheLabyrinth()
  local level = game:GetLevel()
  local curses = level:GetCurses()
  
  return curses & LevelCurse.CURSE_OF_LABYRINTH == LevelCurse.CURSE_OF_LABYRINTH
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
  mod.allowInitDialog = false
  mod.doRender = false
  mod.isYes = false
  mod.handleInput = false
  mod.blockInput = false
end

function mod:initDialog()
  mod.sprite:Play('Appear', true)
  mod.doRender = true
  mod.isYes = false
  mod.handleInput = false
  mod.blockInput = true
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

function mod:hasCollectible(collectible)
  for i = 0, game:GetNumPlayers() - 1 do
    local player = game:GetPlayer(i)
    
    if player:HasCollectible(collectible, false) then
      return true
    end
  end
  
  return false
end

function mod:hasBigChest()
  for _, entity in ipairs(Isaac.GetRoomEntities()) do
    if entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_BIGCHEST then
      return true
    end
  end
  
  return false
end

function mod:loadSprite()
  mod.sprite:Load('gfx/ui/prompt_yesno.anm2', false)
  mod.sprite:ReplaceSpritesheet(2, 'gfx/ui/prompt_victoryrun.png') -- animation editor shows this as 1
  mod.sprite:LoadGraphics()
end

mod:loadSprite()
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, mod.onRender) -- MC_GET_SHADER_PARAMS draws over the HUD, MC_POST_RENDER draws under the HUD
mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, mod.onInputAction)
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.onEntityTakeDmg, EntityType.ENTITY_PLAYER)