# HoverToolTip

Standalone tooltip styling addon for World of Warcraft Retail.

HoverToolTip was built as its own tooltip module and originally lived inside ElvUI_MerathilisUI during development. It is inspired by the idea behind MerathilisUI's NameHover module, but it is not an extraction of MerathilisUI code.

HoverToolTip styles Blizzard's native `GameTooltip` directly instead of copying protected tooltip text into a separate frame. This keeps open-world tooltip customization flexible while using a conservative visual-only path for restricted instance tooltips in dungeons, raids, scenarios, and Delves.

## Requirements

- World of Warcraft: Retail, interface `120005`
- Optional: ElvUI
- Optional: Details

## Features

- Transparent tooltip backdrop and border styling
- Status bar visibility control
- Tooltip scale, text alpha, font size, and outline settings
- Named profiles with per-character profile selection
- Profile import/export for sharing or backing up settings
- Presets for Minimal, Clean, and Full Info setups
- Tabbed options window for setup, general styling, text, and line controls
- Open-world player, NPC, and quest line hiding options
- GameTooltip styling without requiring ElvUI
- Optional unit-frame tooltip handling for ElvUI unit frames when ElvUI is loaded
- Separate restricted-instance handling that avoids reading or modifying secret tooltip values
- Keybind for temporarily showing full details
- `/htt` options command
- `/httdebug` debug snapshot command

## Instance Tooltip Safety

Retail WoW 12.0.x protects some unit tooltip values inside instances. Those values can be shown by Blizzard's UI, but addon code cannot safely read, parse, compare, or convert them once execution is tainted.

Because of that, HoverToolTip keeps instance world tooltips separate from the open-world styling path. In restricted instance tooltips it only performs safe visual styling, such as hiding chrome or status bars, and avoids text inspection for secret unit lines.

## Installation

1. Download or clone this repository.
2. Copy the `HoverToolTip` folder into:

   ```text
   World of Warcraft/_retail_/Interface/AddOns/
   ```

3. Restart the game or run `/reload`.
4. Enable `HoverToolTip` from the AddOns list.

If you also run ElvUI_MerathilisUI, disable its built-in NameHover module while testing this standalone version to avoid overlapping similar tooltip events.

## Commands

```text
/htt
/httdebug
/httdebug on
/httdebug off
/httdebug dump
/httdebug trace start
/httdebug trace dump
```

## Profiles And Presets

Open `/htt` and use the top tabs of the options window:

- **Setup** contains profiles, presets, and import/export.
- **General** contains enable, anchor, alpha, scale, backdrop, status bar, and instance-safe controls.
- **Text** contains font outline and size controls.
- **Lines** contains quest, player, and NPC line-hiding controls.

Profiles are selected per character. Import replaces only the active profile and fills missing settings from HoverToolTip defaults.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

HoverToolTip is free to use, share, and modify for personal, non-commercial use.

It may not be sold, repackage-sold, or otherwise commercially distributed without written permission.

See [LICENSE](LICENSE).
