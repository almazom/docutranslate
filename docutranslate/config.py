from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    host: str = Field(default="127.0.0.1")
    port: int = Field(default=8010, ge=1, le=65535)
    cors_enabled: bool = False
    cors_origin_regex: str = r"^(https?://.*|null|file://.*)$"
    with_mcp: bool = False
    proxy_enabled: bool = False
    cache_num: int = 10

    default_base_url: str = ""
    default_api_key: str = ""
    default_model_id: str = ""
    default_to_lang: str = "Simplified Chinese"
    default_concurrent: int = 30
    default_chunk_size: int = 4000
    default_temperature: float = 0.7
    default_top_p: float = 0.9
    default_timeout: int = 1200
    default_retry: int = 2
    default_thinking: Literal["default", "enable", "disable"] = "disable"
    default_system_proxy_enable: bool = False
    default_convert_engine: str = "mineru"
    default_mineru_token: str = ""
    default_model_version: str = "vlm"
    default_mineru_deploy_base_url: str = "http://127.0.0.1:8000"
    default_mineru_deploy_backend: str = "hybrid-auto-engine"
    default_mineru_deploy_parse_method: str = "auto"
    default_mineru_deploy_formula_enable: bool = True
    default_mineru_deploy_table_enable: bool = True
    default_mineru_deploy_start_page_id: int = 0
    default_mineru_deploy_end_page_id: int = 99999

    model_config = SettingsConfigDict(
        env_prefix="DOCUTRANSLATE_",
        env_file=".env",
        extra="ignore",
    )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
