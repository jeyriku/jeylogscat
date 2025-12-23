# Initialisation de SSH_PREFIX_STR pour compatibilité
if [ -n "${NETDEV_PASS:-}" ]; then
  if command -v sshpass >/dev/null 2>&1; then
    SSH_PREFIX_STR="sshpass -p '${NETDEV_PASS}'"
  else
    SSH_PREFIX_STR=""
    echo "WARNING: NETDEV_PASS is set but 'sshpass' not found; will attempt key-based auth"
  fi
else
  SSH_PREFIX_STR=""
fi
#!/bin/bash
# --- Relance automatique en bash si nécessaire ---
if [ -z "$BASH_VERSION" ]; then
  if command -v bash >/dev/null 2>&1; then
    echo "[INFO] Relance du script avec bash pour compatibilité."
    exec bash "$0" "$@"
  else
    echo "[ERREUR] Bash n'est pas disponible sur ce système."
    exit 98
  fi
fi
# Push syslog config commands to network devices listed in the env var "netdev" (or NETDEVS).
# Usage:
#   export netdev="dev1 dev2 ..."
#   export SYSLOG_SERVER=192.0.2.10
#   export NETDEV_USER=admin
#   export SSH_OPTS="-i /home/jeyriku/.ssh/id_ed25519_jeynas01 -o StrictHostKeyChecking=no"
#   export DRY_RUN=1   # default 1 -> only print commands; set to 0 to actually SSH and run
# Then run: sudo /opt/jeylogscat/push-syslog-to-devices.sh

set -euo pipefail

# Redirection de toute la sortie vers un fichier log horodaté
LOGFILE="push-syslog-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

# Initialisation sécurisée de SSH_OPTS

# Forcer la compatibilité avec les équipements Cisco/ASA anciens (ssh-rsa)
# Option -tt (pseudo-terminal) activable uniquement si SSH_FORCE_TTY=1
if [ "${SSH_FORCE_TTY:-0}" = "1" ]; then
  SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10 -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa"
else
  SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa"
fi

## Chargement de la liste d'équipements
# Priorité : si le fichier devices.txt existe et n'est pas vide, l'utiliser
if [ -f devices.txt ] && [ -s devices.txt ]; then
  NETDEVS_RAW="$(grep -v '^\s*#' devices.txt | xargs)"
  echo "[INFO] Liste des équipements chargée depuis devices.txt : $NETDEVS_RAW"
else
  NETDEVS_RAW=${netdev:-${NETDEVS:-}}
fi
if [ -z "${NETDEVS_RAW:-}" ]; then
  echo "ERROR: devices.txt introuvable/vide et variable d'environnement 'netdev' ou 'NETDEVS' non définie"
  exit 2
fi
SYSLOG_SERVER=${SYSLOG_SERVER:-192.168.0.251}
echo "[INFO] Adresse du serveur syslog utilisée : $SYSLOG_SERVER"
# Prefer explicit NETDEV_USER, fall back to legacy lowercase netdev_user from .zshrc

# Initialisation sécurisée de NETDEV_USER et NETDEV_PASS
: "${NETDEV_USER:=${netdev_user:-}}"
: "${NETDEV_PASS:=${netdev_passwd:-}}"
export NETDEV_USER
export NETDEV_PASS

# Tableaux associatifs pour rapport par équipement
declare -A REPORT_STATUS REPORT_DETAIL

# 1. Affichage détaillé des erreurs SSH
# Mode debug SSH complet
SSH_VERBOSE="-vvv"

for dev in $NETDEVS_RAW; do
  echo "[DEBUG] (début boucle) NETDEV_USER=\"$NETDEV_USER\" NETDEV_PASS=\"********\" SSH_PREFIX_STR=\"$SSH_PREFIX_STR\" SSH_OPTS=\"$SSH_OPTS\" dev=\"$dev\""
  dev_lc=$(echo "$dev" | tr '[:upper:]' '[:lower:]')
  echo "--- device: $dev ---"
  # Détection du type d'équipement
  if [[ "$dev_lc" == *jeysa* || "$dev_lc" == *asa* || "$dev_lc" == "jeysaco" ]]; then
    dtype=asa
  elif [[ "$dev_lc" == *jun* || "$dev_lc" == *srx* || "$dev_lc" == *junos* || "$dev_lc" == *ex* ]]; then
    dtype=juniper
  else
    dtype=cisco
  fi

  # Pré-check syslog
  case "$dtype" in
    cisco|asa)
      precheck_cmd="show running-config | include logging host"
      precheck_expected="$SYSLOG_SERVER"
      ;;
    juniper)
      precheck_cmd="show configuration system syslog"
      precheck_expected="$SYSLOG_SERVER"
      ;;
  esac
  if [ "$DRY_RUN" -eq 0 ]; then
    if [ "$dtype" = "asa" ]; then
      echo "[PRE-CHECK] $dev (ASA) : vérification via expect..."
      precheck_result=$(expect /opt/jeylogscat/asa_check_expect.exp "$dev" "$NETDEV_USER" "$NETDEV_PASS" "show running-config | include logging host" 2>&1 || true)
      if echo "$precheck_result" | grep -q "$precheck_expected"; then
        echo "[PRE-CHECK] $dev : configuration syslog déjà présente, aucune action nécessaire. Passage à l'équipement suivant."
        REPORT_STATUS["$dev"]="ALREADY_PRESENT"
        REPORT_DETAIL["$dev"]="Config déjà présente, non modifiée."
        continue
      else
        echo "[PRE-CHECK] $dev : configuration syslog absente, application des commandes via expect."
      fi
    else
      precheck_result=$(eval "$SSH_PREFIX_STR ssh $SSH_OPTS ${NETDEV_USER}@${dev} \"$precheck_cmd\" 2>&1" || true)
      if echo "$precheck_result" | grep -q "$precheck_expected"; then
        echo "[PRE-CHECK] $dev : configuration syslog déjà présente, aucune action nécessaire. Passage à l'équipement suivant."
        REPORT_STATUS["$dev"]="ALREADY_PRESENT"
        REPORT_DETAIL["$dev"]="Config déjà présente, non modifiée."
        continue
      else
        echo "[PRE-CHECK] $dev : configuration syslog absente, application des commandes."
      fi
    fi
  else
    echo "[PRE-CHECK] (DRY_RUN) $dev : $precheck_cmd"
    REPORT_STATUS["$dev"]="DRY_RUN"
    REPORT_DETAIL["$dev"]="(DRY_RUN)"
    continue
  fi

  # Application de la configuration
  case "$dtype" in
    cisco)
      cisco_cmds="configure terminal
logging host ${SYSLOG_SERVER} transport udp port 514
logging trap informational
end
write memory"
      echo "Detected Cisco device. Commands to run:"
      echo "$cisco_cmds"
      if [ "$DRY_RUN" -eq 0 ]; then
        echo "Test de connexion SSH vers $dev..."
        # 2. Mode verbeux pour SSH
        echo "[DEBUG] NETDEV_USER=\"$NETDEV_USER\""
        echo "[DEBUG] NETDEV_PASS=\"********\""
        echo "[DEBUG] SSH_PREFIX_STR=\"$SSH_PREFIX_STR\""
        echo "[DEBUG] SSH_OPTS=\"$SSH_OPTS\""
        echo "[DEBUG] Commande SSH exécutée : $SSH_PREFIX_STR ssh $SSH_VERBOSE $SSH_OPTS -o ConnectTimeout=5 ${NETDEV_USER}@${dev} exit </dev/null"
        echo "[DEBUG] Commande SSH exécutée : $SSH_PREFIX_STR ssh $SSH_VERBOSE $SSH_OPTS -o ConnectTimeout=5 ${NETDEV_USER}@${dev} exit </dev/null"
        if eval "$SSH_PREFIX_STR ssh $SSH_VERBOSE $SSH_OPTS -o ConnectTimeout=5 ${NETDEV_USER}@${dev} exit </dev/null 2>&1"; then
          echo "Connexion SSH OK. Pause avant envoi des commandes..."
          sleep 2
          if [[ "$dev_lc" == *sw* ]]; then
            while IFS= read -r line; do
              echo "$line"
              sleep 1
            done <<< "$cisco_cmds" | eval "$SSH_PREFIX_STR ssh $SSH_VERBOSE $SSH_OPTS ${NETDEV_USER}@${dev}"
          else
            printf "%s\n" "$cisco_cmds" | eval "$SSH_PREFIX_STR ssh $SSH_VERBOSE $SSH_OPTS ${NETDEV_USER}@${dev}"
          fi
        else
          echo "[DEBUG] Commande SSH exécutée (échec) : $SSH_PREFIX_STR ssh $SSH_VERBOSE $SSH_OPTS -o ConnectTimeout=5 ${NETDEV_USER}@${dev} exit </dev/null"
          echo "[DEBUG] Tentative d'automatisation avec expect pour Cisco..."
          if expect /opt/jeylogscat/auto_syslog_expect.exp "$dev" "$NETDEV_USER" "$NETDEV_PASS" "cisco" "$SYSLOG_SERVER" >> "$LOGFILE" 2>&1; then
            echo "[INFO] Automatisation via expect réussie pour $dev"
            REPORT_STATUS["$dev"]="OK"
            REPORT_DETAIL["$dev"]="Appliquée via expect fallback"
            continue
          else
            echo "[ERREUR] Connexion SSH impossible vers $dev."
            echo "[DEBUG] Détail de l'échec SSH :"
            eval "$SSH_PREFIX_STR ssh $SSH_VERBOSE $SSH_OPTS -o ConnectTimeout=5 ${NETDEV_USER}@${dev} exit </dev/null 2>&1"
            REPORT_STATUS["$dev"]="KO"
            REPORT_DETAIL["$dev"]="Echec SSH et fallback expect échoué"
            continue
          fi
        fi
      fi
      ;;
    juniper)
      juniper_cmds="cli -c 'configure; set system syslog host ${SYSLOG_SERVER} any any; commit and-quit'"
      echo "Detected Juniper device. Commands to run (will use 'cli -c' to configure):"
      echo "$juniper_cmds"
      if [ "$DRY_RUN" -eq 0 ]; then
        echo "Test de connexion SSH vers $dev..."
        if eval "$SSH_PREFIX_STR ssh $SSH_OPTS -o ConnectTimeout=5 -o BatchMode=yes ${NETDEV_USER}@${dev} \"exit\" >/dev/null 2>&1"; then
          echo "Connexion SSH OK. Envoi des commandes..."
          echo "$juniper_cmds" | eval "$SSH_PREFIX_STR ssh $SSH_OPTS ${NETDEV_USER}@${dev}"
        else
          echo "[ERREUR] Connexion SSH impossible vers $dev. Commandes non envoyées."
          echo "[DEBUG] Tentative d'automatisation avec expect pour Juniper..."
          expect /opt/jeylogscat/auto_syslog_expect.exp "$dev" "$NETDEV_USER" "$NETDEV_PASS" "juniper" "$SYSLOG_SERVER" || {
            echo "[GUIDE] Automatisation échouée. Passage en mode interactif guidé."
            ...existing code...
          }
        fi
      fi
      ;;
    asa)
      # ASA requires an interface name for logging host. Default to 'inside' unless ASA_IF_<host> env var provided.
      ASA_IF_VAR="ASA_IF_${dev^^}"
      ASA_IF=${!ASA_IF_VAR:-inside}
      asa_cmds="terminal length 0
    terminal pager 0
    configure terminal
    logging host ${ASA_IF} ${SYSLOG_SERVER} udp/514
    logging trap informational
    write memory"
      echo "Detected ASA device. Using interface '${ASA_IF}'. Commands to run:"
      echo "$asa_cmds"
      if [ "$DRY_RUN" -eq 0 ]; then
        echo "[DEBUG] Utilisation systématique d'expect pour ASA ($dev)"
        expect /opt/jeylogscat/auto_syslog_expect.exp "$dev" "$NETDEV_USER" "$NETDEV_PASS" "asa" "$SYSLOG_SERVER" >> "$LOGFILE" 2>&1 || {
          echo "[GUIDE] Automatisation échouée. Passage en mode interactif guidé."
          ...existing code...
        }
      fi
      ;;
  esac

  # Vérification post-config
  case "$dtype" in
    cisco|asa)
      check_cmd="show running-config | include logging host"
      expected="$SYSLOG_SERVER"
      ;;
    juniper)
      check_cmd="show configuration system syslog"
      expected="$SYSLOG_SERVER"
      ;;
  esac
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY_RUN] Vérification à exécuter sur $dev : $check_cmd"
    REPORT_STATUS["$dev"]="DRY_RUN"
    REPORT_DETAIL["$dev"]="(DRY_RUN)"
  else
    echo "Vérification post-config sur $dev..."
    if [ "$dtype" = "asa" ]; then
      result=$(expect /opt/jeylogscat/asa_check_expect.exp "$dev" "$NETDEV_USER" "$NETDEV_PASS" "$check_cmd" 2>&1 || true)
    elif [ "$dtype" = "juniper" ]; then
      result=$(expect /opt/jeylogscat/juniper_check_expect.exp "$dev" "$NETDEV_USER" "$NETDEV_PASS" "$check_cmd" 2>&1 || true)
    else
      result=$(eval "$SSH_PREFIX_STR ssh $SSH_OPTS ${NETDEV_USER}@${dev} \"$check_cmd\" 2>&1" || true)
      # Si le check SSH ne retourne pas la valeur attendue, tenter un fallback via expect (Cisco interactif)
      if ! echo "$result" | grep -q "$expected"; then
        echo "[DEBUG] Résultat SSH ne contient pas la valeur attendue ; tentative de fallback expect pour $dev"
        result_expect=$(expect /opt/jeylogscat/cisco_check_expect.exp "$dev" "$NETDEV_USER" "$NETDEV_PASS" "$check_cmd" 2>&1 || true)
        result="${result}\n${result_expect}"
      fi
    fi
    if echo "$result" | grep -q "$expected"; then
      echo "[OK] $dev : configuration syslog détectée."
      REPORT_STATUS["$dev"]="OK"
      REPORT_DETAIL["$dev"]="OK"
    else
      echo "[KO] $dev : configuration syslog ABSENTE ou non détectée !"
      REPORT_STATUS["$dev"]="KO"
      REPORT_DETAIL["$dev"]="KO : $result"
    fi
  fi
  echo
done


 # --- Rapport de succès/échec et vérification post-configuration ---
echo "\n=== Rapport de configuration syslog et vérification post-configuration ==="
for dev in $NETDEVS_RAW; do
  dev_lc=$(echo "$dev" | tr '[:upper:]' '[:lower:]')
  if [[ "$dev_lc" == *jeysa* || "$dev_lc" == *asa* || "$dev_lc" == "jeysaco" ]]; then
    dtype=asa
  elif [[ "$dev_lc" == *jun* || "$dev_lc" == *srx* || "$dev_lc" == *junos* || "$dev_lc" == *ex* ]]; then
    dtype=juniper
  else
    dtype=cisco
  fi
  case "$dtype" in
    cisco|asa)
      check_cmd="show running-config | include logging host"
      expected="$SYSLOG_SERVER"
      ;;
    juniper)
      check_cmd="show configuration system syslog"
      expected="$SYSLOG_SERVER"
      ;;
  esac
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY_RUN] Vérification à exécuter sur $dev : $check_cmd"
    REPORT_STATUS["$dev"]="DRY_RUN"
    REPORT_DETAIL["$dev"]="(DRY_RUN)"
  else
    echo "Vérification post-config sur $dev..."
    if [ "$dtype" = "asa" ]; then
      result=$(expect /opt/jeylogscat/asa_check_expect.exp "$dev" "$NETDEV_USER" "$NETDEV_PASS" "$check_cmd" 2>&1 || true)
    elif [ "$dtype" = "juniper" ]; then
      result=$(expect /opt/jeylogscat/juniper_check_expect.exp "$dev" "$NETDEV_USER" "$NETDEV_PASS" "$check_cmd" 2>&1 || true)
    else
      result=$(eval "$SSH_PREFIX_STR ssh $SSH_OPTS ${NETDEV_USER}@${dev} \"$check_cmd\" 2>&1" || true)
      # Tentative de fallback expect si la vérification SSH ne trouve pas la bonne valeur
      if ! echo "$result" | grep -q "$expected"; then
        echo "[DEBUG] Vérification SSH insuffisante ; tentative de fallback expect pour $dev"
        result_expect=$(expect /opt/jeylogscat/cisco_check_expect.exp "$dev" "$NETDEV_USER" "$NETDEV_PASS" "$check_cmd" 2>&1 || true)
        result="${result}\n${result_expect}"
      fi
    fi
    if echo "$result" | grep -q "$expected"; then
      echo "[OK] $dev : configuration syslog détectée."
      REPORT_STATUS["$dev"]="OK"
      REPORT_DETAIL["$dev"]="OK"
    else
      echo "[KO] $dev : configuration syslog ABSENTE ou non détectée !"
      REPORT_STATUS["$dev"]="KO"
      # Diagnostic détaillé pour ASA et Juniper
      if [ "$dtype" = "asa" ]; then
        REPORT_DETAIL["$dev"]="KO (ASA) : Vérifiez la syntaxe de la commande logging host, l'interface utilisée et les logs côté ASA. Résultat : $result"
      elif [ "$dtype" = "juniper" ]; then
        REPORT_DETAIL["$dev"]="KO (Juniper) : Vérifiez l'utilisateur, les droits, la configuration SSH et la syntaxe Junos. Résultat : $result"
      else
        REPORT_DETAIL["$dev"]="KO : $result"
      fi
    fi
  fi
done

echo "\n=== Synthèse finale ==="
for dev in $NETDEVS_RAW; do
  status=${REPORT_STATUS["$dev"]}
  detail=${REPORT_DETAIL["$dev"]}
  if [ "$status" = "OK" ]; then
    echo "[OK] $dev : configuration syslog appliquée et détectée."
  elif [ "$status" = "KO" ]; then
    echo "[KO] $dev : $detail"
  else
    echo "[INFO] $dev : vérification non effectuée (DRY_RUN)."
  fi
done

# Exemple de liste complète d'équipements (Cisco, ASA, Juniper)
# export netdev="cisco-sw-01 cisco-sw-02 cisco-rtr-01 cisco-rtr-02 jeysaco jey-srx3x-ce-01 jey-srx3x-pe-01 jey-srx3x-pe-02 jey-srx3x-pe-03 jey-srx3x-pe-04 jey-srx3x-pe-05 jey-srx3x-rr-01 jey-srx3x-rr-02"
# Personnalisez la variable netdev selon votre inventaire réel.

# devices.txt est déjà pris en compte en tête de script (priorité)
