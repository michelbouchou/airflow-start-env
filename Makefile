VENV_DIR := venv
GCP_PROJECT := PROJECT_ID
GCP_LOCATION := LOCATION
COMPOSER_INSTANCE := COMPOSER_INSTANCE

python_version := ${shell python3 -c 'print("python"+".".join(map(str, __import__("sys").version_info[:2])))'}
bin_dir := ${VENV_DIR}/bin

current_username := ${shell whoami}
webserver_port := ${shell jq -r '.'"${current_username}"'.webserver' dev/port_allocation.json}
log_server_port := ${shell jq -r '.'"${current_username}"'.log_server' dev/port_allocation.json}

global_env_vars := AIRFLOW_HOME=. AIRFLOW__WEBSERVER__WEB_SERVER_PORT=${webserver_port} AIRFLOW__CELERY__WORKER_LOG_SERVER_PORT=${log_server_port}

# Le ONESHELL est necessaire pour permettre a la target de launch de
# gerer le forwarding de signaux au procces en background
.ONESHELL:

${bin_dir}/activate:
	python3 -m venv ${VENV_DIR}
	@${bin_dir}/python -m pip install --upgrade pip wheel setuptools

.PHONY: venv
venv: ${bin_dir}/activate

# Nous declarons cette target comme PHONY car elle a des sources distantes (eg la config Composer GCP)
# Cela ne nous impacte pas car cette commande se execute tres rapidement
.PHONY: .composer/config.json
.composer/config.json:
	mkdir -p .composer
	@$(eval tmp_file := $(shell mktemp --suffix=.json))
	gcloud composer environments describe \
		--format=json \
		--project=${GCP_PROJECT} \
		--location=${GCP_LOCATION} \
		${COMPOSER_INSTANCE} \
		> ${tmp_file}
	@if [ "$$(cat ${tmp_file} | wc -l)" -eq "0" ] ; then echo "Echec au recuperation de la config GCP" ; exit 1 ; fi
	@mv $(tmp_file) .composer/config.json

# Compiler les dependances
Pipfile.lock: Pipfile | ${bin_dir}/activate
	source ${bin_dir}/activate && pipenv lock
	touch Pipfile.lock

# Installer airflow si les dependances changent
${bin_dir}/airflow: Pipfile.lock | ${bin_dir}/activate
	. ${bin_dir}/activate && pipenv install && touch ${bin_dir}/airflow

# Installer airflow si les dependances changent
${bin_dir}/pytest: Pipfile.lock | ${bin_dir}/activate
	. ${bin_dir}/activate && pipenv install --dev
	touch ${bin_dir}/pytest

.PHONY: install
install: ${bin_dir}/airflow

# Creation du user admin
airflow.db: ${bin_dir}/airflow
	@${global_env_vars} ${bin_dir}/airflow db init
	@${global_env_vars} ${bin_dir}/airflow users create \
		--username admin \
		--password password \
		--firstname fname \
		--lastname lname \
		--role Admin \
		--email admin@example.org \
		;

# Lancement du airflow avec injection variables d'environnement
# We use the activate syntax since there is a bug in the way airflow locates its gunicorn runner
.PHONY: launch
launch: airflow.db ${bin_dir}/airflow .git/hooks/prepare-commit-msg
	@. ${bin_dir}/activate && \
		${global_env_vars} \
		airflow webserver &
	@. ${bin_dir}/activate && \
		${global_env_vars} \
		airflow scheduler &
	wait

.PHONY: pytest
pytest: ${bin_dir}/pytest
	unset $$(cat /etc/environment | sed 's/export //' | cut -d'=' -f1) \
	&& . ${bin_dir}/activate && pipenv run pytest

.PHONY: pytest-sql
pytest-sql: ${bin_dir}/pytest
	unset $$(cat /etc/environment | sed 's/export //' | cut -d'=' -f1) \
	&& . ${bin_dir}/activate && pipenv run pytest tests/sql/sql_queries.py

.PHONY: isort
isort:
	pre-commit run --all isort

.PHONY: black
black:
	pre-commit run --all black

.PHONY: flake
flake8:
	pre-commit run --all flake8

# .PHONY: sqlfluff
# sqlfluff:
# 	pre-commit run --all sqlfluff-fix

.PHONY: lint
lint:
	pre-commit run --all

.PHONY: bandit
bandit: ${bin_dir}/airflow
	pipenv run pip install bandit
	pipenv run bandit -r dags
	pipenv run bandit -r plugins

.PHONY: safety
safety: | ${bin_dir}/activate
	. ${bin_dir}/activate && pipenv check

.PHONY: security
security: safety

.PHONY: clean
clean:
	find . -type f -name "*.pyc" -delete
	find . -name "__pycache__" -delete
	rm -rf .composer airflow.db
	pipenv clean

dev/extra-requirements.txt: Pipfile.lock | ${bin_dir}/activate
	. ${bin_dir}/activate && pipenv lock -r | grep -Ev '(#|-i)' | cut -d\; -f1 | grep -vif dev/reqs-composer.txt | sed 's:==.*:="&":g' | tee dev/extra-requirements.txt

.git/hooks/prepare-commit-msg:
	cp dev/prepare-commit-msg .git/hooks/prepare-commit-msg
	chmod +x .git/hooks/prepare-commit-msg
