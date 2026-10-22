# TargetCharms

TargetCharms gives you a floating toolbar for quick access to charms and raid target icons. Arrange the buttons in any order and customize their spacing, opacity, position, and size. A movable **Ready Check** button and a **world marker / flare** toolbar make it useful for party and raid leaders.

## Clients

The same Lua and XML files are shared by all supported variants. Keep the TOC files together: the game selects the appropriate one automatically.

| Client | TOC file | Interface |
| --- | --- | --- |
| Retail | `TargetCharms_Mainline.toc` | `120105`, `120107` |
| WoW Forever / Camelot | `TargetCharms_Camelot.toc` | `16001` |
| Classic Era | `TargetCharms_Vanilla.toc` | `11509` |
| Mists of Pandaria Classic | `TargetCharms_Mists.toc` | `50504` |
| Burning Crusade Classic / Anniversary | `TargetCharms_TBC.toc` | `20506` |

`TargetCharms.toc` also contains the client-specific interface metadata as a fallback. These targets refer to Blizzard's modern clients, rather than the original 2004–2012 executables.

World markers are available only when the client exposes and enables its raid marker system. TargetCharms hides that toolbar when the system is unavailable; adding a TOC cannot add a missing game feature. Marker placement and ready checks remain subject to the game's group permissions and restrictions.

## Installation

1. Download or clone the repository.
2. Place the addon in your chosen client's `Interface/AddOns/TargetCharms` folder. `TargetCharms.toc`, `Locales.lua`, and both XML files must be directly inside that folder.
3. Start the game and enable **TargetCharms** in the AddOns list.

Install the addon separately for each client you use. No external addon libraries are required. Saved settings are retained under `TargetCharms_OptionsGlobal` and `TargetCharms_Options`.

## Controls

- **Left-click a target icon:** assign that icon to your current target. The clear button removes the target icon.
- **Toggle icons:** enable the option in setup to remove an icon when you click the same icon again.
- **Ready Check:** left-click the button to start a ready check when your group permissions allow it. The button does not initiate checks during combat.
- **World markers:** left-click a marker, then choose its location in the world. Use the clear button to remove world markers.
- **Move target icons or Ready Check:** right-click and drag. Enable **Draggable** in setup first.
- **Move world markers:** drag the small handle in the world marker toolbar.
- **Open setup:** Ctrl+right-click a toolbar/button, or enter `/tc setup`.

Move frames and configure layouts outside combat. Setup is hidden when combat starts. Protected frame changes are deferred until combat ends; marker clicks use Blizzard's secure actions.

## Commands

| Command | Action |
| --- | --- |
| `/tc setup` | Open the setup window. |
| `/tc reset` | Reset layout, position, size, and display options to defaults. |
| `/tc` | Show command help. |

`/targetcharms` is an alias for `/tc`.

## Custom layouts

Each button consists of a direction character followed by an icon character. For example, `>1>2>3` creates a horizontal row of star, circle, and diamond.

| Direction | Placement relative to the previous button |
| --- | --- |
| `>` | Right |
| `<` | Left |
| `^` | Up |
| `v` | Down |

| Target icon | Character |
| --- | --- |
| Clear | `0` |
| Star, Circle, Diamond, Triangle | `1`, `2`, `3`, `4` |
| Moon, Square, Cross, Skull | `5`, `6`, `7`, `8` |
| Hidden spacer | `_` |

| World marker | Character |
| --- | --- |
| Blue, Green, Purple, Red | `B`, `G`, `P`, `R` |
| Yellow, Orange, Silver, White | `Y`, `O`, `S`, `W` |
| Drag handle | `D` |
| Clear all | `X` |
| Hidden spacer | `_` |

Layouts support up to 20 slots. Presets are also available in the setup window. Availability of individual world markers depends on the client.

## Compatibility work in 1.7.2

- Added TOCs for Retail, Forever, Classic Era, Mists Classic, and TBC Classic.
- Added fallbacks for modern and legacy addon metadata, settings categories, and ready-check APIs.
- Used native secure `raidtarget` and `worldmarker` actions across clients, with support for both key-down and key-up click settings.
- Moved target/group visibility to secure state drivers and deferred protected changes during combat.
- Fixed stale buttons after shortening a layout, switching a world-marker slot between an icon and a drag handle, and applying the toggle option.
- Kept the saved-variable schema compatible and rebuilt the toolbars when resetting options.

## Validation

Lua files and embedded XML scripts are checked against Lua 5.1 syntax. The compatibility harness in `tests/compatibility.lua` models the five clients, both settings/metadata API styles, unavailable world markers, layout changes, dragging, reset, and combat restrictions. It can optionally run extracted `raidtarget` and `worldmarker` handlers from each client's Blizzard UI source.

From the repository root, with a Lua interpreter installed:

```sh
lua tests/compatibility.lua Mainline
lua tests/compatibility.lua Camelot
lua tests/compatibility.lua Vanilla
lua tests/compatibility.lua Mists
lua tests/compatibility.lua TBC
```

These are simulated API tests, not a completed in-game certification. Before releasing, check each client in game: load/reload and saved settings; mark, toggle, and clear a target; shorten/change a layout; move all three toolbars; start a ready check as leader; place/clear available world markers; enter and leave combat while changing targets. Confirm that no Lua errors or blocked-action messages appear. Interface numbers may need updates after future game patches; `/dump select(4, GetBuildInfo())` shows the current client's number.

API behavior was reviewed against Blizzard's UI code, mirrored in [Retail](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua), [Forever](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua), [Classic Era](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua), [Mists Classic](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua), and [TBC Anniversary](https://github.com/Gethe/wow-ui-source/blob/classic_anniversary/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua). Interface metadata was cross-checked with the [Plater maintainer's multi-client TOC](https://github.com/Tercioo/Plater-Nameplates/blob/master/Plater.toc).

## Special thanks

*Gander, the original author of TargetCharms.*

*blazer404, for fixing most of the recent issues.*

**Original version by gander_curse:** [Target Charms on CurseForge](https://www.curseforge.com/wow/addons/target-charms)

Cheers,  
sAks/eusi
