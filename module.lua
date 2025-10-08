local fbi = {
	services = {
		players = game:GetService("Players");
		workspace = game:GetService("Workspace");
		replicated = game:GetService("ReplicatedStorage");
		run_service = game:GetService("RunService");
		user_input_service = game:GetService("UserInputService");
        http_service = game:GetService("HttpService");
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
        animation_hb = nil;
	};
	real_chars = {};
	callbacks = {
		on_play = nil,
		on_stop = nil,
	},
	animation = {
        cache = {};
        state = {
            is_playing = false;
            current_url = nil;
            speed = 1.0;
            keyframes = nil;
            total_duration = 0;
            elapsed_time = 0;
        };
        original_motor_c0s = {};
        joints = {};
    };
};

local API = {};

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
		return ("bad argument to 'fire_remote' (Instance expected, got %s)"):format(typeof(remote));
	end;
	if not (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
		return ("bad argument to 'fire_remote' (RemoteEvent or RemoteFunction expected, got %s)"):format(remote.ClassName);
	end;
	if remote:IsA("RemoteEvent") then
		remote:FireServer(...);
	else
		remote:InvokeServer(...);
	end;
end;

--- Stops any currently playing animation.
API.stop_animation = function()
    if not fbi.animation.state.is_playing then return end;
    
	local stopped_url = fbi.animation.state.current_url

    if fbi.connections.animation_hb then
        fbi.connections.animation_hb:Disconnect();
        fbi.connections.animation_hb = nil;
    end

    local player = get_local_player();
    if typeof(player) == "string" then return player end;

    local clone_char = API.get_clone(player);
    if clone_char then
        for motor, orig_c0 in pairs(fbi.animation.original_motor_c0s) do
            if motor and motor.Parent then
                motor.C0 = orig_c0;
            end
        end
        local clone_animate_script = clone_char:FindFirstChild("Animate")
        if clone_animate_script then
            clone_animate_script.Enabled = true
        end
    end
    
    table.clear(fbi.animation.original_motor_c0s);
    table.clear(fbi.animation.joints);
    fbi.animation.state = { is_playing = false, current_url = nil, speed = 1.0, keyframes = nil, total_duration = 0, elapsed_time = 0 };

	if fbi.callbacks.on_stop then
		pcall(fbi.callbacks.on_stop, stopped_url)
	end
end;

--- Toggles the Reanimate state.
-- @param bool (boolean) - true to enable reanimation, false to disable.
-- @param remote (Instance) [optional] - A RemoteEvent or RemoteFunction to fire.
-- @param args (table) [optional] - Arguments for the remote.
API.reanimate = function(bool, remote, args)
	if bool ~= true and bool ~= false then
		return ("bad argument #1 to 'reanimate' (boolean expected, got %s)"):format(typeof(bool));
	end;
	local player = get_local_player();
	if typeof(player) == "string" then return player end;

	if bool then
		if fbi.flags.reanimated then
			return "Already reanimated.";
		end;
		local real_char = get_char(player);
        if typeof(real_char) == "string" then return real_char end;
		if not real_char:FindFirstChild("Humanoid") then
			return "Real character is missing a Humanoid.";
		end;
		local real_hrp = real_char:FindFirstChild("HumanoidRootPart")
		if not real_hrp then
			return "Real character is missing a HumanoidRootPart, cannot reanimate.";
		end
		fbi.real_chars[player] = real_char;
		local cloned_char = clone_char(real_char);
        if typeof(cloned_char) == "string" then return cloned_char end;
		if not cloned_char:FindFirstChild("Humanoid") then
			return "Cloned character failed to create or is missing a Humanoid.";
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
			local err = fire_remote(remote, unpack(args or {}));
            if err then return err end;
		end;
		fbi.flags.reanimated = true;
	else
		if not fbi.flags.reanimated then
			return;
		end;
        API.stop_animation();
		if remote then
			local err = fire_remote(remote, unpack(args or {}));
            if err then return err end;
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

--- Plays an animation on the reanimated character.
-- @param url (string) - The URL of the keyframe script.
-- @param speed (number) [optional] - The playback speed multiplier. Defaults to 1.
API.play_animation = function(url, speed)
    if not fbi.flags.reanimated then
        return "Cannot play animation, not reanimated.";
    end
    
    local player = get_local_player();
    if typeof(player) == "string" then return player end;
    
    local clone_char = API.get_clone(player);
    if not clone_char then 
        return "Cannot play animation, clone character not found.";
    end
    
    if fbi.animation.state.is_playing and fbi.animation.state.current_url == url then
        API.stop_animation();
        return;
    end
    
    API.stop_animation();
    
    local clone_anim_controller = clone_char:FindFirstChildOfClass("Humanoid") or clone_char:FindFirstChildOfClass("AnimationController")
    if clone_anim_controller then
        for _, track in ipairs(clone_anim_controller:GetPlayingAnimationTracks()) do
            track:Stop()
        end
    end
    local clone_animate_script = clone_char:FindFirstChild("Animate")
    if clone_animate_script then
        clone_animate_script.Enabled = false
    end
    
    local anim = fbi.animation;
    anim.state.speed = tonumber(speed) or 1.0;

    local keyframe_data = anim.cache[url];
    if not keyframe_data then
        local success, response = pcall(game.HttpGet, game, url);
		if not success then return "Animation Error: Failed to fetch URL." end

        local loaded_fn, err = loadstring(response);
		if not loaded_fn then return "Animation Error: Invalid script from URL. " .. tostring(err) end;
        
		local success, data = pcall(loaded_fn)
		if not success then return "Animation Error: Script from URL failed to execute. " .. tostring(data) end
        keyframe_data = data;

        if typeof(keyframe_data) ~= "table" then return "Animation Error: Script from URL did not return a table." end;
        
        anim.cache[url] = keyframe_data;
    end

    local keyframes = keyframe_data[next(keyframe_data)];
	if not keyframes or #keyframes == 0 then
		return "No keyframes array found for animation URL: " .. url;
	end

    anim.state.keyframes = keyframes;

    table.clear(anim.joints);
    table.clear(anim.original_motor_c0s);
    for _, descendant in ipairs(clone_char:GetDescendants()) do
        if descendant:IsA("Motor6D") then
            anim.joints[descendant.Part1.Name] = descendant;
            anim.original_motor_c0s[descendant] = descendant.C0;
        end
    end

    anim.state.is_playing = true;
    anim.state.current_url = url;
    anim.state.total_duration = keyframes[#keyframes].Time;
	if anim.state.total_duration <= 0 then API.stop_animation(); return end;
	
	anim.state.elapsed_time = 0;
	
	if fbi.callbacks.on_play then
		pcall(fbi.callbacks.on_play, anim.state.current_url)
	end
	
	fbi.connections.animation_hb = fbi.services.run_service.Heartbeat:Connect(function(deltaTime)
		if not anim.state.is_playing then return end;
		
		anim.state.elapsed_time = (anim.state.elapsed_time + (deltaTime * anim.state.speed)) % anim.state.total_duration;
		
		local current_frame, next_frame;
		for i = 1, #anim.state.keyframes - 1 do
			if anim.state.elapsed_time >= anim.state.keyframes[i].Time and anim.state.elapsed_time < anim.state.keyframes[i+1].Time then
				current_frame = anim.state.keyframes[i];
				next_frame = anim.state.keyframes[i+1];
				break;
			end
		end
		if not current_frame then
			current_frame = anim.state.keyframes[#anim.state.keyframes];
			next_frame = anim.state.keyframes[1];
		end
		
		local frame_duration = next_frame.Time - current_frame.Time;
		if frame_duration <= 0 then frame_duration = anim.state.total_duration end;

		local alpha = (frame_duration > 0) and (anim.state.elapsed_time - current_frame.Time) / frame_duration or 0;
		alpha = math.clamp(alpha, 0, 1)

		for partName, pose_cframe in pairs(current_frame.Data) do
            local motor = anim.joints[partName];
            if motor and anim.original_motor_c0s[motor] then
                local original_c0 = anim.original_motor_c0s[motor];
                local next_pose_cframe = next_frame.Data and next_frame.Data[partName];

                if next_pose_cframe then
                    motor.C0 = original_c0 * pose_cframe:Lerp(next_pose_cframe, alpha);
                else
                    motor.C0 = original_c0 * pose_cframe;
                end
            end
		end
	end);
end;

--- Sets the playback speed for any currently playing animation.
-- @param speed (number) - The new playback speed multiplier.
API.set_animation_speed = function(speed)
    fbi.animation.state.speed = tonumber(speed) or 1.0;
end;

--- Registers a callback function to be called when an animation starts playing.
-- @param callback (function) - The function to call. It receives the animation URL as an argument.
API.on_animation_play = function(callback)
	if type(callback) == "function" then
		fbi.callbacks.on_play = callback
	end
end

--- Registers a callback function to be called when an animation stops.
-- @param callback (function) - The function to call. It receives the animation URL that was stopped.
API.on_animation_stop = function(callback)
	if type(callback) == "function" then
		fbi.callbacks.on_stop = callback
	end
end

--- Returns the current animation playback state.
-- @return boolean, string | nil - is_playing, current_url
API.is_animation_playing = function()
	return fbi.animation.state.is_playing, fbi.animation.state.current_url
end

--- Returns true if the local player is currently reanimated.
-- @return boolean
API.is_reanimated = function()
	return fbi.flags.reanimated;
end;

--- Gets the active clone character model for a player.
-- @param player (Player) [optional] - The player to get the clone of. Defaults to LocalPlayer.
-- @return Model | nil
API.get_clone = function(player)
	player = player or get_local_player();
	if typeof(player) == "string" then return nil end;
	return fbi.clones[player];
end;

--- Gets the real character model for a player.
-- @param player (Player) [optional] - The player to get the real character of. Defaults to LocalPlayer.
-- @return Model | nil
API.get_real_character = function(player)
	player = player or get_local_player();
	if typeof(player) == "string" then return nil end;
	return fbi.real_chars[player];
end;

return API;
