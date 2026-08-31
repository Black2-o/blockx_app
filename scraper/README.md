# Blocklist Scraper

Tools for building the adult-domain blocklist used by BlockX.

## Folder layout

```
scraper/
├── main.py           # 1. Scrapes Google search results into links
├── clean_links.py    # 2. Resolves redirects -> unique main domains
├── filter_links.py   # 3. Removes non-porn noise, de-duplicates
├── README.md
└── data/
    ├── input.txt      # search queries, one per line (you edit this)
    ├── links.txt      # the output blocklist (bare domains, one per line)
    └── completed.txt  # progress tracker so re-runs resume where they stopped
```

All scripts read/write the `data/` folder automatically, so you can run them
from anywhere (e.g. `python scraper/main.py` or from inside `scraper/`).

## Requirements

```
pip install selenium requests
```

`main.py` also needs Google Chrome installed.

## Usage

Full pipeline (only when scraping fresh data):

```
python main.py         # scrape -> data/links.txt (raw google redirect links)
python clean_links.py  # follow redirects -> unique main domains
python filter_links.py # strip mainstream/non-porn noise + de-duplicate
```

### What each script does

- **main.py** — reads queries from `data/input.txt`, searches Google, and saves
  every result link to `data/links.txt`. It never wipes previous results, and it
  records finished queries in `data/completed.txt` so an interrupted run resumes
  instead of starting over. Delete `completed.txt` to force a full re-scrape.

- **clean_links.py** — Google wraps results in encoded redirect links
  (`google.com/goto?url=...`). This follows each link to its real destination,
  reduces it to just the main domain (e.g. `example.com`), and de-duplicates.

- **filter_links.py** — removes mainstream / non-porn domains (search engines,
  social media, news, wikis, stock photos, shops, gov/edu pages, SEO tools) and
  de-duplicates. Edit the `NON_PORN` set at the top of the file to add or remove
  domains from the block list.

## Adding domains from another source

Paste the domains (or a Kotlin/JS list, a URL to scrape, etc.) and they can be
appended to `data/links.txt`, then run `filter_links.py` to clean the result.
