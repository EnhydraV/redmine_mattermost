# HANDOFF

Journal de reprise du projet, pour Vincent et pour les sessions Claude suivantes. A relire en début de session, à compléter en fin de session.

## Objectif

1. Étape 1 : transformer ce plugin multi-messageries en plugin Redmine dédié à Mattermost, avec un compte bot et l'API REST (retrait de Slack, Discord et Rocket.Chat, format de message natif Mattermost), et publier au nom de l'utilisateur qui agit dans Redmine.
2. Étape 2 : l'enrichir avec des fonctions propres à Mattermost (voir "Pistes").

## Décisions

Validées par Vincent (2026-11-03) :

- Versions cibles : Redmine 6.0 / 6.1 / 7.0, Ruby 3.1 à 4.0 (matrice de l'ancienne CI). Le code doit rester compatible Ruby 3.1.
- Identifiant du plugin : `redmine_mattermost` (module `RedmineMattermost`).
- Connexion par compte bot et API REST v4, dès l'étape 1.
- Serveur Mattermost minimal : 12.0. Mattermost de Vincent : auto-hébergé, Vincent en est l'admin.
- Publier au nom de l'utilisateur qui agit (pour qu'il ne soit pas notifié de ses propres actions) : par le relais du plugin Mattermost `com.cubedesigners.redmine` (dépôt `EnhydraV/mattermost-plugin-redmine`, qui porte aussi l'action "Créer un ticket Redmine"). Le relais a d'abord été écrit dans le sous-dossier `mattermost-plugin/` de ce dépôt (commit `0c6716b`), puis fusionné dans ce plugin le 2026-11-03 : un seul plugin Mattermost pour Redmine.
- Aucune CI pour ce dépôt : les tests Redmine se lancent en local. `Jenkinsfile` et `old_dot_github/` supprimés. Le dépôt du plugin Mattermost garde sa propre CI GitHub (release-please, bundle attaché aux releases).

Prises pendant l'implémentation (révisables) :

- Le webhook entrant, l'icône et le nom d'expéditeur disparaissent : l'identité est celle du bot, ou celle de l'utilisateur via le relais.
- URL du serveur, jeton, vérification SSL et "publier au nom de l'utilisateur" : réglages globaux uniquement. Équipe, canaux, mentions et options : surchargeables par projet.
- Jeton lisible dans la variable d'environnement `REDMINE_MATTERMOST_BOT_TOKEN`, prioritaire sur le champ de l'administration (qui le stocke en clair dans la table `settings`).
- Correspondance utilisateurs : nom d'utilisateur Mattermost = login Redmine ; le relais tente ensuite l'email (désactivable dans ses réglages).
- L'auteur de l'action est retiré des mentions du message.
- Les 7 langues sont conservées.
- Migration 002 : reprise des réglages de `redmine_messenger` / `redmine_messenger_so`, hors URL de webhook. L'ancienne table reste en place, le README donne le SQL de nettoyage.
- Seuls les champs personnalisés visibles par tous sont publiés.
- Version `2.0.0` pour le plugin Redmine. Le plugin Mattermost suit son propre semver.

## Origine du code

- Chaîne de forks : redmine_slack / redmine_mattermost / redmine_rocketchat -> `alphanodes/redmine_messenger` -> `smartorigin/redmine_messenger_so` (Smart/Origin) -> ce dépôt.
- Remote `origin` : https://github.com/EnhydraV/redmine_mattermost (hébergé sur GitHub : aucune référence de ticket Redmine ni temps passé dans les commits).
- Point de départ : commit `7bb115d` "version 1.1.2" (2026-09-16), dernier commit amont de Smart/Origin.
- Licence MIT.

## Déploiement (Redmine Cubedesigners)

- L'image Redmine de prod est construite par le dépôt `docker-images` (dossier `redmine/`, CI Forgejo) : plugins clonés depuis `redmine/plugins.list` (branche par défaut, `--depth 1`), `REDMINE_PLUGINS_MIGRATE: 1` dans le compose, donc les migrations des plugins tournent à chaque démarrage.
- La prod utilise `redmine_messenger` d'AlphaNodes (webhook entrant), pas le fork Smart/Origin. Le 2026-11-03, le worktree de `docker-images` remplace cette ligne par `redmine_mattermost` (modification de Vincent, non commitée à ce moment-là).
- L'ancien plugin sort de l'image sans sa migration de désinstallation : la table `messenger_settings` reste, la migration 002 la reprend au démarrage.
- Prod lue le 2026-11-03 (hotfuzz, `root@hotfuzz.cubedesigners.com`, conteneur `redmine-mariadb`, lecture seule) : 86 lignes dans `messenger_settings` (migrations AlphaNodes 1 à 4), aucun webhook propre à un projet, salons tous au format accepté, options toutes à 0 (hérité). Global `plugin_redmine_messenger` : webhook sur `mm.cubedesigners.com`, salon par défaut `redmine-test`, mentions auto, observateurs, descriptions.
- Piège trouvé en prod : un `plugin_redmine_mattermost` du 2016-10-14, laissé par l'ancien plugin altsol (webhook `slack.cubedesigners.com`, sérialisé en `ActionController::Parameters`). La migration 002 sautait l'import global en le voyant. Corrigée : un réglage sans clé `mattermost_team` n'est pas de ce plugin et est remplacé (import, sinon défauts) ; les `ActionController::Parameters` sont lus par `to_unsafe_h` ; l'URL du serveur est déduite du webhook (`.../hooks/...`). 6 tests (`test/unit/import_messenger_settings_test.rb`, schéma AlphaNodes).
- Après déploiement : l'équipe reste à saisir ; le bot doit pouvoir publier dans les ~60 salons (droit "publier dans tous les canaux publics", et membre des canaux privés).
- Mise en service le 2026-11-04 (Redmine sur hotfuzz, Mattermost 12.0.1 Team Edition sur gremlins, conteneur `mattermost`, équipe unique `cubedesigners`) :
  - le compte Mattermost `redmine` (propriétaire du webhook de l'ancien plugin, 51 819 posts) converti en bot (`mmctl --local user convert redmine --bot`), rôles `system_user system_post_all_public` posés par `PUT /api/v4/users/{id}/roles` sur la socket locale (`/proc/<pid>/root/var/tmp/mattermost_local.socket`), `mmctl permissions role assign` étant réservé à l'édition Enterprise ; ajouté aux canaux privés `board` et `compta` (accord de Vincent) ;
  - jeton du bot généré par `mmctl --local token generate`, posé dans le bloc `docker-images/redmine` de `/docker/redmine/.env` (fichier généré par `bw-env.sh`, sauvegarde `.env.avant-mattermost`), conteneur recréé ;
  - Redmine : équipe `cubedesigners`, "Publier au nom de l'utilisateur" activé ; plugin Mattermost déjà réglé par Vincent (`redmineurl`, `relayusernames=redmine`, `defaulttrackerid=2`) ;
  - vérifié par le client du plugin : relais 0.1.0+3547d66 joignable, 64 canaux sur 69 trouvés ; introuvables : `ipglobal`, `kadreo`, `odile` (archivés), `mondelez`, `vsu-veryspeciaunit` (inexistants).
  - Les 5 canaux introuvables passés à `-` (projets ip-global, kadreo, odile-front, mondelez, stop-the-robots), à la demande de Vincent : 64 canaux sur 64 trouvés.
  - Reste à Vincent : renvoyer le jeton dans la note Bitwarden (bw-sync sur hotfuzz), sinon la prochaine régénération du `.env` l'efface ; tester un vrai ticket.
- Aucun serveur Mattermost ni plugin Mattermost dans `docker-images` : le plugin `com.cubedesigners.redmine` s'installe à la main sur le serveur Mattermost (archive des releases GitHub de `EnhydraV/mattermost-plugin-redmine`, ou `make dist`).
- Le jeton du bot n'est pas encore câblé : à ajouter dans `redmine/docker-compose.yml` (`REDMINE_MATTERMOST_BOT_TOKEN`), `redmine/.env.example` et la note Bitwarden `docker-images/redmine`.

## Architecture (2.0.0)

### Plugin Redmine

| Fichier | Rôle |
|---|---|
| `init.rb` | Enregistrement du plugin, permission `manage_mattermost`, réglages globaux, chargement des hooks |
| `lib/redmine_mattermost.rb` | Version, `RELAY_PLUGIN_ID`, `configured?`, `server_url`, `bot_token`, `actor_for`, `with_default_language`, `safely`, `setup` (patchs `Issue`, `Project`, `WikiContent`) |
| `lib/redmine_mattermost/project_settings.rb` | Résolution projet -> parents -> global, sans état partagé ; liste des canaux |
| `lib/redmine_mattermost/formatter.rb` | Markdown Mattermost : échappement, liens, gras, champs, URL absolues (via `Mailer.default_url_options`) |
| `lib/redmine_mattermost/journal_field.rb` | `JournalDetail` -> champ d'attachment |
| `lib/redmine_mattermost/issue_notification.rb` | Messages de création et de mise à jour de ticket (filtres, mentions, messages directs, lien de révision) |
| `lib/redmine_mattermost/wiki_notification.rb` | Messages de création et de modification de page wiki |
| `lib/redmine_mattermost/notifier.rb` | Calcule les destinations et met un `MattermostDeliverJob` en file pour chacune, avec l'identité de l'auteur si le relais est activé |
| `lib/redmine_mattermost/client.rb` | Client API v4 (Bearer) : canal par équipe et nom, canal direct, `POST /posts`, cache des identifiants (1 h) ; `relay_post` / `relay_status` vers le plugin relais |
| `lib/redmine_mattermost/hooks/model_hook.rb` | `after_plugins_loaded` ; mot-clé de commit : pose `issue.mattermost_changeset` |
| `lib/redmine_mattermost/patches/*` | Callbacks `after_*_commit` sur `Issue` et `WikiContent`, `has_one :mattermost_setting` sur `Project` |
| `app/jobs/mattermost_deliver_job.rb` | Avec auteur : relais, puis repli sur le bot si le relais refuse ; sans auteur : bot. Relance 2 fois sur erreur réseau, 429 et 5xx |
| `app/models/mattermost_setting.rb` | Réglages par projet, validations des noms d'équipe et de canaux |
| `app/controllers/mattermost_settings_controller.rb`, `app/views/*` | Onglet projet et page de configuration globale |
| `db/migrate/001`, `002` | Table `mattermost_settings` ; import depuis l'ancien plugin |

Destinations : `{ 'team' => ..., 'channel' => ... }` pour un canal, `{ 'username' => ... }` pour un message direct. Auteur transmis au relais : `{ 'username' => login, 'email' => mail }`.

Modèle de réglages : champs texte vides = hérités ; options au niveau projet `0` = hérité, `1` = désactivé, `2` = activé ; canal `-` = aucun envoi.

### Relais (plugin Mattermost `com.cubedesigners.redmine`)

- Dépôt `EnhydraV/mattermost-plugin-redmine` (Go + webapp React, `min_server_version` 12.0.0), qui porte aussi l'action "Créer un ticket Redmine" et la commande `/redmine link|unlink|status` (lien canal -> projet en KV). Relais ajouté sur la branche `feat/relais-notifications` (`server/relay.go`) ; son HANDOFF et son README le décrivent.
- `POST /plugins/com.cubedesigners.redmine/api/v1/posts` : `{ target, actor, post }`. `GET .../api/v1/status` : identifiant et version.
- Authentification : la requête porte le jeton du bot Redmine ; le serveur Mattermost la valide et transmet `Mattermost-User-Id`, que le plugin compare au réglage "Relais : compte bot de Redmine" (`RelayUsernames`, vide par défaut = relais désactivé).
- Choix de l'auteur : l'utilisateur (par login, puis email si `RelayMatchByEmail`) s'il a `create_post` sur le canal, sinon le bot s'il a ce droit, sinon 403. Message direct : canal direct utilisateur -> destinataire.
- API plugin `server/public` v0.4.3 (Mattermost 12.0.0), chaîne Go 1.26.7 imposée par le `Makefile` : en Go 1.27, grpc 1.81 ne compile pas (`golang.org/x/net/http2` exclut son ancien serveur, `//go:build !(go1.27 && !http2legacy)`).

Vérifié dans les sources de Mattermost 12.0.0 : un plugin peut publier avec n'importe quel `UserId` (`PluginAPI.CreatePost`, "trusted server surface") ; l'auteur d'un post n'est pas notifié (`notification.go`, sauf `from_webhook`) ; `override_username` n'est réinjecté que pour les webhooks entrants, donc inutilisable par un bot via l'API REST ; un post créé par plugin ne passe pas par `MarkChannelsAsViewed`.

## Tests et outillage

- Redmine de test : `$SUPERCLAUDE_SCRATCH/redmine-env/redmine-7.0.1` (SQLite, gems dans `vendor/bundle`, lien symbolique `plugins/redmine_mattermost` -> projet, base de test migrée). Commande : `RAILS_ENV=test bundle exec rake redmine:plugins:test NAME=redmine_mattermost RUBYOPT='-W0'` depuis ce dossier.
- Résultat au 2026-11-03 : 68 tests, 239 assertions, 0 échec (Redmine 7.0.1, Ruby 3.3.8).
- Redmine force l'adaptateur ActiveJob `:inline` en test, que `ActiveJob::TestHelper` respecte depuis Rails 7.2 : `RedmineMattermost::TestHelper` surcharge `queue_adapter_for_test`.
- Relais : 13 tests Go (`plugintest.API`) dans `mattermost-plugin-redmine` (`server/relay_test.go`), golangci-lint du projet propre.
- RuboCop (bundle de Redmine, sans `rubocop-minitest` qui n'y est pas) : seules restent 2 alertes `Layout/EndOfLine` sur `test/unit/issue_test.rb` et `project_test.rb`, dues au CRLF du checkout Windows. Config temporaire : `.rubocop.yml` débarrassé de ses CR et des cops Minitest.
- slim-lint : pas lancé (gem absente du bundle de Redmine).
- Semgrep (`p/ruby`, `p/security-audit`, `p/golang`) : un seul signalement, `VERIFY_NONE` dans `client.rb`, assumé (option "Vérifier SSL" décochable par l'admin, cochée par défaut).
- Données de test : prénoms Charlie, Juliette, Oscar, Roméo, Victor.

## Reste à faire (étape 1)

- Merger la branche `feat/relais-notifications` de `mattermost-plugin-redmine`, publier sa release et l'installer avant de cocher "Publier au nom de l'utilisateur".
- Tester contre le vrai serveur Mattermost de Vincent : bot seul (canal public, privé, message direct), puis relais (post au nom de l'utilisateur, repli sur le bot, message direct).
- Vérifier en réel si le canal apparaît non lu pour l'auteur d'un post créé par le relais.
- Nettoyer les reliquats : `package.json`, `.stylelintrc.json`, `assets/*/.eslintignore`, `.stylelintignore`.
- Bouton "Tester la connexion" dans la configuration globale (`/users/me`, et `relay_status` si le relais est activé).
- Lancer slim-lint et les cops Minitest.

## Silence (2.1.0, 2026-11-04)

- Réglage global `ignored_attributes` (liste à choix multiples dans les options des tickets) : clés `done_ratio`, `cf_<id>`, `attachment`, `relation`... (`RedmineMattermost::IgnoredAttributes`). Mise à jour sans note ni révision dont tous les détails sont ignorés : rien n'est publié ; sinon les détails ignorés sont retirés du message (la description ignorée n'est plus envoyée en texte). Cas visé par Vincent : le champ personnalisé "Sessions Claude Code" rempli par le MCP Redmine.
- Mot-clé de commit : le champ "Révision" ne porte plus que le lien, sans le message du commit (demande de Vincent).
- Publication au nom de l'utilisateur : le message sans "par <utilisateur>" (clés `label_mattermost_*_short`) part dans `payload['actor_message']` ; le job l'envoie au relais comme message du post et transmet le message complet dans `bot_message`, que le relais doit utiliser quand il publie au nom du bot. Sur l'appel REST direct du bot, `actor_message` est retiré.
- Mentions : chez Cubedesigners les logins Redmine sont des emails (7 utilisateurs actifs sur 7). `add_mention_users` met les utilisateurs mentionnés (login, email) dans `payload['mention_users']` ; le job les résout par `Client#username_for` (nom d'utilisateur si le login n'est pas un email, puis `GET /users/email/...`, cache 1 h, possible car `PrivacySettings.ShowEmailAddress` est à true sur gremlins) et remplace les `@login` dans tout le payload (`Formatter.replace_mentions`). Les messages directs portent aussi l'email du destinataire et sont résolus de la même façon.
- Mentions et observateurs : Redmine n'ajoute pas les mentionnés aux observateurs (mail seulement, `notified_mentions`) ; les observateurs automatiques ne viennent que des préférences "Surveiller automatiquement" (contributeur, assigné).
- Réponses depuis Mattermost (validé par Vincent le 2026-11-04 : appel serveur à serveur accepté, écho géré en supprimant la réponse du fil). Côté Redmine, fait et testé :
  - les notifications de ticket portent `props.redmine_issue_id` ;
  - `POST /mattermost/replies` (`MattermostRepliesController` < `ActionController::API`, hors session) : en-tête `X-Redmine-Mattermost-Secret` comparé à `REDMINE_MATTERMOST_REPLY_SECRET` (absent ou faux : 404) ; corps JSON `issue_id, username, email, message, root_id, channel_id` ; utilisateur par login puis email (`User.having_mail`), actif, ticket visible et permission `add_issue_notes` ; réponses 201 `{journal_id}`, 404 ticket, 422 utilisateur inconnu ou message vide ou ticket invalide, 403 permission ;
  - la note porte `issue.mattermost_reply_to` ; la notification part avec `payload['reply_to'] = {root_id, channel_id}` : le job pose `root_id` sur l'appel REST quand le canal résolu est celui du fil, et transmet `reply_to` au relais.
- Contrat attendu de `mattermost-plugin-redmine` (à écrire, dépôt non monté le 2026-11-04) :
  - réglage `RedmineReplySecret` (`secret: true`), avec `RedmineURL` existant ;
  - hook `MessageHasBeenPosted` : ignorer si `RootId` vide, si le post porte `redmine_issue_id` (nos notifications, donc pas de boucle), s'il est d'un bot ou de type système ; lire la racine (`GetPost(RootId)`), prendre son `redmine_issue_id` ; POST JSON vers `{RedmineURL}/mattermost/replies` avec l'en-tête secret ; 201 -> `DeletePost(reply)` ; sinon `SendEphemeralPost` à l'auteur avec le `message` de la réponse ;
  - relais : `relayRequest.BotMessage` (`bot_message`) utilisé quand le poster est le bot ; `relayRequest.ReplyTo` (`reply_to` : `root_id`, `channel_id`) -> `post.RootId` si `channel.Id` == `channel_id`.
  - déploiement : même secret dans le `.env` Redmine de hotfuzz (`REDMINE_MATTERMOST_REPLY_SECRET`, à ajouter au compose de `docker-images` et à la note Bitwarden) et dans la config du plugin sur gremlins.
- RESTE À FAIRE côté `mattermost-plugin-redmine` (dépôt non monté le 2026-11-04) : champ `BotMessage string json:"bot_message,omitempty"` dans `relayRequest`, et `post.Message = req.BotMessage` quand `poster.Id == requester.Id`, avec un test. À déployer AVANT la 2.1.0 de Redmine : sinon un repli sur le bot publie la version sans auteur.

### Mise en service de la 2.1.0 (2026-11-04)

- Piège : le workflow Forgejo "Build redmine image" de `docker-images` ne part que sur un commit qui touche `Dockerfile`, `.dockerignore`, `plugins.list`, `scripts/` ou le workflow ; un push GitHub de ce dépôt ne déclenche rien. Mettre à jour le plugin en prod = relancer le workflow à la main (workflow_dispatch), puis tirer l'image et recréer le conteneur.
- Plugin Mattermost `0.1.0+a1c1fa5` installé sur gremlins (`mmctl --local plugin add --force`, archive déposée dans `/mattermost/data` : le `/tmp` du conteneur est un tmpfs invisible pour `docker cp`).
- Secret des réponses (64 car. hex) posé dans la config du plugin (`mmctl --local config patch` avec la section complète du plugin) et dans le bloc `docker-images/redmine` de `/docker/redmine/.env`, conteneur recréé. Route vérifiée : mauvais secret 404 vide, bon secret et ticket 0 : 404 `issue not found`.
- Attributs ignorés en prod : `cf_9` (Sessions Claude Code).
- Reste à Vincent : bw-sync des deux secrets (jeton du bot, secret des réponses) vers la note Bitwarden, sinon une régénération du `.env` les efface ; supprimer `/docker/redmine/.env.avant-mattermost` ; tester une vraie réponse dans un fil.

## Pistes (étape 2)

- Un fil de discussion par ticket (`root_id`), ce qui suppose de mémoriser l'identifiant du premier post par ticket et par canal (le relais renvoie déjà `post_id`).
- Mise à jour d'un message existant plutôt qu'un nouveau post.
- Couleur de l'attachment selon le statut ou la priorité.
- Autres événements : actualités, documents, versions, temps passé, relations entre tickets.
- Le plugin Mattermost a déjà `/redmine link` (canal -> projet en KV) : piste pour router les notifications d'un projet vers ses canaux liés. Boutons interactifs au même endroit.
- Redmine 7 dispose de webhooks natifs (`app/jobs/webhook_job.rb`) : à regarder pour voir ce qu'ils couvrent.

## Points d'attention

- Une description ou une note contenant `@all` ou `@channel` déclenche la mention Mattermost correspondante (texte transmis tel quel, comme avant).
- Les notes au format Textile s'affichent sans conversion (Mattermost rend du Markdown).
- Le cache des identifiants de canaux est indexé par serveur et jeton : un changement de configuration repart à zéro, un canal renommé côté Mattermost reste en cache jusqu'à 1 h.
- Le relais permet au jeton du bot Redmine de publier au nom de tout utilisateur autorisé à écrire dans le canal visé : le jeton doit rester hors de la base (variable d'environnement).

## Journal des sessions

### 2026-11-03

- Lecture complète du code, initialisation de ce fichier.
- Décisions de Vincent : matrice de versions conservée, renommage en `redmine_mattermost`, bot, Mattermost 12.0 ; puis publication au nom de l'utilisateur via un plugin serveur relais, dans ce dépôt.
- Refonte de l'étape 1 : renommage complet, client API bot, messages Markdown, migrations 001/002, 7 langues, README, CHANGELOG 2.0.0, tests.
- Bugs de la 1.1.2 corrigés dans la refonte : regex du hook de commit, SSL par projet ignoré, URL de webhook dans les logs, `CustomField.find` sur champ supprimé, `@setting_found` partagé, mentions lues dans la description, double notification sur mot-clé de commit, modifications wiki jamais notifiées (callback sur `WikiPage` au lieu de `WikiContent`), cases à cocher globales fausses sur les valeurs par défaut, enregistrement créé à l'affichage de l'onglet.
- Plugin serveur Mattermost (Go) écrit, testé et empaqueté ; option Redmine "Publier au nom de l'utilisateur" ; repli sur le bot.
- Vérifié : 62 tests Redmine et 12 tests Go au vert, RuboCop, Semgrep, YAML des 7 langues (43 clés identiques).
- Pas encore vérifié : envoi réel vers un serveur Mattermost, slim-lint.
- Vincent n'a pas besoin de CI : `Jenkinsfile` et `old_dot_github/` supprimés, tâche CI retirée.
- Relais fusionné dans `EnhydraV/mattermost-plugin-redmine` (branche `feat/relais-notifications`, à la demande de Vincent) : `RELAY_PLUGIN_ID` = `com.cubedesigners.redmine`, sous-dossier `mattermost-plugin/` supprimé, textes des 7 langues, README et CHANGELOG mis à jour.
- Environnement : worktree en CRLF (index en LF), aucun `.gitattributes` ; `.idea/` non suivi et absent du `.gitignore`.
