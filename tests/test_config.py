import pytest

from config import IntegrationConfig, load_integration_config

REQUIRED_ENV = {
    "CP_SQL_SERVER": "ADWPC-MAIN",
    "CP_SQL_DATABASE": "WOODYS_CP",
    "CP_SQL_DRIVER": "ODBC Driver 18 for SQL Server",
    "CP_SQL_TRUSTED_CONN": "true",
    "CP_SQL_TIMEOUT": "45",
    "WOO_BASE_URL": "https://example.com",
    "WOO_CONSUMER_KEY": "ck_test",
    "WOO_CONSUMER_SECRET": "cs_test",
}


def set_env(monkeypatch, overrides: dict[str, str] | None = None) -> None:
    monkeypatch.delenv("CP_SQL_USERNAME", raising=False)
    monkeypatch.delenv("CP_SQL_PASSWORD", raising=False)
    data = REQUIRED_ENV.copy()
    if overrides:
        data.update(overrides)
    for key, value in data.items():
        monkeypatch.setenv(key, value)


def test_load_config_requires_sql_server(monkeypatch):
    set_env(monkeypatch, {"CP_SQL_SERVER": ""})
    with pytest.raises(ValueError):
        load_integration_config()


def test_load_config_trusted_connection_default(monkeypatch):
    set_env(monkeypatch)
    config = load_integration_config()
    assert config.database.trusted_connection is True
    assert config.database.server == REQUIRED_ENV["CP_SQL_SERVER"]
    assert config.database.timeout == int(REQUIRED_ENV["CP_SQL_TIMEOUT"])
    assert config.woo.base_url == "https://example.com"


def test_load_config_sql_auth(monkeypatch):
    overrides = {
        "CP_SQL_TRUSTED_CONN": "false",
        "CP_SQL_USERNAME": "cp_user",
        "CP_SQL_PASSWORD": "secret",
    }
    set_env(monkeypatch, overrides)
    config = load_integration_config()
    assert config.database.trusted_connection is False
    assert config.database.username == "cp_user"
    assert config.database.password == "secret"

