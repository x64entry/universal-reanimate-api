# FBI Reanimation Module

A self-contained Roblox module for networkless (netless) reanimation, utilizing a vulnerability found in most ragdoll systems.

### v1.1.0
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
    -   [`API.isReanimated()`](#apiisreanimated)
    -   [`API.getClone()`](#apigetclone)
    -   [`API.getRealCharacter()`](#apigetrealcharacter)
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

### `API.isReanimated()`

Returns whether the reanimation module is currently active.

-   **Returns**: (boolean) - `true` if reanimated, `false` otherwise.

```lua
if api.isReanimated() then
    print("The player is currently reanimated.")
end
```

---

### `API.getClone()`

Retrieves the active clone `Model` being controlled by the player.

-   **Returns**: (Model | nil) - The clone character model, or `nil` if not currently reanimated.

---

### `API.getRealCharacter()`

Retrieves the original character `Model` that is being synchronized.

-   **Returns**: (Model | nil) - The real character model, or `nil` if not currently reanimated.

```lua
local real_character = api.getRealCharacter()
if real_character then
    -- You could, for example, change the color of the real character's parts
    real_character.Head.BrickColor = BrickColor.Red()
end
```

## Full Example

This example demonstrates how to set up remotes and toggle a ragdoll state using the module.

```lua
local replicated_storage = game:GetService("ReplicatedStorage")
local ragdoll = replicated_storage:WaitForChild("RagdollEvent")
local unragdoll = replicated_storage:WaitForChild("UnragdollEvent")

-- Load the API
local api = loadstring(game:HttpGet("https://raw.githubusercontent.com/x64entry/universal-reanimate-api/refs/heads/main/module.lua"))()

-- Enable reanimation and fire the ragdoll event
api.reanimate(true, ragdoll)

-- After 10 seconds, disable reanimation and fire the unragdoll event
task.wait(10)
api.reanimate(false, unragdoll)
```
