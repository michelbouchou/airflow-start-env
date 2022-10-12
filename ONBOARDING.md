# Guide du nouvel arrivant

Pour commencer, il faut vous connecter aux serveurs (GCP Compute Engine) et a Github :

## 1.1. Connexion Compute Engine

1. Demandez à votre responsable d'avoir les droits de `ComputeEgine.OSLogin` dans le projet GCP `PROJECT_NAME`.
2. Installez [`glcoud`, le SDK de GCP](https://cloud.google.com/sdk/docs/install)
3. Lancez la commande suivante depuis un terminal afin de créer une paire de clé SSH et de tester la connection.

```shell
gcloud beta compute ssh \
  --zone "ZONE"\
  "VM_NAME" \
  --tunnel-through-iap \
  --project "PROJECT_ID" \
  ;
```

4. Si la connection SSH fonctionne dans le terminal, relancer la même commande mais avec `--dry-run` en plus à la fin

```shell
gcloud beta compute ssh \
  --zone "ZONE"\
  "VM_NAME" \
  --tunnel-through-iap \
  --project "PROJECT_ID" \
  --dry-run \
  ;
```

5. Pour les utilisateurs MAC : récupérer le résultat retourné par la commande précédente,
   remplacez `ProxyCommand /System/Library ... --verbosity=warning` par `ProxyCommand="/System/Library ... --verbosity=warning"`,
   `/usr/bin/ssh` simplement par `ssh`. , et `%port` par `%p`
   Copiez le text en question, car vous en aurez besoin dans l'étape suivante.

6. Dans le fichier `~/.ssh/config`, ajoutez la section suivante. Veillez à bien remplacer les parties concernées.
   Vous remarquerez qu'elle est construite à partir du résultat de la commande antérieure :

```
Host HOSTNAME
    HostName compute.6137362399221448678
    ProxyUseFdpass no
    IdentityFile ~/.ssh/google_compute_engine
    UserKnownHostsFile ~/.ssh/google_compute_known_hosts
    User username
    ProxyCommand LOCAL_PYTHON_PATH -S /Applications/google-cloud-sdk/lib/gcloud.py beta compute start-iap-tunnel dev-instance %p --listen-on-stdin --project=PROJECT_ID --zone=ZONE --verbosity=warning
```

7. Pour les utilisateurs Windows, le fichier resemble au suivant, `ProxyCommand` est `-proxycmd`.

```
Host HOSTNAME_2
    HostName compute.8160292163141368109
    ProxyUseFdpass no
    IdentityFile ~/.ssh/google_compute_engine
    UserKnownHostsFile ~/.ssh/google_compute_known_hosts
    User username_2
    ProxyCommand "LOCAL_PYTHON_PATH" "-S" "LOCAL_GCLOUD_PATH" beta compute start-iap-tunnel dev-local-instance %p --listen-on-stdin --project=PROJECT_ID --zone=ZONE --verbosity=warning
```

8. Config des IDE :

VS Code :

- Installez le [plugin VS Code Remote: SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) <br />
  puis _Shift-Command-P -> Remote-SSH: Connect to Host -> HOSTNAME_.
- Une fois connecté sur l'instance, vous pouvez installer d'autres plugins. Voici la liste des plugins recommandés :
  1. [Python](https://marketplace.visualstudio.com/items?itemName=ms-python.python)
  2. [Database CLient](https://marketplace.visualstudio.com/items?itemName=cweijan.vscode-database-client2)
  3. [Git Lens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens)
- Définition des tunnels vers les UI Airflow & logs
  - #TODO

PyCharm (Version pro > 2022.1) : [Support natif du remote dev](https://www.jetbrains.com/help/pycharm/remote-development-a.html#gateway)

- A partir de l'écran d'accueil, ou de File > "Remote development"
  - Dans l'onglet SSH, selectionner "New connection". Et aller dans les options de la nouvelle connection à creer
  - "Authentication type" : "OpenSSH config and authentication agent" <br />
    Host : "HOSTNAME" (le même que dans le fichier `~/.ssh/config`) et port : 22. <br />
    PyCharm doit trouver tout seul le username
  - "Test connection", puis validez.
- Définir les tunnels SSH vers les UI Airflow & logs :
  - #TODO

## 1.2. Connexion Github

1. Ouvrez un terminal depuis VS Code (ce terminal devrait s'ouvrir dans la VM), et créez un paire de clés SSH pour GitHub.

```shell
git config --global user.name "USERNAME"
git config --global user.email "EMAIL"
ssh-keygen -q -C "ComputeEngineDataDev" -t ed25519 -b 2048 -f ~/.ssh/id_github
cat << EOF >> ~/.ssh/config
Host github.com
  User git
  Hostname github.com
  IdentityFile ~/.ssh/id_github
EOF
chmod 400 ~/.ssh/id_github
```

2. Ajoutez la nouvelle clé publique sur GitHub, en copiant le contenu du fichier `~/.ssh/id_github.pub`
   et le collant sur [https://github.com/settings/keys](https://github.com/settings/keys)

3. Installer `pipenv` et `pre-commit` dans votre user a l'aide de `pip`. Nous recommandons d'utiliser `pipx`.

```shell
pip3 install pipx
python3 -m pipx ensurepath
exec $SHELL
pipx install pipenv
pipx install pre-commit
```

## 2. Configurer un VM pour la première fois

```bash
sudo apt update
sudo apt install \
    python3.7 \
    git \
    jq \
    make \
    python3-pip \
    python3-venv \
    default-libmysqlclient-dev \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    ;
```

Après, installer Docker selon la [documentation officielle](https://docs.docker.com/engine/install/debian/).
C'est aussi important de suivre [le guide de post-installation](https://docs.docker.com/engine/install/linux-postinstall/)
