# Crédits et licences audio — Alchi-Gun

Provenance et licence de chaque asset audio tiers embarqué dans `assets/audio/`.
Le jeu étant destiné à une distribution commerciale, seules des licences **CC0** ou
explicitement libres de droits sans clause share-alike sont acceptées ici.

Copies de référence des sources non traitées :
`~/.claude/tiktok-pipeline-assets/music/` (musique) et `~/.claude/sound-design-assets/sfx/` (SFX).

---

## Musique

| Fichier projet | Source | Auteur | Licence | URL |
|---|---|---|---|---|
| `music/cave.ogg` | 8-bit — Truth | HydroGene | CC0 | https://opengameart.org/content/8-bit-truth |
| `music/crypt.ogg` | 8-bit — Perilous Dungeon | HydroGene | CC0 | https://opengameart.org/content/8-bit-perilous-dungeon |
| `music/alchemy.ogg` | 8-bit — Infinite Darkness | HydroGene | CC0 | https://opengameart.org/content/8-bit-infinite-darkness |

CC0 : aucune attribution obligatoire. Elle est conservée ici par traçabilité, pas par contrainte.

Traitement appliqué aux trois pistes (2026-09-04) : rognage du silence de tête et de queue,
rampe équipuissance de 3 ms sur les deux bords pour supprimer le clic de bouclage,
réencodage Vorbis `-q:a 4` à 44,1 kHz. Aucune modification musicale.
Le bouclage est activé à l'exécution par `AudioManager._load_music()`, pas à l'import.

`music/dungeon.ogg` a été supprimé lors de ce passage : remplacé par la palette
`cave` / `crypt` / `alchemy`, plus aucune référence dans le code.

## Effets sonores dérivés de sources tierces

Ces cinq fichiers sont des **mixages multi-couches** construits à partir des sources ci-dessous
(filtrage, transposition, découpe, fondu, normalisation crête). Ce sont des dérivés spécifiques
au projet, pas des copies des sources.

| Fichier projet | Couches sources | Auteur | Licence | URL |
|---|---|---|---|---|
| `sfx/impact_water.ogg` | `splash_10.ogg` + corps grave de l'ancien `impact_water` | rubberduck | CC0 | https://opengameart.org/content/40-cc0-water-splash-slime-sfx |
| `sfx/impact_mixture.ogg` | `slime_16.ogg`, `bubble_02.ogg` + corps grave transposé | rubberduck | CC0 | https://opengameart.org/content/40-cc0-water-splash-slime-sfx |
| `sfx/craft_success.ogg` | `bottle-glass-uncork-01.wav`, `vial-glass-small-drop-01.wav` | Vehicle (Jan Schupke) | CC0 | https://opengameart.org/content/fantasy-accessory-sfx-library |
| `sfx/craft_success.ogg` | `bubble_01.ogg` | rubberduck | CC0 | https://opengameart.org/content/40-cc0-water-splash-slime-sfx |
| `sfx/station_open.ogg` | `keyhole-lockbox-unlock-01.wav`, `vial-glass-square-empty-open-02.wav` | Vehicle (Jan Schupke) | CC0 | https://opengameart.org/content/fantasy-accessory-sfx-library |
| `sfx/station_open.ogg` | `small_metal_clasp.mp3` | sinny | CC0 | https://opengameart.org/content/small-metal-clasp-open-close-switching |
| `sfx/pickup_ingredient.ogg` | `vial-glass-small-drop-01.wav` | Vehicle (Jan Schupke) | CC0 | https://opengameart.org/content/fantasy-accessory-sfx-library |

## Assets audio antérieurs au 2026-09-04

`music/boss.ogg`, `music/hub.ogg` et l'ensemble des autres fichiers de `sfx/` datent des
commits `3ab468a`, `0840f87`, `648954a`, `b6dd31a` et `a1a7469`. Aucune source externe ni
licence n'a été enregistrée pour eux à l'époque et leur provenance n'a pas pu être
reconstituée depuis (aucune métadonnée dans les fichiers, aucun message de commit exploitable).

**À confirmer par l'auteur du projet avant toute distribution commerciale.** S'ils ont été
synthétisés dans le projet, aucune licence tierce ne s'applique et cette section peut être
close ; s'ils proviennent d'une source externe, sa licence doit être ajoutée ci-dessus.
