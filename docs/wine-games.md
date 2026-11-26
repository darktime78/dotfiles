# Old Windows games with Wine (in Docker)

`wine-game` installs Windows games from a CD image (`.iso`) or an installer (`.exe`,
e.g. from GOG) into the Docker image `my/wine`. Nothing is installed on your system:
each game gets its own folder `~/Games/NAME` with its own Wine prefix (its "Windows"),
the unpacked discs and the settings. Delete the folder and the game is gone.

The disc goes into a virtual CD drive **D:** with the disc's real name (label), so
games that look for "their" CD find it.

## Once

```sh
docker-images-update wine        # builds archlinux -> my/base -> my/wine (~10 min)
```

## Example: Heroes of Might and Magic III

```sh
wine-game install homm3 ~/Downloads/HoMM3.iso
```

1. The disc is unpacked and put into drive D:, then its setup starts (from
   `autorun.inf`, as on Windows).
2. Install to the folder it suggests on C:. Choose the **full** install if it asks,
   so the game needs the disc less often.
3. At the end it asks which program starts the game: pick `Heroes3.exe` (the biggest
   one is listed first).

Play: `wine-game run homm3`, or **homm3 (Wine)** in the launcher (`$mod+d`). The window
opens on workspace 4.

The game runs at 800x600. If the screen goes black or the picture is wrong when it
switches to full screen, play it in a window of that size:

```sh
wine-game set homm3 desktop 800x600      # back to full screen: desktop off
```

Mods and patches are Windows installers too; run them inside the game's prefix and
install them into the game folder (`C:\...\3DO\Heroes 3` or wherever setup put it):

```sh
wine-game exe homm3 ~/Downloads/HoMM3_HD_Latest.exe   # HD mod: big resolutions, windowed mode
wine-game exe homm3 ~/Downloads/HotA_setup.exe        # Horn of the Abyss
```

If a mod has its own launcher, make that the program `run` starts (with the folder
your setup created):

```sh
wine-game set homm3 exe 'C:\Program Files\3DO\Heroes 3\HD_Launcher.exe'
```

## Example: Civilization III

```sh
wine-game install civ3 ~/Downloads/Civ3.iso
# then the expansion, from its own disc, into the same prefix:
wine-game disc civ3 ~/Downloads/Civ3_Conquests.iso
wine-game exe civ3 'D:\setup.exe'
wine-game set civ3 exe 'C:\Program Files\Infogrames Interactive\Civilization III\Conquests\Civ3Conquests.exe'
```

Use the folder names your setup really created: `wine-game shell civ3` and then
`ls "$WINEPREFIX/drive_c/Program Files"` shows them. Paths are not case sensitive, as on
Windows. Civ3 runs at 1024x768; `wine-game set civ3 desktop 1024x768` if full screen
gives trouble. Install the last official patch with `wine-game exe civ3 patch.exe`.

## Games on several discs

When setup asks for disc 2, put it in from a second terminal and press OK:

```sh
wine-game disc NAME ~/Downloads/game_disc2.iso
```

Same for games that want "the play disc" later. The discs stay unpacked in
`~/Games/NAME/discs/`, so switching back is instant.

## Commands

| Command | Does |
|---|---|
| `wine-game install NAME FILE` | new game from `game.iso` or `setup.exe` |
| `wine-game run NAME` | play |
| `wine-game disc NAME FILE.iso` | other disc in drive D: (also while the game runs) |
| `wine-game exe NAME FILE.exe` | run a patch, mod installer, map editor ... in that prefix (also `'C:\...'` / `'D:\...'`) |
| `wine-game set NAME exe 'C:\...\game.exe'` | the program `run` starts |
| `wine-game set NAME desktop 1024x768` / `off` | play in a window of that size / full screen |
| `wine-game set NAME args "-nosound"` | arguments for the game |
| `wine-game set NAME lang ru_RU.UTF-8` | language / codepage, for Russian games (garbled text) |
| `wine-game winecfg NAME` | Wine settings: Windows version, sound, drives |
| `wine-game tricks NAME VERB...` | winetricks, e.g. `corefonts`, `directplay` (old multiplayer) |
| `wine-game shell NAME` | bash inside the container, `$WINEPREFIX` = the prefix |
| `wine-game list` / `remove NAME` | your games / delete one (saves too!) |

Russian edition? Start the setup in Russian too, so its text isn't garbled:
`LANG=ru_RU.UTF-8 wine-game install homm3 Heroes3_rus.iso`, then
`wine-game set homm3 lang ru_RU.UTF-8`.

## Saves and backups

Everything is in `~/Games/NAME`: saves usually inside the game folder in
`prefix/drive_c/...` (Heroes III: `games/`, Civ III: `Saves/`). Copying that folder to
another machine with these dotfiles moves the whole game.

## When it doesn't work

* **"Please insert the CD" although it's in D:**: many retail discs from about 2000 to
  2008 use SafeDisc or SecuROM copy protection (the original Civilization III CD, for
  example). It needs a Windows kernel driver, so it doesn't run on Wine, nor on
  Windows 10 and 11. The GOG or Steam release has no disc check: install its
  `setup.exe` with `wine-game install`, or play the Steam version in the Steam
  container (Proton).
* **`.bin/.cue`, `.mdf`, `.nrg` images**: convert them to `.iso` first:
  `bchunk game.bin game.cue game`, `mdf2iso game.mdf game.iso`, `nrg2iso game.nrg game.iso`.
  CD music tracks (audio CDs) are not part of an `.iso`; the game runs without them.
* **Black screen, wrong colours, mouse off target**: `wine-game set NAME desktop WxH`
  with the game's resolution.
* **No sound**: `wine-game winecfg NAME`, tab Audio, test sound. The container uses your
  PipeWire / PulseAudio.
* **Setup needs an old Windows**: `wine-game winecfg NAME`, tab Applications, Windows
  version (Windows XP / 7), then `wine-game exe NAME 'D:\setup.exe'` again.
* **Details**: `wine-game shell NAME`, then run the game by hand with logs:
  `WINEDEBUG=err+all,fixme-all wine-run 'C:\...\game.exe'`.
