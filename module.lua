local fbi = {
	services = {
		players = game:GetService("Players");
		workspace = game:GetService("Workspace");
		replicated = game:GetService("ReplicatedStorage");
		run_service = game:GetService("RunService");
		user_input_service = game:GetService("UserInputService");
	};
	flags = {
		reanimated = false;
	};
	clones = {};
	connections = {
		hb = nil;
		died = nil;
		real_char_child_removed = nil;
		character_removing = nil;
		clone_died = nil;
		clone_char_child_removed = nil;
	};
	real_chars = {};
};

local API = {};

local try = function(func, ...)
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

local set_model_transparency = function(model, transparency)
	if not model then
		return;
	end;
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = transparency;
		end;
	end;
end;

local get_local_player = function()
	local player = fbi.services.players.LocalPlayer;
	if not player then
		return "bad argument to 'get_local_player' (LocalPlayer not found; must run in a LocalScript)";
	end;
	return player;
end;

local get_char = function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return ("bad argument #1 to 'get_char' (Player expected, got %s)"):format(typeof(player));
	end;
	local character = player.Character;
	if not character or not character.Parent then
		return ("Player %s has no active character."):format(player.Name);
	end;
	return character;
end;

local get_clone = function(player)
	local clone_char = fbi.clones[player];
	if not clone_char or not clone_char.Parent then
		return ("No clone found for player %s."):format(player.Name);
	end;
	return clone_char;
end;

local clone_char = function(model)
	if typeof(model) ~= "Instance" then
		return ("bad argument #1 to 'clone_char' (Instance expected, got %s)"):format(typeof(model));
	end;
	model.Archivable = true;
	local new_clone = model:Clone();
	model.Archivable = false;
	new_clone.Name = "Reanimation";
	new_clone.Parent = fbi.services.workspace;
	new_clone:WaitForChild("Animate").Disabled = true;
    new_clone.Humanoid.RequiresNeck = false;
    new_clone.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None;
	if new_clone:FindFirstChildWhichIsA("ForceField") then
		new_clone:FindFirstChildWhichIsA("ForceField"):Destroy();
	end;
	return new_clone;
end;

local fire_remote = function(remote, ...)
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

--- Toggles the Reanimate state.
-- @param bool (boolean) - true to enable reanimation, false to disable.
-- @param remote (Instance) [optional] - A RemoteEvent or RemoteFunction to fire.
-- @param args (table) [optional] - Arguments for the remote.
API.reanimate = function(bool, remote, args)
	if bool ~= true and bool ~= false then
		warn("FBI: " .. ("bad argument #1 to 'reanimate' (boolean expected, got %s)"):format(typeof(bool)));
		return;
	end;
	local player = try(get_local_player);
	if not player then
		return;
	end;
	if bool then
		if fbi.flags.reanimated then
			warn("FBI: Already reanimated.");
			return;
		end;
		local real_char = try(get_char, player);
		if not real_char or not real_char:FindFirstChild("Humanoid") then
			return;
		end;
		local real_hrp = real_char:FindFirstChild("HumanoidRootPart")
		if not real_hrp then
			warn("FBI: Real character is missing a HumanoidRootPart, cannot reanimate.");
			return;
		end
		fbi.real_chars[player] = real_char;
		local cloned_char = try(clone_char, real_char);
		if not cloned_char or not cloned_char:FindFirstChild("Humanoid") then
			warn("FBI: Cloned character failed to create or is missing a Humanoid.");
			return;
		end;
		fbi.clones[player] = cloned_char;
		set_model_transparency(cloned_char, 1);
		local player_gui = player:FindFirstChildWhichIsA("PlayerGui");
		if player_gui then
			for _, gui in player_gui:GetChildren() do
				if gui:IsA("ScreenGui") and gui.ResetOnSpawn then
					gui.ResetOnSpawn = false;
				end;
			end;
		end;
		player.Character = cloned_char;
		cloned_char:WaitForChild("Animate").Disabled = true;
		cloned_char:WaitForChild("Animate").Disabled = false;
		if player_gui then
			for _, gui in player_gui:GetChildren() do
				if gui:IsA("ScreenGui") and not gui.ResetOnSpawn then
					gui.ResetOnSpawn = true;
				end;
			end;
		end;
		fbi.connections.hb = fbi.services.run_service.Heartbeat:Connect(function()
			if not real_char or not real_char.Parent or not cloned_char or not cloned_char.Parent then
				API.reanimate(false, remote, args);
				return;
			end;
			for _, p in real_char:GetChildren() do
				local clone_part = cloned_char:FindFirstChild(p.Name);
				if p:IsA("BasePart") and clone_part then
					p.CFrame = clone_part.CFrame;
					p.Velocity = Vector3.new();
				end;
			end;
		end);
		local real_humanoid = real_char.Humanoid;
		local cloned_humanoid = cloned_char.Humanoid;
		fbi.connections.died = real_humanoid.Died:Connect(function()
			API.reanimate(false, remote, args);
		end);
		fbi.connections.real_char_child_removed = real_char.ChildRemoved:Connect(function(child)
			if child == real_humanoid or child == real_hrp then
				API.reanimate(false, remote, args);
			end;
		end);
		fbi.connections.clone_char_child_removed = cloned_char.ChildRemoved:Connect(function(child)
			if child == cloned_humanoid then
				API.reanimate(false, remote, args);
			end;
		end);
		fbi.connections.clone_died = cloned_humanoid.Died:Connect(function()
			local current_real_humanoid = real_char and real_char:FindFirstChild("Humanoid");
			if current_real_humanoid and current_real_humanoid.Health > 0 then
				current_real_humanoid.Health = 0;
			else
				API.reanimate(false, remote, args);
			end;
		end);
		fbi.connections.character_removing = player.CharacterRemoving:Connect(function(character_being_removed)
			if character_being_removed == cloned_char or character_being_removed == real_char then
				API.reanimate(false, remote, args);
			end;
		end);
		if remote then
			fire_remote(remote, unpack(args or {}));
		end;
		fbi.flags.reanimated = true;
	else
		if not fbi.flags.reanimated then
			return;
		end;
		if remote then
			fire_remote(remote, unpack(args or {}));
		end;
		for key, connection in pairs(fbi.connections) do
			if connection then
				connection:Disconnect();
				fbi.connections[key] = nil;
			end;
		end;
		local cloned_char = fbi.clones[player];
		if cloned_char and cloned_char.Parent then
			cloned_char:Destroy();
			fbi.clones[player] = nil;
		end;
		local real_char = fbi.real_chars[player];
		if real_char and real_char.Parent then
			set_model_transparency(real_char, 0);
			local hrp = real_char:FindFirstChild("HumanoidRootPart");
			if hrp then
				hrp.Transparency = 1;
			end;
			local player_gui = player:FindFirstChildWhichIsA("PlayerGui");
			if player_gui then
				for _, gui in player_gui:GetChildren() do
					if gui:IsA("ScreenGui") and gui.ResetOnSpawn then
						gui.ResetOnSpawn = false;
					end;
				end;
			end;
			player.Character = real_char;
			if player_gui then
				for _, gui in player_gui:GetChildren() do
					if gui:IsA("ScreenGui") and not gui.ResetOnSpawn then
						gui.ResetOnSpawn = true;
					end;
				end;
			end;
		end;
		fbi.flags.reanimated = false;
	end;
end;

--- Returns true if the local player is currently reanimated.
-- @return boolean
API.isReanimated = function()
	return fbi.flags.reanimated;
end;

--- Gets the active clone character model for a player.
-- @param player (Player) [optional] - The player to get the clone of. Defaults to LocalPlayer.
-- @return Model | nil
API.getClone = function(player)
	player = player or try(get_local_player);
	if not player then
		return nil;
	end;
	return fbi.clones[player];
end;

--- Gets the real character model for a player.
-- @param player (Player) [optional] - The player to get the real character of. Defaults to LocalPlayer.
-- @return Model | nil
API.getRealCharacter = function(player)
	player = player or try(get_local_player);
	if not player then
		return nil;
	end;
	return fbi.real_chars[player];
end;

return API;
