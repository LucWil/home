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

## Loisirs : restaurants, hôtels et budget des sorties

Le cinquième onglet (les week-ends ont rejoint Voyages, avec un choix en haut) :

- **Restaurants** : fiche (adresse, carte Plans, téléphone, site ou réservation, menu avec les prix,
  avis clients), complétée chaque soir par Claude dans l'app web, ou à la main. **« On y est allés »** :
  date, addition et prix par personne, qui était là, photos du plat et de l'ambiance, impression de
  chacun ; puis **« Laisser un avis »** copie le texte et ouvre Google ou Tripadvisor.
- **Hôtels** : dates et nuits, prix, numéro et lien de réservation, options, **annulation gratuite**
  avec rappel au calendrier, recherche Booking avec les dates ; après le séjour, **note finale**
  (moyenne de la famille), prix payé, photos de la chambre et de l'ambiance.
- **Le budget** (visible seulement par le foyer) : total de l'année, restaurants et hôtels hors
  vacances, moyenne par mois, et une partie **Vacances** voyage par voyage (une sortie datée pendant un
  voyage ou un séjour à Fréjus du calendrier y est rangée automatiquement).

Code : `Shared/Loisirs.swift` (modèles et synchronisation iCloud) et `App/Views/LoisirsView.swift`.
L'import d'une sauvegarde de l'app web reprend aussi les restaurants, les sorties, les hôtels et leurs photos.

## La vie de la maison : qui fait quoi, qui est là

- **« Ça bouge à la maison »** (accueil) : le fil de ce que fait chacun — « Loulou a rangé
  3 articles dans les armoires », « Julien propose un week-end : Ardennes ». Les gestes répétés
  d'une même personne en dix minutes sont regroupés sur une seule ligne. Toucher une ligne ouvre l'onglet.
- **« En ce moment »** : un point vert sur l'aimant de ceux qui ont l'app ouverte, et ce qu'ils
  regardent (« Manhattan regarde le calendrier »). Sur chaque onglet, un bandeau montre qui
  regarde la même chose que toi.
- **Notifications** : app fermée, une notification par geste (regroupée par onglet) ; app
  ouverte, une bannière glisse en haut de l'écran. Réglage dans *Chez nous › Partage familial*.

Code : `Shared/Activite.swift` (fil et présence), `App/Synchro/Alertes.swift` (bannière et notifications).

## Le look et les règles de design d'Apple

- **Polices de l'app web** : Bricolage Grotesque (titres), Figtree (texte) et Gochi Hand
  (écriture à la main), embarquées dans `Shared/Fonts` (licence libre OFL, texte joint).
- **Taille du texte** : tout suit le réglage *Taille du texte* d'iOS (Dynamic Type), y compris
  les polices de la famille.
- **Mode sombre**, couleur d'accent et fond d'écran au lancement définis dans le catalogue de couleurs.
- **Retours haptiques** discrets : l'aimant qui se colle quand on choisit quelqu'un, une
  confirmation quand on touche « Mangé » ou qu'on laisse un mot, une alerte légère quand on jette.
- **Animations** : post-it qui se collent, articles qui glissent hors du stock, compteur du boni
  qui défile, étapes Thermomix qui s'enchaînent. Toutes se coupent si *Réduire les animations*
  est activé dans Réglages › Accessibilité.
- **Accessibilité** : VoiceOver lit les aimants par prénom, les post-it (« Mot de Loulou : … »),
  les jours du calendrier et les réactions ; zones à toucher d'au moins 44 points.
- Écrans vides au format Apple (`ContentUnavailableView`), confirmation avant les actions
  importantes, actions de partage dans les menus.

## Le partage entre les huit membres (iCloud, sans service tiers)

Toute la famille a un iPhone : les données sont partagées par **iCloud**, gratuitement, sans
serveur ni abonnement. Elles vivent dans une « maison commune » (une zone iCloud nommée *Willys*)
qui appartient à Chouchou et qu'il partage avec les sept autres.

1. **Chouchou** ouvre l'app, choisit son aimant, importe la sauvegarde de l'app web
   (*Chez nous › Reprendre une sauvegarde*), puis touche **Chez nous › Inviter la famille**.
   La fenêtre d'Apple permet d'envoyer le lien par Messages, WhatsApp ou e-mail.
2. **Chaque membre** installe l'app, choisit son aimant et touche le lien reçu. C'est tout :
   l'app se remplit. Son iPad voit aussi la maison commune, sans nouvelle invitation.
3. Ensuite, tout changement part tout seul vers les autres (quelques secondes en général).
   Un « Mangé » touché dans un widget part à la prochaine ouverture de l'app.

En coulisses : chaque appareil garde une copie locale (SwiftData) lue par l'app et les widgets ;
`App/Synchro/SynchroFamille.swift` l'échange avec iCloud grâce à CKSyncEngine. Si deux personnes
changent la même chose au même moment, la dernière modification gagne. Les IBAN ne quittent jamais
l'appareil de celui qui les a importés.

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
2. Dans le *CloudKit Console*, rien à créer à la main : les types d'enregistrements se créent au
   premier envoi en développement. Avant de distribuer l'app à la famille, cliquer sur
   **Deploy Schema Changes** pour passer le schéma en production.
3. Vérifier que l'App Group `group.be.willys.app` et le conteneur iCloud `iCloud.be.willys.app`
   sont cochés (Xcode les crée sur le compte développeur au premier lancement).
4. Lancer sur ton iPhone. iOS 17 minimum (SwiftData et widgets interactifs).

> Ce code a été écrit sans Mac à portée de main : il n'a pas encore été compilé.
> Le premier `⌘B` fera probablement remonter quelques petites erreurs : demande à
> Claude Code sur le Mac de les corriger, il a tout le contexte dans ce dossier.

## Organisation du code

```
project.yml              projet XcodeGen (app + extension widgets)
Shared/                  partagé entre l'app et les widgets
  Family.swift           les 8 membres, les 4 foyers, types, saisons, vacances scolaires
  Models.swift           modèles SwiftData (compatibles iCloud) + outils de dates
  Store.swift            base locale (App Group), règle du boni, bouton « Mangé » (AppIntent)
  Enregistrements.swift  correspondance objets ↔ enregistrements iCloud, file d'envoi
  Theme.swift            aimants, post-it, cartes « porte du frigo »
App/                     l'app
  LesWillysApp.swift     onglets et liens profonds
  Import/                reprise de la sauvegarde JSON de l'app web
  Synchro/               la maison commune iCloud (CKSyncEngine, invitation, acceptation)
  Views/                 un fichier par onglet + formulaires
Widgets/                 les cinq widgets
```

## Ce qui reste à faire (suite du plan)

- **Lecture des tickets** par l'appareil photo (Vision, sur l'appareil).
- **Notifications** (« les yaourts sont à manger aujourd'hui », nouveau petit mot).
- **Menu « avec ce qu'on a »** via l'API de Claude, si on veut garder cette fonction.
- Écrans natifs pour l'entretien, les pièces, le matériel, les papiers, les restos et les IBAN
  (données déjà importées, pas encore affichées).
- **L'icône de l'app** : le dossier `App/Assets.xcassets/AppIcon.appiconset` attend une image
  1024 × 1024, idéalement préparée dans *Icon Composer* (Apple, gratuit).
- Réglage du lieu habituel de chaque foyer pour le widget « Qui est où » (Belgique par défaut).
