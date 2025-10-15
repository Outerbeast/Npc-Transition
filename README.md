# Npc Transition
Custom entities that allow npcs to cross level changes in Sven Co-op

# Getting Started:

To install [download](https://github.com/Outerbeast/Npc-Transition/archive/refs/heads/main.zip) and extract into your map's `scripts/maps/` folder

To enable it in your map(s) either:
- `map_script npc_transition` in your map's cfg file
OR

- `#include "npc_transition"` in your map's main script file header
OR

- Add a trigger_script entity pointing with the keyvalue `"m_iszScriptFile" "npc_transition"`

# Description

These entities will allow you to transfer npcs from one map to the next.
By default, entities within a zone at the time of a map change will be transitioned to the next level, if the nextmap key is set and a valid bsp exists
The entity can also be triggered manually by another entity.

# Configuring the transition entity

The entity comes in two flavours, but both share the same keys and flags:
- `env_transition` is a point entity that uses a user-defined zone which if npcs exist inside of will be saved and transferred to the next level. The entity can use a radius or a sizeable bounding box to define the zone. The entity's position sets the current level landmark, the exact position in the map is not important but the next maps landmark position must match.
- `func_transition` is a brush entity which the transition zone is based on the brush model dimensions, and must use a brush origin as the landmark. Only cuboidal brush models are allowed.

`"frags"` can be used to get the current number of entities within the zone.

## Positioning

| Name | Key | Description |
| ----| :---: | -------- |
| Origin |`"origin" "x y z"`| This is the starting landmark position for the transition. |
| Angles |`"angles" "p y r"`| Changes the orientation of the npcs saved. |
| Zone Radius |`"zoneradius" "r"` | Transition zone radius. Default is 128, set value cannot go lower than 16. Radius is used by default if zone bounds are not defined/measured incorrectly. |
| Transition Zone Min (X Y Z) |`"zonecornermin" "x1 y1 z1"`| Transition zone bounding box min origin (if you are facing 0 degrees, this is the coords of the lower front right corner of the box). |
| Transition Zone Max (X Y Z) |`"zonecornermax" "x2 y2 z2"` | Same as above but upper back left corner of the box. |
| Next map landmark position (X Y Z) |`"landmark" "x y z"` | Coordinates for the same position in the next map. If left undefined, the next map will need an info_landmark. |

## Logic
| Name | Key | Description |
| ----| :---: | -------- |
| Name |`"targetname" "trigger_me"` | Add a targetname if you want something else to trigger this, rather than automatically during a map change. |
| Target |`"target" "target_entity"` | Target to trigger when a transition successfully happens. |
| Transition failed Target |`"netname" "target_entity"` | Target to trigger when a transition fails (in the current level). |
| Target in next map |`"message" "target_entity"` | Target to trigger in the next level, when npcs are successfully loaded. This can be set to target a specific info_landmark in the next map. |
| Minimum Monsters Required |`"mincount" "1"` | Minimum no. of npcs required to be in the zone to trigger the entity. This is always 1 by default. |
| Maximum Monsters Allowed |`"maxcount" "128"` | Maximum no. of npcs allowed to transition to the next level. |

## Flags
| Name | Value `"spawnflags" "f"` | Description |
| ----| :---: | -------- |
| Start Off | `1` | Entity starts inactive, trigger to turn it on. |
| Trigger when Mincount Reached | `2` | Entity will automatically trigger its target when the `mincount` number of entities are within the zone. |
| Include Enemies | `4` | Enemy npcs will also be transferred to the next level. This is required when using `is_player_ally` key on a hostile monster e.g. for a robogrunt. |
| Ignore Blacklist | `8` | Blacklisted npcs will be transitioned to the next level. |

# Configuring info_landmark

If the previous level's transition entity did not have a `landmark` value set to a point in the next map, then the next map will need to have a info_landmark to set the ending landmark point for the transition.
It must be positioned such that it matches the exact same location with regards to the world as the previous map's transition entity origin point. This is to ensure that transitioned monsters spawn in the correct place.
If there is more than one landmark entity in the map, all of them must have a targetname set, and the previous level's `message` key must target the corresponding info_landmark.

## Keys
| Name | Key | Description |
| ----| :---: | -------- |
| Name | `"targetname" "trigger_me"` | Set a name if you want to trigger the npcs to spawn manually, otherwise its automatically done if left undefined. The previous map's transition entity can target this landmark via `"message"`. |
| Target on Spawn | `"target" "target_entity"` | Target to trigger for every npc spawned. The `!activator` is the npc spawned. |
| Spawn successful Target | `"message" "target_entity"` | This will trigger if transitioned npcs successfully spawned |
| Spawn failed Target | `"netname" "target_entity"` | This will trigger if transitioned npcs failed to spawn |
| Entity transition limit | `"health" "h"` | Set a limit for how many npcs are allowed to spawn here. |

`"frags"` can be used to access the current count of transition npcs spawned in the level.

# Monster Keys
These are keyvalues that are meant to be set for monster entities in the map.
- `"$i_transition_type" "i"` This is used to keep track of monsters that have went through a changelevel. You can explicitly set this keyvalue for a monster to "-1" to prevent them transitioning to the next level.`
- `"$i_is_player_ally"  "1"` Because of game limitations, `is_player_ally` value cannot be retrieved by the AS API. If a mapper has changed the `is_player_ally` value for a monster they need to set this keyvalue in addition so the ally toggle state is saved correctly. Ensure that the `"Include Enemies"` flag has been set first.

# Known Issues
- Players may take npcs to the level change trigger to a spot where they might obstruct the spawn point in the next level, and may lead to players spawning inside the transitioned npcs leading to a softlock. Players are encouraged to avoid taking npcs very close to the trigger_changelevel.

- You might notice that monsters might have different textures/bodyparts after a level change, which may be controlled by the entity's `"head"` value. Unfortunately a monster's `"head"` value cannot be retrieved with AngelScript because of game/API limitations.

# Planned features:
- Add a classname/targetname filter
- Add a feature for blacklist inversion



