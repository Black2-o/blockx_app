"""
Filter links.txt down to adult (porn) domains only.

Removes mainstream / non-porn domains that get scooped up by the scraper
(search engines, social media, news, wikis, stock photos, shops, gov/edu
pages, SEO tools, etc.), then de-duplicates.

Edit NON_PORN below to add or remove domains from the block list.

Usage:
    python filter_links.py
"""

from pathlib import Path

# links.txt lives in the data/ folder next to this script.
LINKS_FILE = Path(__file__).resolve().parent / "data" / "links.txt"

# Mainstream / non-porn base domains to strip out. A line is removed when its
# host equals one of these OR ends with ".<one of these>" (so subdomains like
# music.youtube.com or in.pinterest.com are caught too).
NON_PORN = {
    # search / big tech / infra
    "google.com", "youtube.com", "apple.com", "microsoft.com", "bing.com",
    "yahoo.com", "duckduckgo.com", "play.google.com", "virustotal.com",
    "mywot.com", "archive.ph", "translate.google.com",
    # social / forums (mainstream)
    "facebook.com", "instagram.com", "twitter.com", "x.com", "tiktok.com",
    "linkedin.com", "pinterest.com", "quora.com", "discord.me", "steemit.com",
    "buzzfeed.com", "reddit.com", "itch.io", "newgrounds.com",
    # wikis / reference
    "wikipedia.org", "wiktionary.org", "wikimedia.org", "fandom.com",
    # news / magazines
    "bbc.com", "vice.com", "ritzau.dk", "news18.com", "reduxx.info",
    "rediff.com", "mensxp.com", "gqindia.com", "purewow.com", "homegrown.co.in",
    "deepdives.in",
    # music / video / media
    "scribd.com", "rumble.com", "storytel.com", "jiosaavn.com", "shazam.com",
    "deezer.com", "spotify.com", "bilibili.tv", "dailymotion.com",
    "dictionary.com",
    # SEO / research tools
    "similarweb.com", "imdb.com", "semrush.com", "researchgate.net",
    "nerdydata.com",
    # NGO / policy / privacy services
    "business-humanrights.org", "dig.watch", "joindeleteme.com",
    # security / malware / whois / downloader tools
    "mailboxvalidator.com", "whois.com", "pcrisk.com", "checksite.ai",
    "xranks.com", "yt2save.com", "ip2whois.com", "gridinsoft.com",
    "github.com", "apify.com", "scamadviser.com", "cloudflare.com",
    "he.net", "scam-detector.com", "savethevideo.com", "savesubs.com",
    "freepatentsonline.com", "kaspersky.com", "ibmcloud.com",
    "malwarebytes.com", "badassdownloader.com", "builtwith.com",
    "enigmasoftware.com", "sensorstechforum.com", "cpanel.net", "ocaml.org",
    "openstack.org", "ul.com", "supersmashflash.com", "steampowered.com",
    "deviantart.com",
    # news / media / blogs
    "phillyvoice.com", "abplive.com", "prothomalo.com", "jugantor.com",
    "channelionline.com", "dainikamadershomoy.com", "hindustantimes.com",
    "banglatribune.com", "samakal.com", "tv9bangla.com", "eisamay.com",
    "dhakapost.com", "indianexpress.com", "aajtak.in", "reclameaqui.com.br",
    "underconsideration.com", "somewhereinblog.net", "last.fm", "vkvideo.ru",
    "insomniac.com", "arminvanbuuren.com", "538.nl", "shajgoj.com",
    # companies / commerce / tourism / services
    "gea.de", "gmc.com", "dragarwal.com", "alamy.com", "andersenwindows.com",
    "admiralmarkets.com", "fastmail.com", "spain.info", "luxexpress.eu",
    "tallinn.ee", "visitestonia.com", "elisa.ee", "cramo.ee", "alexela.ee",
    "myfitness.ee", "veryimportantlot.com", "erankina-vocal.ru",
    # stock photo / creative assets
    "gettyimages.in", "shutterstock.com", "pexels.com", "unsplash.com",
    "dreamstime.com", "tenor.com", "vecteezy.com", "flickr.com", "pixabay.com",
    "bigstockphoto.com", "adobe.com", "istockphoto.com", "photodune.net",
    "mixkit.co", "videohive.net",
    # shopping / services
    "indiamart.com", "tradeindia.com", "alibaba.com", "amazon.in", "amazon.ca",
    "etsy.com", "konga.com", "dhgate.com", "made-in-china.com", "sbilife.co.in",
    "primevideo.com", "loveawake.com", "invisionfree.com", "lawrato.com",
    "tantricacademy.com", "kebapcitamer.com", "jo77.ru", "brainly.in",
    "katarzynasobolewska.com.pl",
    # institutions / companies (not caught by the gov/edu rule below)
    "ieee.org", "usp.br", "carel.com", "ostermann.eu", "pwc.co.in",
    "viewpoint.org.uk", "cipce.org.ar", "coalitionfortheicc.org",
    # not adult, VPN advert
    "vpnsites.com",
}


def is_institutional(host):
    """True for government / academic sites (…gov, …edu, …ac.<cc>)."""
    return (
        host.endswith(".gov")
        or ".gov." in host
        or host.endswith(".edu")
        or ".edu." in host
        or ".ac." in host
    )


def is_blocked(host):
    if is_institutional(host):
        return True
    for bad in NON_PORN:
        if host == bad or host.endswith("." + bad):
            return True
    return False


def filter_links():
    path = Path(LINKS_FILE)

    if not path.exists():
        print(f"{LINKS_FILE} not found.")
        return

    with open(LINKS_FILE, "r", encoding="utf-8") as f:
        domains = [line.strip().lower() for line in f if line.strip()]

    kept = []
    removed = []
    seen = set()

    for host in domains:
        if is_blocked(host):
            removed.append(host)
            continue
        if host in seen:
            continue
        seen.add(host)
        kept.append(host)

    with open(LINKS_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(kept))
        if kept:
            f.write("\n")

    print(f"Kept {len(kept)} adult domains, removed {len(removed)} non-porn.")
    if removed:
        print("\nRemoved:")
        for r in sorted(set(removed)):
            print(f"  {r}")


if __name__ == "__main__":
    filter_links()
