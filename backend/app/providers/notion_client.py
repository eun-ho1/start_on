import json
import re
import urllib.error
import urllib.request
from dataclasses import dataclass


NOTION_API_BASE_URL = "https://api.notion.com"
NOTION_API_VERSION = "2026-03-11"
DATABASE_ID_PATTERN = re.compile(
    r"[0-9a-fA-F]{8}(?:-?[0-9a-fA-F]{4}){3}-?[0-9a-fA-F]{12}",
)


class NotionClientError(Exception):
    pass


@dataclass(frozen=True)
class ResolvedNotionSource:
    database_id: str
    database_title: str
    pages: list[dict]


class NotionClient:
    def resolve_source(
        self,
        *,
        notion_api_token: str,
        database_id: str | None = None,
        database_url: str | None = None,
    ) -> ResolvedNotionSource:
        resolved_database_id = extract_database_id(
            database_id=database_id,
            database_url=database_url,
        )
        if not resolved_database_id:
            raise NotionClientError("Unable to resolve a valid Notion database identifier.")

        try:
            data_source = self.fetch_data_source(
                notion_api_token=notion_api_token,
                data_source_id=resolved_database_id,
            )
            pages = self.query_data_source_pages(
                notion_api_token=notion_api_token,
                data_source_id=resolved_database_id,
            )
            return ResolvedNotionSource(
                database_id=resolved_database_id,
                database_title=read_title_from_response(
                    data_source,
                    fallback="Notion Data Source",
                ),
                pages=pages,
            )
        except NotionClientError as error:
            if not should_fallback_to_database(error):
                raise

        database = self.fetch_database(
            notion_api_token=notion_api_token,
            database_id=resolved_database_id,
        )
        data_source_ids = extract_data_source_ids(database)
        if not data_source_ids:
            raise NotionClientError("No data sources were found for the provided Notion database.")

        pages = merge_pages_from_data_sources(
            client=self,
            notion_api_token=notion_api_token,
            data_source_ids=data_source_ids,
        )
        return ResolvedNotionSource(
            database_id=data_source_ids[0],
            database_title=read_title_from_response(
                database,
                fallback="Notion Database",
            ),
            pages=pages,
        )

    def fetch_data_source(
        self,
        *,
        notion_api_token: str,
        data_source_id: str,
    ) -> dict:
        return self._request_json(
            method="GET",
            path=f"/v1/data_sources/{data_source_id}",
            notion_api_token=notion_api_token,
        )

    def fetch_database(
        self,
        *,
        notion_api_token: str,
        database_id: str,
    ) -> dict:
        return self._request_json(
            method="GET",
            path=f"/v1/databases/{database_id}",
            notion_api_token=notion_api_token,
        )

    def query_data_source_pages(
        self,
        *,
        notion_api_token: str,
        data_source_id: str,
    ) -> list[dict]:
        pages: list[dict] = []
        start_cursor: str | None = None

        while True:
            body: dict[str, object] = {"page_size": 100}
            if start_cursor is not None:
                body["start_cursor"] = start_cursor

            response = self._request_json(
                method="POST",
                path=f"/v1/data_sources/{data_source_id}/query",
                notion_api_token=notion_api_token,
                body=body,
            )
            pages.extend(response.get("results", []))
            if response.get("has_more") is not True:
                break
            start_cursor = response.get("next_cursor")

        return pages

    def _request_json(
        self,
        *,
        method: str,
        path: str,
        notion_api_token: str,
        body: dict[str, object] | None = None,
    ) -> dict:
        request = urllib.request.Request(
            url=f"{NOTION_API_BASE_URL}{path}",
            method=method,
            headers={
                "Authorization": f"Bearer {notion_api_token.strip()}",
                "Notion-Version": NOTION_API_VERSION,
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
            data=json.dumps(body).encode("utf-8") if body is not None else None,
        )
        try:
            with urllib.request.urlopen(request) as response:
                raw_body = response.read().decode("utf-8")
        except urllib.error.HTTPError as error:
            raw_body = error.read().decode("utf-8", errors="ignore")
            try:
                payload = json.loads(raw_body) if raw_body else {}
            except json.JSONDecodeError:
                payload = {}
            code = payload.get("code")
            message = payload.get("message") or "Notion API request failed."
            raise NotionClientError(f"{error.code}:{code}:{message}") from error
        except urllib.error.URLError as error:
            raise NotionClientError("Failed to reach the Notion API.") from error

        try:
            return json.loads(raw_body) if raw_body else {}
        except json.JSONDecodeError as error:
            raise NotionClientError("Failed to decode Notion API response.") from error


def extract_database_id(
    *,
    database_id: str | None = None,
    database_url: str | None = None,
) -> str:
    for value in (database_id, database_url):
        normalized = normalize_database_id(value or "")
        if normalized:
            return normalized
    return ""


def normalize_database_id(value: str) -> str:
    match = DATABASE_ID_PATTERN.search(value.strip())
    if match is None:
        return ""

    compact = match.group(0).replace("-", "")
    return (
        f"{compact[0:8]}-"
        f"{compact[8:12]}-"
        f"{compact[12:16]}-"
        f"{compact[16:20]}-"
        f"{compact[20:32]}"
    )


def extract_data_source_ids(database_payload: dict) -> list[str]:
    data_sources = database_payload.get("data_sources", [])
    return [
        item["id"]
        for item in data_sources
        if isinstance(item, dict) and isinstance(item.get("id"), str) and item["id"]
    ]


def read_title_from_response(response: dict, *, fallback: str) -> str:
    title_items = response.get("title", [])
    title = "".join(
        item.get("plain_text", "")
        for item in title_items
        if isinstance(item, dict)
    ).strip()
    return title or fallback


def should_fallback_to_database(error: NotionClientError) -> bool:
    message = str(error)
    return (
        ":object_not_found:" in message
        or ":validation_error:" in message
        or message.startswith("404:")
    )


def merge_pages_from_data_sources(
    *,
    client: NotionClient,
    notion_api_token: str,
    data_source_ids: list[str],
) -> list[dict]:
    pages: list[dict] = []
    seen_page_ids: set[str] = set()
    for data_source_id in data_source_ids:
        results = client.query_data_source_pages(
            notion_api_token=notion_api_token,
            data_source_id=data_source_id,
        )
        for page in results:
            page_id = page.get("id")
            if not isinstance(page_id, str) or page_id in seen_page_ids:
                continue
            seen_page_ids.add(page_id)
            pages.append(page)
    return pages
