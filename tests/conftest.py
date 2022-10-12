import logging
import os
import pathlib
import sqlite3
import sys
import time
import typing
from unittest import mock

import docker
import MySQLdb
import pytest
from airflow.models import connection
from airflow.providers.mysql.hooks import mysql as mysql_hook
from airflow.providers.sqlite.hooks import sqlite as sqlite_hook

if typing.TYPE_CHECKING:
    from _pytest.monkeypatch import MonkeyPatch

REPO_DIR_PATH = pathlib.Path(__file__).parent.parent
sys.path.append(str(REPO_DIR_PATH))
sys.path.append(str(REPO_DIR_PATH / "plugins"))

logging.basicConfig(level="INFO")


# Before running any test, pytest will first run through every test file
#  counting how many tests are avaiable
# This process is called the test collection
#
# This function is called before the test collection
#
# Some DAGs use the env vars as global vars, so they cannot be imported
# if the env vars are not yet avaiable (like in the CI)
#
# Since some DAGs are imported during test collection (ie outside test functions),
# the collection would fail if the env vars are not present
#
# The pytest_sessionstart is called before test collection
# An autouse fixture will not suffice because fixtures are called
# after test collection and before tests
def pytest_sessionstart():
    os.environ["GCP_PROJECT_ID"] = "project_id"
    os.environ["PRIMEO_RAW_BUCKET"] = "primeo_raw_bucket"
    os.environ["PRIMEO_BACKUP_BUCKET"] = "primeo_backup_bucket"
    os.environ["MATOMO_RAW_BUCKET"] = "matomo_raw_bucket"
    os.environ["MATOMO_BACKUP_BUCKET"] = "matomo_backup_bucket"


@pytest.fixture()
def sqlite3_patch_mysql_hook(monkeypatch: "MonkeyPatch") -> sqlite3.Connection:
    sqlite_test_file = "test.db"

    monkeypatch.setattr(
        mysql_hook,
        "MySqlHook",
        mock.MagicMock(return_value=sqlite_hook.SqliteHook("some_connection_id")),
    )

    monkeypatch.setattr(
        sqlite_hook.SqliteHook,
        "get_connection",
        mock.MagicMock(
            return_value=connection.Connection(uri=f"sqlite://{sqlite_test_file}")
        ),
    )
    monkeypatch.setattr(
        sqlite_hook.SqliteHook,
        "get_conn",
        mock.MagicMock(side_effect=lambda: sqlite3.connect(sqlite_test_file)),
    )
    try:
        with sqlite3.connect(sqlite_test_file) as conn:
            yield conn
    finally:
        pathlib.Path(sqlite_test_file).unlink()


@pytest.fixture()
def docker_mysql():
    client = docker.from_env()

    container = client.containers.run(
        "mysql:8.0.28",
        detach=True,
        remove=True,
        name="pytest-mysql",
        command=["--default-authentication-plugin=mysql_native_password"],
        environment={"MYSQL_ROOT_PASSWORD": "root", "MYSQL_DATABASE": "database"},
        ports={3306: 3306},
    )

    try:
        time.sleep(20)
        with MySQLdb.connect(
            host="127.0.0.1",
            user="root",
            password="root",
            port=3306,
            database="database",
        ) as conn:
            yield conn
    finally:
        container.stop()
