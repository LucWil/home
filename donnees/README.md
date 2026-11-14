# Données publiques de l'agenda du coin

`agenda.json` est lu par l'app iPhone (Près de chez nous). Il contient seulement des informations publiques
(activités, marchés, bons plans, pharmacies de garde) recopiées de la collection « agenda » de l'app web
par la recherche automatique : jamais de données de la famille (ni « ça me tente », ni calendrier).

## voyages.json

Les bonnes affaires voyage (copiées de « Veille voyages » chaque jour par une tâche planifiée) :
`{"maj", "offres": [{id, type ("releve"|"pepite"|"neige"), titre, detail, format, depart, retour, prix, personnes, prixPers,
baisse, depuisDebut, plusBas, etoiles, note, temp, pluie, lien, photo, depuis, pourquoi, releve, score}]}`.
Que des offres publiques : jamais de champ by, at ni rien de la famille.
