# Device syslog push — Usage safe guide

But: ce document décrit l'utilisation sécurisée de `push-syslog-to-devices.sh` pour déployer la configuration syslog vers les équipements réseau.

Prérequis
- Exécuter depuis `/opt/jeylogscat` en tant qu'utilisateur disposant des clefs/accès SSH (ou `sudo` si nécessaire).
- Fournir la liste des équipements soit via `devices.txt` (une entrée par ligne), soit via la variable d'environnement `NETDEVS`.
- Définir l'utilisateur réseau : `NETDEV_USER=admin` (obligatoire si vous n'utilisez pas l'auth SSH par clé).
- Si authentification par mot de passe nécessaire, définir `NETDEV_PASS` (note : transmettre en variable d'environnement temporaire est recommandé plutôt que stocker en clair).

Modes d'exécution
- Dry-run (recommandé): `DRY_RUN=1 /opt/jeylogscat/push-syslog-to-devices.sh` — imprime les actions sans les exécuter.
- Production (applique la config): `sudo DRY_RUN=0 /opt/jeylogscat/push-syslog-to-devices.sh` — applique les commandes sur les équipements.

Sécurité et recommandations
- Préférer l'authentification par clé SSH et usage de `ssh-agent` plutôt que `NETDEV_PASS`.
- Testez d'abord sur un petit sous-ensemble d'appareils (ex. `NETDEVS="jey-test-01 jey-test-02"`).
- Planifiez une fenêtre de maintenance si vous exécutez le push sur un grand parc.
- Le script utilise des fallbacks Expect pour Cisco/ASA si la connexion SSH échoue — cela peut demander un mot de passe interactif.

Rollback
- Le script écrit la configuration via commandes natives (`configure terminal` / `write memory`). Le rollback dépend de chaque équipement (save/restore de config hors scope). Avant large déploiement, sauvegardez les configurations existantes.

Logs et audit
- Le script écrit un log horodaté dans le répertoire courant (`push-syslog-YYYYMMDD-HHMMSS.log`).
- Le service d'alerte (`syslog-alert-relay`) et son log sont dans `/var/log/syslog-alert-relay/relay.log`.

Exemples
- Dry-run sur un petit inventaire:
```
NETDEVS="cisco-sw-01 jeysaco" DRY_RUN=1 /opt/jeylogscat/push-syslog-to-devices.sh
```
- Exécution réelle (avec sudo):
```
NETDEV_USER=admin NETDEV_PASS='vault-or-temp' sudo DRY_RUN=0 /opt/jeylogscat/push-syslog-to-devices.sh
```

Contact
- Pour toute question ou si vous souhaitez que j'exécute le push réel, fournissez `NETDEV_USER` et la méthode d'auth (clé SSH ou `NETDEV_PASS`).
