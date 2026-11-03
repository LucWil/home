# Les Willys — l'app iPhone & iPad

La version native (Swift / SwiftUI) de l'artifact **Les Willys**, écrite d'après le
« dossier de portage iPhone & iPad ». Même esprit « porte du frigo » : fond émaillé,
un aimant de couleur par personne, petits mots manuscrits.

## Ce qui est déjà là

| Onglet | Contenu |
|---|---|
| **La famille** | Bannière avec la photo du jour, « Cette semaine », ce qui est nouveau depuis ta dernière visite, qui est passé, les petits mots (post-it), le mur des petites (photos + ❤️ 😄 🤩) |
| **Calendrier** | Mois du lundi au dimanche, bandes de vacances scolaires Belgique / Luxembourg et Fréjus, détail du jour, gardes, partage |
| **Voyages / Week-ends** | Idées proposées, réactions J'adore / J'en suis / Bof, triées par enthousiasme |
| **Cuisine** | « À manger cette semaine », le frais, le surgélateur tiroir par tiroir, les armoires, bouton **Mangé** (règle du boni) et **Jeté**, carnet de recettes, **mode Thermomix** plein écran, produits de saison |
| **Chez nous** | Récoltes pesées, heures au jardin, import de la sauvegarde de l'app web, changer d'aimant |
| **Budget & boni** | Boni du foyer, boni du trimestre, objectif de l'année avec barre de progression |

**Les cinq widgets** du dossier :

1. *À manger cette semaine* (moyen/grand) — avec un bouton **Mangé** directement dans le widget.
2. *Les petits mots* (petit) — le dernier mot, sur un post-it.
3. *Qui est où ce week-end* (moyen) — pastille Belgique / Luxembourg / Fréjus par foyer.
4. *Cette semaine* (grand) — les 7 prochains jours, le prochain voyage, le dernier mot.
5. *Le boni du foyer* (écran verrouillé) — jauge vers l'objectif.

Toucher un widget ouvre l'app sur le bon onglet (`willys://cuisine`, `willys://calendrier`, `willys://boni`…).

## Reprendre les données de l'app web

1. Dans Les Willys (web) : *Calendrier › La maison › Sauvegarde › Télécharger*, ou le bouton
   **Données** dans *Le coffre des Willys*. On obtient `les-willys-sauvegarde-aaaa-mm-jj.json`.
2. Dans l'app : *Chez nous › Reprendre une sauvegarde de l'app web*, et choisir le fichier.
3. L'app affiche le nombre d'éléments repris par collection et le boni par foyer, pour vérifier les totaux.

Calendrier, idées, mots, réactions, stock, boni, foyers, recettes et photos deviennent des données
natives. Tout le reste (jardin, récoltes, restos, entretien, papiers, IBAN…) est gardé intact
et pourra recevoir son écran plus tard. Reprendre deux fois le même fichier ne crée pas de doublons.
Les sauvegardes ne doivent jamais être ajoutées à ce dépôt (le `.gitignore` les exclut).

## Compiler sur le Mac

```sh
brew install xcodegen
cd LesWillys
xcodegen            # crée LesWillys.xcodeproj à partir de project.yml
open LesWillys.xcodeproj
```

Puis dans Xcode :

1. *Signing & Capabilities* : choisir ton équipe Apple Developer pour les deux cibles
   (`LesWillys` et `WillysWidgets`), ou remplir `DEVELOPMENT_TEAM` dans `project.yml`.
2. Vérifier que l'App Group `group.be.willys.app` et le conteneur iCloud `iCloud.be.willys.app`
   sont cochés (Xcode les crée sur le compte développeur au premier lancement).
3. Lancer sur ton iPhone. iOS 17 minimum (SwiftData et widgets interactifs).

> Ce code a été écrit sans Mac à portée de main : il n'a pas encore été compilé.
> Le premier `⌘B` fera probablement remonter quelques petites erreurs : demande à
> Claude Code sur le Mac de les corriger, il a tout le contexte dans ce dossier.

## Organisation du code

```
project.yml              projet XcodeGen (app + extension widgets)
Shared/                  partagé entre l'app et les widgets
  Family.swift           les 8 membres, les 4 foyers, types, saisons, vacances scolaires
  Models.swift           modèles SwiftData (compatibles iCloud) + outils de dates
  Store.swift            base partagée (App Group), règle du boni, bouton « Mangé » (AppIntent)
  Theme.swift            aimants, post-it, cartes « porte du frigo »
App/                     l'app
  LesWillysApp.swift     onglets et liens profonds
  Import/                reprise de la sauvegarde JSON de l'app web
  Views/                 un fichier par onglet + formulaires
Widgets/                 les cinq widgets
```

## Ce qui reste à faire (suite du plan)

- **Partage familial (semaine 4 du plan).** Aujourd'hui, la synchronisation iCloud passe par la base
  *privée* : les données suivent une même personne sur son iPhone et son iPad, mais ne sont pas
  encore partagées entre les huit membres. Pour partager, il faut une zone iCloud partagée
  (`CKShare`) : SwiftData ne le gère pas encore, il faudra passer la couche de données sur
  `NSPersistentCloudKitContainer` (Core Data) ou sur un petit serveur (Supabase, par exemple, si un
  membre est sous Android). Les modèles sont déjà prêts pour ça.
- **Lecture des tickets** par l'appareil photo (Vision, sur l'appareil).
- **Notifications** (« les yaourts sont à manger aujourd'hui », nouveau petit mot).
- **Menu « avec ce qu'on a »** via l'API de Claude, si on veut garder cette fonction.
- Écrans natifs pour l'entretien, les pièces, le matériel, les papiers, les restos et les IBAN
  (données déjà importées, pas encore affichées).
- Police manuscrite identique à l'app web : ajouter `GochiHand-Regular.ttf` (licence OFL) au
  projet et à `UIAppFonts` ; l'app l'utilise automatiquement si elle est présente.
- Réglage du lieu habituel de chaque foyer pour le widget « Qui est où » (Belgique par défaut).
