# meld-macos

Meld sur macOS (Tahoe compris) : reproduire et corriger le bug d'affichage
de la fenêtre, et le distribuer via le cask Homebrew `meld-patched` du tap
[azman0101/homebrew-tap](https://github.com/azman0101/homebrew-tap).

## Le bug

Symptôme : au lancement, la fenêtre de Meld s'ouvre mal placée, avec la
barre de titre cachée sous la barre de menus et une partie de la fenêtre hors
de l'écran ; elle ne peut plus être attrapée pour la déplacer. C'est le ticket
upstream [meld#966](https://gitlab.gnome.org/GNOME/meld/-/work_items/966).

Cause, mesurée sur les runners GitHub macOS 15 et macOS 26 :

- Meld enregistre la taille de la fenêtre (GSettings
  `org.gnome.meld.window-state`, stockée dans
  `~/Library/Preferences/org.gnome.Meld.plist`) mais pas sa position.
- Au lancement, le backend quartz de GTK 3 place la fenêtre en (0, 0) et
  **ne la contraint pas à l'écran**. Si la taille enregistrée vient d'un écran
  plus grand (écran externe, résolution différente), la fenêtre déborde et sa
  barre de titre passe sous la barre de menus. Exemple mesuré sur macOS 26 :
  taille enregistrée 2400×1600 sur un écran 1024×768 → cadre 2452×1699 à y=-28.

Ce n'est **pas** propre à Tahoe : le même scénario échoue à l'identique sur
macOS 15. La barre de menus de Tahoe, plus haute (31 pt contre 25 pt), le rend
seulement plus visible.

Pistes écartées :

- [GTK #8233](https://gitlab.gnome.org/GNOME/gtk/-/work_items/8233) (flou en
  HiDPI sur Tahoe, corrigé par GTK !10038 et pas encore publié) : il vient
  d'une mauvaise détection de la version de macOS. Le diagnostic
  `diag/gdkver.m` montre que le GTK embarqué dans Meld 3.22.3+105 et 3.24.1
  (arm64) détecte correctement Tahoe (`gdk_quartz_osx_version() = 99`). Ces
  builds ne sont donc pas concernés.
- Le rendu en 1× sur Tahoe est identique à celui de Sequoia (captures
  `repro`). Le HiDPI (Retina) n'a pas pu être testé : l'écran virtuel des
  runners ne propose que le 1×.

À noter, hors périmètre : Meld 3.24.1 (DMG officiel GNOME) affiche les
espaces de la police de l'interface trop serrés (« Ln1,Col1 »), ce que ne
fait pas 3.22.3+105. Le cask part donc de 3.22.3+105.

## Le correctif

`patches/meld-3.22-window-placement.patch` et
`patches/meld-3.24-window-placement.patch` modifient `meld/windowstate.py` :
sur macOS, au premier affichage, la fenêtre est réduite si besoin à la zone
utile de l'écran (sous la barre de menus, hors Dock), décorations comprises,
puis centrée. La taille réduite est ensuite enregistrée normalement.

Résultats sur runners (`scripts/placement.sh`, 4 scénarios × macOS 15/26 ×
Meld 3.22.3/3.24.1) :

| scénario                         | d'origine | corrigé |
|----------------------------------|-----------|---------|
| premier lancement                | OK        | OK      |
| relance                          | OK        | OK      |
| taille enregistrée > écran       | **ÉCHEC** | OK      |
| petite taille enregistrée        | OK        | OK      |

## Contenu

| chemin                         | rôle                                                         |
|--------------------------------|--------------------------------------------------------------|
| `scripts/install.sh`           | installe un DMG de Meld dans /Applications                   |
| `scripts/repro.sh`             | diagnostic de version GTK + captures d'écran                 |
| `scripts/placement.sh`         | test du placement de fenêtre (4 scénarios)                   |
| `scripts/repack.sh`            | applique un patch au DMG officiel, signe ad hoc, refait le DMG |
| `scripts/test-cask.sh`         | installe le cask depuis un tap local et vérifie              |
| `scripts/release.sh`           | construit, teste et publie le DMG corrigé d'un tag           |
| `diag/gdkver.m`                | version de macOS vue par GTK                                 |
| `diag/winfo.swift`             | géométrie des fenêtres et zone utile de l'écran              |
| `patches/`                     | correctifs Meld                                              |
| `.github/workflows/ci.yml`     | CI sur runners macOS 15 et 26                                |

Le cask lui-même est dans
[azman0101/homebrew-tap](https://github.com/azman0101/homebrew-tap)
(`Casks/meld-patched.rb`) ; le job `cask` le récupère depuis ce dépôt.

Les jobs CI se déclenchent selon un marqueur dans le message de commit :
`[repro]`, `[placement]`, `[fix]`, `[cask]` (`workflow_dispatch` les lance
tous). Les jobs `placement` testent le Meld d'origine : leur échec sur le
scénario `large` est attendu et ne fait pas échouer le run. Seuls les
artefacts `fix-*` et `cask-*` contiennent un DMG ; `repro-*` et
`placement-*` ne contiennent que journaux et captures.

## Release

Pousser un tag `v<version de Meld>-fix<n>` publie le DMG corrigé en release
GitHub (job `release`, `scripts/release.sh`) après les 4 scénarios de
placement :

```bash
git tag v3.22.3+105-fix1 && git push origin v3.22.3+105-fix1
git tag v3.24.1-fix1 && git push origin v3.24.1-fix1
```

Reporter ensuite le sha256 affiché dans les notes de release dans le cask du
tap.

## Cask Homebrew

Oui, Homebrew peut pointer vers un dépôt GitHub personnel : un tap est un
simple dépôt Git.

- Avec un dépôt nommé `azman0101/homebrew-tap` :
  `brew trust azman0101/tap && brew install --cask azman0101/tap/meld-patched`
  (les versions récentes de Homebrew refusent de charger un tap tiers tant
  qu'il n'est pas approuvé avec `brew trust`)
- Avec n'importe quel autre nom de dépôt :
  `brew tap azman0101/tap https://github.com/azman0101/<dépôt>` puis la même
  commande.

Le cask télécharge le DMG repackagé depuis une release GitHub de ce dépôt
(tag `v3.22.3+105-fix1` pour la version `3.22.3,105,1`). Le DMG est
signé ad hoc seulement (pas de certificat Apple Developer ID), donc
Gatekeeper le refuse. Le cask retire l'attribut de quarantaine après
installation (`postflight_steps`), comme le ferait
`xattr -dr com.apple.quarantine`. Il installe aussi la commande `meld` via un
`command_wrapper`, car le lanceur de Meld refuse d'être appelé par un lien
symbolique. Il entre en conflit avec le cask officiel `meld` : désinstaller ce
dernier d'abord.

Le cask a été testé sur les runners macOS 15 et 26 (job `cask`) : `brew style`,
installation depuis un tap local, signature valide, quarantaine absente,
`meld --version`, puis les 4 scénarios de placement. Le job remplace l'URL de
la release et le sha256 par ceux du DMG construit localement.

## Suite

1. Mettre à jour le cask du tap automatiquement à la release (demande un
   jeton avec accès en écriture à azman0101/homebrew-tap).
2. Proposer le correctif upstream sur meld#966.

Historique : ce projet a démarré dans
[azman0101/sandbox#14](https://github.com/azman0101/sandbox/pull/14).
