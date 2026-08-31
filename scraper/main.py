"""
Google Search Link Scraper

Requirements:
    pip install selenium

Create an input.txt file with one search query per line.

Example input.txt:

hello
world
python selenium
django tutorial
"""

import random
import time
from pathlib import Path

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys

# All data files live in the data/ folder next to this script, so the
# scripts work no matter which directory you run them from.
DATA_DIR = Path(__file__).resolve().parent / "data"
DATA_DIR.mkdir(exist_ok=True)

INPUT_FILE = DATA_DIR / "input.txt"
OUTPUT_FILE = DATA_DIR / "links.txt"
DONE_FILE = DATA_DIR / "completed.txt"


def build_driver(headless=False):
    options = Options()

    if headless:
        options.add_argument("--headless=new")

    options.add_argument("--window-size=1920,1080")
    options.add_argument("--disable-blink-features=AutomationControlled")

    options.add_argument(
        "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/137.0.0.0 Safari/537.36"
    )

    return webdriver.Chrome(options=options)


def read_queries():
    path = Path(INPUT_FILE)

    if not path.exists():
        path.write_text(
            "hello\nworld\npython selenium\n",
            encoding="utf-8",
        )
        print(f"{INPUT_FILE} created.")
        print("Add your search terms (one per line) and run again.")
        exit()

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        return [line.strip() for line in f if line.strip()]


def read_completed():
    """Return the set of queries already finished in previous runs."""
    path = Path(DONE_FILE)

    if not path.exists():
        return set()

    with open(DONE_FILE, "r", encoding="utf-8") as f:
        return {line.strip() for line in f if line.strip()}


def mark_completed(query):
    """Record a query as fully done so re-runs skip it."""
    with open(DONE_FILE, "a", encoding="utf-8") as f:
        f.write(query + "\n")


def collect_links(driver):
    links = []
    seen = set()

    anchors = driver.find_elements(By.XPATH, "//a[.//h3]")

    for anchor in anchors:
        href = anchor.get_attribute("href")

        if href and href.startswith("http") and href not in seen:
            seen.add(href)
            links.append(href)

    return links


def save_links(query, page, links):
    with open(OUTPUT_FILE, "a", encoding="utf-8") as f:
        f.write("=" * 80 + "\n")
        f.write(f"SEARCH : {query}\n")
        f.write(f"PAGE   : {page}\n")
        f.write("=" * 80 + "\n")

        for link in links:
            f.write(link + "\n")

        f.write("\n")


def accept_cookies(driver):
    buttons = [
        "Accept all",
        "I agree",
        "Accept",
    ]

    for text in buttons:
        try:
            driver.find_element(
                By.XPATH,
                f"//button[.//div[text()='{text}'] or text()='{text}']",
            ).click()

            time.sleep(1)
            return

        except Exception:
            pass


def search_query(driver, query):
    print(f"\nSearching: {query}")

    driver.get("https://www.google.com")

    time.sleep(random.uniform(2, 4))

    accept_cookies(driver)

    search_box = driver.find_element(By.NAME, "q")
    search_box.clear()
    search_box.send_keys(query)
    search_box.send_keys(Keys.RETURN)

    time.sleep(random.uniform(2, 4))

    page = 1

    while True:

        print(f"  Page {page}")

        links = collect_links(driver)

        save_links(query, page, links)

        print(f"    Saved {len(links)} links")

        try:
            next_button = driver.find_element(
                By.XPATH,
                "//a[@id='pnnext' or @aria-label='Next']"
            )

            driver.execute_script(
                "arguments[0].scrollIntoView({block:'center'});",
                next_button,
            )

            next_button.click()

            page += 1

            time.sleep(random.uniform(2, 5))

        except Exception:
            print("  No more pages.")
            break


def main():
    queries = read_queries()

    if not queries:
        print("No search queries found.")
        return

    # Resume support: skip queries already finished in previous runs.
    # links.txt is NEVER wiped, so all earlier results are kept.
    completed = read_completed()

    pending = [q for q in queries if q not in completed]

    if not pending:
        print("All queries already completed. Nothing to do.")
        print(f"Delete {DONE_FILE} if you want to run them again.")
        return

    print(f"{len(completed)} already done, {len(pending)} remaining.")

    driver = build_driver(headless=False)

    try:
        for i, query in enumerate(pending, start=1):
            print(f"\n[{i}/{len(pending)}]")
            search_query(driver, query)

            # Mark done only after the whole query finished successfully.
            mark_completed(query)

            # Delay before next search
            if i != len(pending):
                time.sleep(random.uniform(4, 8))

    finally:
        driver.quit()

    print("\nDone! All links have been saved to links.txt")


if __name__ == "__main__":
    main()