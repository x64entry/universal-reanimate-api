# FBI Reanimation Module

A self-contained Roblox module for networkless (netless) reanimation, utilizing a vulnerability found in most ragdoll systems.

### v1.3.0
- **Added** `API.play_animation(url, speed)` to play custom keyframe animations on the reanimated character.
- **Added** `API.stop_animation()` to halt any active animation.
- **Changed** function names to use underscore convention (`is_reanimated`, `get_clone`, `get_real_character`) for consistency.

### v1.2.0
- **Reverted** the previous transparent limbs update.
- **Disabled** `RequiresNeck` in clone humanoid to prevent unwanted death.

### v1.1.0
- **Fixed** issue where GUIs would disappear after reanimating.  
- **Fixed** chat not working after reanimating.  
- **Changed** transparent limbs from the clone to the real character.  
- **Changed** humanoid name display to be hidden.  
- **Added** check to remove `ForceField` from clone.  
- **Added** listeners for (probably) all death-related events to cleanup reanimation.  
- **Added** animation refresh on reanimate; clones now animate by default.  
- **Improved** unreanimate cleanup by fully disconnecting all event listeners.  

### v1.0.0
- Initial release of FBI Reanimation Module.

## Table of Contents

-   [API Reference](#api-reference)
    -   [`API.reanimate(enable, remote, args)`](#apireanimateenable-remote-args)
    -   [`API.play_animation(url, speed)`](#apiplay_animationurl-speed)
    -   [`API.stop_animation()`](#apistop_animation)
    -   [`API.is_reanimated()`](#apiis_reanimated)
    -   [`API.get_clone()`](#apiget_clone)
    -   [`API.get_real_character()`](#apiget_real_character)
-   [Full Example](#full-example)

## API Reference

### `API.reanimate(enable, remote, args)`

Toggles the reanimation state for the local player.

-   **`enable`** (boolean):
    -   `true`: Clones the character and enables the reanimation.
    -   `false`: Destroys the clone, restores the original character, and disables the reanimation.
-   **`remote`** (Instance) `[optional]`: A `RemoteEvent` or `RemoteFunction` to be fired/invoked immediately after the state changes.
-   **`args`** (table) `[optional]`: A table of arguments to be passed to the remote when it is fired.

```lua
-- Example: Enable reanimation and tell the server to ragdoll the character
local ragdoll = game:GetService("ReplicatedStorage").RagdollEvent
api.reanimate(true, ragdoll, {"SomeArgument"})

-- Example: Disable reanimation and tell the server to un-ragdoll
local unragdoll = game:GetService("ReplicatedStorage").UnragdollEvent
api.reanimate(false, unragdoll)
```

---

### `API.play_animation(url, speed)`

Plays a custom animation on the real (visible) character model. Only works while reanimation is active.

-   **`url`** (string): The raw URL to a script that returns a keyframe table (e.g., from `ichfickdeinemutta.pages.dev`).
-   **`speed`** (number) `[optional]`: The playback speed multiplier. Defaults to `1.0`.

**Note:** Calling this function with the same URL of a currently playing animation will stop it.

```lua
-- Play an animation at normal speed
api.play_animation("https://example.com")

-- Play another animation at double speed
task.wait(5)
api.play_animation("https://example.com", 2)
```

---

### `API.stop_animation()`

Stops any custom animation that is currently playing. The character will return to its default pose.

```lua
api.stop_animation()
```

---

### `API.is_reanimated()`

Returns whether the reanimation module is currently active.

-   **Returns**: (boolean) - `true` if reanimated, `false` otherwise.

```lua
if api.is_reanimated() then
    print("The player is currently reanimated.")
end
```

---

### `API.get_clone()`

Retrieves the active, invisible clone `Model` being controlled by the player.

-   **Returns**: (Model | nil) - The clone character model, or `nil` if not currently reanimated.

---

### `API.get_real_character()`

Retrieves the original, visible character `Model` that is being synchronized and animated.

-   **Returns**: (Model | nil) - The real character model, or `nil` if not currently reanimated.

```lua
local real_character = api.get_real_character()
if real_character then
    -- You could, for example, change the color of the real character's parts
    real_character.Head.BrickColor = BrickColor.Red()
end
```

## Full Example

This example demonstrates how to enable reanimation, play a custom animation, and then clean up.

```lua
local replicated_storage = game:GetService("ReplicatedStorage")
local ragdoll = replicated_storage:WaitForChild("RagdollEvent")
local unragdoll = replicated_storage:WaitForChild("UnragdollEvent")

-- Load the API
local api = loadstring(game:HttpGet("https://raw.githubusercontent.com/x64entry/universal-reanimate-api/main/module.lua"))()

-- Enable reanimation and fire the ragdoll event
api.reanimate(true, ragdoll)
if api.is_reanimated() then
    -- Play a custom animation
    local animation_url = <insert a url here>
    api.play_animation(animation_url, 1.5) -- Play at 1.5x speed
end

-- After 10 seconds, stop the animation, disable reanimation, and fire the unragdoll event
task.wait(10)
api.stop_animation()
api.reanimate(false, unragdoll)
```
