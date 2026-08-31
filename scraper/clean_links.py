"""
Resolve, clean & de-duplicate the scraped links file.

The scraper saves Google redirect links like:
    https://www.google.com/goto?url=CAES....   (encoded — real site hidden)

Those cannot be decoded from text; the site is only revealed by actually
following the redirect. This script:

- Follows each link to its real destination (fast HTTP request, no browser).
- Reduces it to just the MAIN domain (e.g. chotigolpobd.com), dropping
  "www.", the path, and query string.
- Keeps each domain only ONCE (uses a set), preserving first-seen order.
- Saves the clean domain list back to links.txt (overwrites in place).

Requirements:
    pip install requests

Usage:
    python clean_links.py
"""

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlparse

import requests

# links.txt lives in the data/ folder next to this script.
LINKS_FILE = Path(__file__).resolve().parent / "data" / "links.txt"

# How many links to resolve at the same time (higher = faster, but heavier).
MAX_WORKERS = 10

TIMEOUT = 15

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/137.0.0.0 Safari/537.36"
    )
}


def main_domain(url):
    """Return just the main domain of a URL, e.g. 'www.example.com/x' -> 'example.com'."""
    host = urlparse(url).netloc.lower()

    if host.startswith("www."):
        host = host[4:]

    return host


def resolve(link):
    """Follow a link to its final destination and return the main domain.

    Returns None if the link can't be reached.
    """
    try:
        r = requests.get(
            link,
            allow_redirects=True,
            timeout=TIMEOUT,
            headers=HEADERS,
            stream=True,  # don't download the whole page body
        )
        final = r.url
        r.close()
        return main_domain(final)
    except Exception:
        return None


def clean_links():
    path = Path(LINKS_FILE)

    if not path.exists():
        print(f"{LINKS_FILE} not found. Run the scraper (main.py) first.")
        return

    # Read every real link from the file (skip headers / separators / blanks).
    with open(LINKS_FILE, "r", encoding="utf-8") as f:
        raw_links = [
            line.strip()
            for line in f
            if line.strip().startswith("http")
        ]

    if not raw_links:
        print(f"No links found in {LINKS_FILE}. Run the scraper (main.py) first.")
        return

    print(f"Resolving {len(raw_links)} links...")

    # Resolve them in parallel for speed.
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        domains = list(pool.map(resolve, raw_links))

    # De-duplicate: keep each domain only once, in first-seen order.
    seen = set()
    unique = []
    failed = 0

    for domain in domains:
        if not domain:
            failed += 1
            continue

        if domain in seen:
            continue

        seen.add(domain)
        unique.append(domain)

    # Save the clean domain list back to the same file.
    with open(LINKS_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(unique))
        if unique:
            f.write("\n")

    print(f"{len(unique)} unique domains saved to {LINKS_FILE}")

    if failed:
        print(f"{failed} link(s) could not be resolved and were skipped.")


if __name__ == "__main__":
    clean_links()
