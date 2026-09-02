"""Create and validate Litres cookies for the book downloader."""

from __future__ import annotations

import argparse
import json
import logging
import sys
import warnings
from pathlib import Path

import requests
from requests.utils import cookiejar_from_dict, dict_from_cookiejar

LITRES_DOMAIN = "litres.ru"
LITRES_PROFILE_MARKER = "/me/profile/"

logger = logging.getLogger(__name__)


def request_with_ssl_fallback(method: str, url: str, **kwargs):
    kwargs.setdefault("timeout", 30)
    try:
        return requests.request(method, url, verify=True, **kwargs)
    except requests.exceptions.SSLError:
        logger.warning("SSL verification failed, retrying without certificate check")
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            return requests.request(method, url, verify=False, **kwargs)


def validate_cookies_dict(cookies_dict: dict) -> bool:
    if "SID" not in cookies_dict or not cookies_dict["SID"]:
        return False

    cookies = cookiejar_from_dict(cookies_dict)
    try:
        response = request_with_ssl_fallback(
            "GET",
            f"https://www.{LITRES_DOMAIN}",
            cookies=cookies,
        )
    except requests.RequestException as exc:
        logger.error("Network error while validating cookies: %s", exc)
        return False

    if not response.ok:
        logger.error("Litres returned HTTP %s during validation", response.status_code)
        return False

    return LITRES_PROFILE_MARKER in response.text


def save_cookies(cookies_file: Path, cookies_dict: dict) -> None:
    cookies_file.parent.mkdir(parents=True, exist_ok=True)
    cookies_file.write_text(
        json.dumps({"SID": cookies_dict["SID"]}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def login_via_api(email: str, password: str) -> str:
    login_available_url = f"https://api.{LITRES_DOMAIN}/foundation/api/auth/login-available"
    response = request_with_ssl_fallback(
        "POST",
        login_available_url,
        json={"login": email},
    )
    if not response.ok:
        raise RuntimeError(
            f"Litres login check failed ({response.status_code}). "
            "Check your email or internet connection."
        )

    sid = response.headers.get("request-session-id")
    if not sid:
        raise RuntimeError("Litres did not return a session id.")

    login_url = f"https://api.{LITRES_DOMAIN}/foundation/api/auth/login"
    response = request_with_ssl_fallback(
        "POST",
        login_url,
        headers={"Session-Id": sid, "app-id": "115"},
        json={"login": email, "password": password},
    )
    if not response.ok:
        detail = response.text.strip()
        raise RuntimeError(
            f"Login failed ({response.status_code}). "
            f"Check email and password. {detail}"
        )

    return sid


def extract_sid_from_browser(browser: str) -> str:
    try:
        import browsercookie
    except ImportError as exc:
        raise RuntimeError(
            "browsercookie is not installed. Run install.bat first."
        ) from exc

    loaders = {
        "chrome": browsercookie.chrome,
        "chromium": browsercookie.chromium,
        "edge": browsercookie.edge,
        "firefox": browsercookie.firefox,
        "vivaldi": browsercookie.vivaldi,
        "safari": browsercookie.safari,
    }

    loader = loaders.get(browser)
    if loader is None:
        raise RuntimeError(f"Unsupported browser: {browser}")

    try:
        cookie_jar = loader()
    except PermissionError as exc:
        raise RuntimeError(
            f"Cannot read {browser} cookies. Close the browser completely and try again."
        ) from exc
    except Exception as exc:
        raise RuntimeError(
            f"Failed to read cookies from {browser}: {exc}"
        ) from exc

    cookies_dict = dict_from_cookiejar(cookie_jar)
    sid = cookies_dict.get("SID")
    if not sid:
        raise RuntimeError(
            f"SID cookie not found in {browser}. "
            "Open https://www.litres.ru, sign in, then run this again."
        )

    return sid


def create_and_validate(
    cookies_file: Path,
    method: str,
    email: str = "",
    password: str = "",
    browser: str = "edge",
    sid: str = "",
) -> None:
    if method == "login":
        if not email or not password:
            raise RuntimeError("Email and password are required for login method.")
        session_sid = login_via_api(email, password)
        cookies_dict = {"SID": session_sid}
    elif method == "browser":
        session_sid = extract_sid_from_browser(browser)
        cookies_dict = {"SID": session_sid}
    elif method == "manual":
        if not sid.strip():
            raise RuntimeError("SID value is required for manual method.")
        cookies_dict = {"SID": sid.strip()}
    else:
        raise RuntimeError(f"Unknown method: {method}")

    if not validate_cookies_dict(cookies_dict):
        raise RuntimeError(
            "Cookies were created but authorization check failed. "
            "Make sure you are signed in to Litres and your subscription is active."
        )

    save_cookies(cookies_file, cookies_dict)
    print(f"Cookies saved and verified: {cookies_file}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Create Litres cookies file")
    parser.add_argument(
        "--method",
        choices=["login", "browser", "manual"],
        help="Creation method",
    )
    parser.add_argument("--email", help="Litres email or phone")
    parser.add_argument("--password", help="Litres password")
    parser.add_argument(
        "--browser",
        default="edge",
        choices=["chrome", "chromium", "edge", "firefox", "vivaldi", "safari"],
    )
    parser.add_argument("--sid", help="Manual SID value")
    parser.add_argument("--cookies-file", required=True, help="Output cookies file")
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Only validate an existing cookies file",
    )
    return parser


def main() -> int:
    logging.basicConfig(
        format="%(levelname)s: %(message)s",
        level=logging.INFO,
    )

    parser = build_parser()
    args = parser.parse_args()
    cookies_file = Path(args.cookies_file)

    if args.validate_only:
        if not cookies_file.is_file():
            print(f"Cookies file not found: {cookies_file}", file=sys.stderr)
            return 1
        cookies_dict = json.loads(cookies_file.read_text(encoding="utf-8"))
        if validate_cookies_dict(cookies_dict):
            print(f"Cookies are valid: {cookies_file}")
            return 0
        print("Cookies are invalid or expired.", file=sys.stderr)
        return 1

    if not args.method:
        parser.error("--method is required unless --validate-only is used")

    try:
        create_and_validate(
            cookies_file=cookies_file,
            method=args.method,
            email=args.email or "",
            password=args.password or "",
            browser=args.browser,
            sid=args.sid or "",
        )
        return 0
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
