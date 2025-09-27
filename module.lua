local fbi = {
    services = {
        players = game:GetService("Players");
        workspace = game:GetService("Workspace");
        replicated = game:GetService("ReplicatedStorage");
        runservice = game:GetService("RunService");
    };

    flags = {
        reanimated = false;
    };

    clones = {};
    connections = { hb = nil; };
    real_chars = {};
};

local API = {}

local function try(func, ...)
    local success, result = pcall(func, ...);
    if not success then
        warn("FBI Error: " .. tostring(result));
        return nil;
    end;
    
    if typeof(result) == "string" then
        warn("FBI: " .. result);
        return nil;
    end;
    return result;
end;

local function get_localplayer()
    local player = fbi.services.players.LocalPlayer;
    if not player then
        return "bad argument to 'get_localplayer' (LocalPlayer not found; must run in a LocalScript)";
    end;
    return player;
end;

local function get_char(player)
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        return ("bad argument #1 to 'get_char' (Player expected, got %s)"):format(typeof(player));
    end;

    local character = player.Character;
    if not character or not character.Parent then
        return ("Player %s has no active character."):format(player.Name);
    end;

    return character;
end;

local function get_clone(player)
    local clone_char = fbi.clones[player];
    if not clone_char or not clone_char.Parent then
        return ("No clone found for player %s."):format(player.Name);
    end;
    return clone_char;
end;

local function clone_char(model)
    if typeof(model) ~= "Instance" then
        return ("bad argument #1 to 'clone_char' (Instance expected, got %s)"):format(typeof(model));
    end;
    
    model.Archivable = true;
    local new_clone = model:Clone();
    new_clone.Name = "Reanimation";
    new_clone.Parent = fbi.services.workspace;

    for _, part in ipairs(new_clone:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 1;
        end;
    end;

    return new_clone;
end;

local function fire_remote(remote, ...)
    if typeof(remote) ~= "Instance" then
        warn("FBI: " .. ("bad argument to 'fire_remote' (Instance expected, got %s)"):format(typeof(remote)));
        return;
    end;
    if not (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
        warn("FBI: " .. ("bad argument to 'fire_remote' (RemoteEvent or RemoteFunction expected, got %s)"):format(remote.ClassName));
        return;
    end;
    if remote:IsA("RemoteEvent") then
        remote:FireServer(...);
    else
        remote:InvokeServer(...);
    end;
end;

-- Toggles the Reanimate state.
-- @param bool (boolean) - true to enable reanimation, false to disable.
-- @param remote (Instance) [optional] - A RemoteEvent or RemoteFunction to fire after state change.
-- @param args (table) [optional] - Arguments to pass to the remote.
function API.reanimate(bool, remote, args)
    if bool ~= true and bool ~= false then
        warn("FBI: " .. ("bad argument #1 to 'reanimate' (boolean expected, got %s)"):format(typeof(bool)));
        return;
    end;

    local player = try(get_localplayer);
    if not player then return; end;

    if bool then
        if fbi.flags.reanimated then
            warn("FBI: Already reanimated.");
            return;
        end
        
        local real_char = try(get_char, player);
        if not real_char then return; end;

        fbi.real_chars[player] = real_char;

        local cloned_char = try(clone_char, real_char);
        if not cloned_char then return; end;

        fbi.clones[player] = cloned_char;
        
        if remote then
            fire_remote(remote, unpack(args or {}));
        end;

        player.Character = cloned_char;
        fbi.services.workspace.CurrentCamera.CameraSubject = cloned_char.Humanoid

        fbi.connections.hb = fbi.services.runservice.Heartbeat:Connect(function()
            if not real_char or not real_char.Parent or not cloned_char or not cloned_char.Parent then
                API.reanimate(false)
                return
            end
            for _, p in ipairs(real_char:GetChildren()) do
                local clone_part = cloned_char:FindFirstChild(p.Name);
                if p:IsA("BasePart") and clone_part then
                    p.CFrame = clone_part.CFrame;
                    p.Velocity = Vector3.new();
                end;
            end;
        end);

        fbi.flags.reanimated = true;

    else
        if not fbi.flags.reanimated then
            return;
        end
        
        if fbi.connections.hb then
            fbi.connections.hb:Disconnect();
            fbi.connections.hb = nil;
        end;

        local cloned_char = fbi.clones[player];
        if cloned_char and cloned_char.Parent then
            cloned_char:Destroy();
            fbi.clones[player] = nil;
        end;

        local real_char = fbi.real_chars[player];
        if real_char and real_char.Parent then
            player.Character = real_char;
            fbi.services.workspace.CurrentCamera.CameraSubject = real_char.Humanoid
        end;

        if remote then
            fire_remote(remote, unpack(args or {}));
        end;

        fbi.flags.reanimated = false;
    end;
end;

--- Returns true if the local player is currently reanimated.
-- @return boolean
function API.isReanimated()
    return fbi.flags.reanimated;
end

--- Gets the active clone character model for a player.
-- @param player (Player) [optional] - The player to get the clone of. Defaults to LocalPlayer.
-- @return Model | nil
function API.getClone(player)
    player = player or try(get_localplayer)
    if not player then return nil end
    return fbi.clones[player]
end

--- Gets the real character model for a player.
-- @param player (Player) [optional] - The player to get the real character of. Defaults to LocalPlayer.
-- @return Model | nil
function API.getRealCharacter(player)
    player = player or try(get_localplayer)
    if not player then return nil end
    return fbi.real_chars[player]
end

return API
