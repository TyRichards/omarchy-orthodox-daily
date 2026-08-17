# Orthodox Daily

![Orthodox Daily preview](preview.png)

An Orthodox Christian daily companion for the Omarchy bar, with fasting guidance, prayer tracking, Scripture readings, feasts, and lives of the saints.

## Install

```sh
omarchy plugin add https://github.com/TyRichards/omarchy-orthodox-daily.git --enable
```

The widget defaults to the right side of the bar. Move it with Omarchy's bar controls if desired.

## Features

- Daily fasting rule and major-fast or Pascha banners
- Sunday–Saturday prayer history plus morning and evening prayer checks
- Gospel-first Scripture readings with expandable full text
- Saints and commemorations with expandable lives and matching OCA icons when available
- Direct links to the day's Orthocal and OCA pages
- Local cache for offline fallback

## Controls

- **Left click:** Open or close the daily panel.
- **Middle click:** Refresh daily data.
- **Right click:** Open today's OCA readings.
- **R while open:** Refresh daily data.
- **Click a reading or life:** Expand its full text.
- **Click a weekly prayer circle:** Toggle that day's completion.

## Data and dependencies

- **Calendar source:** [Orthocal.info](https://orthocal.info/), using the Slavic/OCA tradition, Gregorian (New) Calendar, and LXX2012 + World English Bible translation.
- **Official links and saint icons:** Daily reading and saint-life pages on [OCA.org](https://www.oca.org/). Matching OCA icons are downloaded automatically when available.
- **Runtime dependencies:** Omarchy Quattro, `curl`, and Python 3. The Python helper uses only the standard library.
- **Network access:** The plugin requests daily data from Orthocal and retrieves matching saint images from OCA.org. It sends no analytics and uses no AI services.
- **Cache:** Daily data is stored in `~/.local/state/omarchy/plugins/io.github.tyrichards.orthodox-daily/daily.json`. OCA icon files and match manifests are stored beneath `~/.local/state/omarchy/plugins/io.github.tyrichards.orthodox-daily/saint-images/`.
- **Prayer history:** Morning, evening, and weekly completion state is stored locally in `~/.local/state/omarchy/plugins/io.github.tyrichards.orthodox-daily/checklist.json`.

Fasting guidance reflects the typikon-strict data supplied by Orthocal; follow your priest's pastoral guidance.

## Remove

```sh
omarchy plugin remove io.github.tyrichards.orthodox-daily --yes
```

To remove local cache and prayer history as well:

```sh
rm -rf ~/.local/state/omarchy/plugins/io.github.tyrichards.orthodox-daily
```

## License

[MIT](LICENSE)
