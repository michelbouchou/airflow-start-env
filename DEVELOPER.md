# Guide pour les développeurs

S'il s'agit de votre premiere connexion, suivez [le guide du nouvel arrivant](./ONBOARDING.md).

NB: N'oubliez pas d'installer `pipenv` et `pre-commit`.

## Guide de démarrage local

Pour démarrer l’utilisation du projet dans les instances, il suffit de cloner le repo et de lancer la commande `make launch`.

```shell
git clone SSH_GIT_LINK
cd FOLDER_NAME
make launch
```

Cette commande crée une instance Airflow de développement sur le port 8080 avec un utilisateur admin (user: admin / mdp: password).
Vous pouvez modifier cet utilisateur en utilisant la commande `airflow users`.

Si vous rencontrez des problèmes, vous pouvez recommencer votre installation à l'aide de la commande `make clean`.

## Testing

Utilisez la commande `make pytest` pour exécuter les tests.

Il est aussi possible de lancer les tests via la CLI de `pytest` ou le runner de VS Code,
mais il faut avoir crée le fichier `.composer/config.json` au prealable (à l'aide du [`Makefile`](./Makefile)).

La config des tests se trouve dans le fichier [`pytest.ini`](./pytest.ini)

## Linting

Vous pouvez l'exécuter manuellement ou via des targets PHONY sur `make`.

La target `make lint` lance l'ensemble des linters,
mais il est aussi possible de les exécuter séparément : `make black`, `make sqlfluff`, etc.

## PreCommit Hooks

Nous utilisons [`pre-commit`](https://pre-commit.com/) pour configurer et exécuter les pre-commit hooks.

L’installation et configuration est simple (pas besoin d’avoir un venv):

```bash
pip install pre-commit
pre-commit install
```

Pour lancer pre-commit sans commit : `pre-commit run --all-files`
Pour commit sans éxecuter les hooks : `git commit --no-verify`

Vous retrouverez la configuration de pre-commit dans le fichier [`.pre-commit-config.yaml`](./.pre-commit-config.yaml).
Pour mettre a jour les versions de hooks dans la config : `pre-commit autoupdate`

## Prepare Commit Message

Afin d'ajouter le numéro de ticket un début du message du commit s'il est précisé dans le nom de la branche, il faut mettre en place l'utilisation du hook `prepare-commit-message`.

Un `make .git/hooks/prepare-commit-message` est disponible et est lié à un make launch.

## Dépendances

Pour ajouter une dépendance au projet, il suffit lancer la commande `pipenv install <package>`ou bien, d’ouvrir le fichier [`Pipfile`](./Pipfile) et ajouter la librairie à installer.

Puis rejouez la commande `make launch` ou bien `make Pipfile.lock`.
Cette action génèrera le fichier [`Pipfile.lock`](./Pipfile.lock) à jour compilé avec toutes les dépendances et sous-dépendances.

N'oubliez pas de bien commiter les changements sur les fichiers de `Pipfile` et `Pipfile.lock`.

Le dépendances pour le développement du projet se trouvent dans le fichier [`Pipfile`](./Pipfile), et elle peut être modifier avec la commande `pipenv install --dev <package>`.

### Dépendances pour Composer

Pour produire la liste des packages à installer sur Composer, il faut produire une liste que:

- Est compatible avec tous les packages déjà présents sur Composer.
- Ne contient aucun package déjà présent sur Composer (pour eviter des conflits).
- (Preferablement) est compilée, c'est-à-dire, contient toutes les sous-dépendances.

Pour cela, garantir les 3 points anterieurs, nous utilisons la procedure suivant:

```
composer_deps = COMPILE(default_composer + custom_deps) - default_composer

default_composer := deps used by default by composer
custom_deps := extra deps you need
```

En detail, le processus resultant est:

1. Ajouter le package avec la commande `pipenv install <package>`
2. Calculer les packages compilés avec la commande `make dev/extra-requirements.txt`
3. Envoyer le contenu résultant à vos collegues et à l'equipe DevOps/Infrastructure.
4. N'oubliez pas de commiter les changements.

## Gestions de secrets

Le backend de secrets configuré par default c’est [GCP Secret Manager](https://console.cloud.google.com/security/secret-manager).

Cependant, nous n’utilisons Secret Manager que pour les connexions, les variables se trouvent dans le store local d’Airflow.

**Il faut donc faire attention à ne pas déclarer des connexions chez Airflow, ni déclarer des variables chez Secret Manager.**

Airflow continue donc à utiliser les deux stores. Pour mieux comprendre cette double gestion le tableau suivant détaille les usages communs.

| Usage                                   | Résultat                                             |
| --------------------------------------- | ---------------------------------------------------- |
| `Variable.get` ou `Connection(conn_id)` | D’abord cherche chez Secret Manager et puis en local |
| `Variable.set`                          | Directement stocké dans le store local               |
| `+` Add variable depuis UI              | Directement stocké dans le store local               |
| List Connections depuis UI              | Ne montre que les connexions locales                 |
| List Variables depuis UI                | Ne montre que les variables locales                  |

Il est aussi important à retenir que la VM et Composer ne peuvent accéder qu’aux secrets crées par Terraform,
et qu’il n’ont pas le droit d’écriture ni création sur aucun secret.

Voici pourquoi **il faut donc faire attention à ne pas déclarer des connexions chez Airflow, ni des variables chez GCP.**

## Déploiement

La CD (Continuous Deployment) du projet est géré par CircleCI.
Les push sur la branche de develop seront déployés sur le projet de dev.
