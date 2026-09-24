import os
import re
import subprocess
import sys
from urllib.parse import unquote_plus

TRACKING_KEYS = frozenset(
    """si pp feature utm_source utm_medium utm_campaign utm_term utm_content
    utm_nooverride utm_ad fbclid igshid ttclid li_fat_id mkt_tok trk gclid
    yclid dclid msclkid gbraid matchtype campaign_id ad_id ref referral
    referrer affiliate_id afid click_id clickid subid sub_id partner_id
    sr_share tag linkcode linkid ascsubtag camp creative pd_rd_i pd_rd_r
    pd_rd_w pd_rd_wg ck_subscriber_id mc_cid mc_eid _hsenc _hsmi""".split()
)
URL = re.compile(r"https?://[^\s<>\"']+")


def clean_url(match):
    url = match.group()
    base, separator, remainder = url.partition("?")
    if not separator:
        return url
    query, fragment_separator, fragment = remainder.partition("#")
    parameters = [
        parameter
        for parameter in query.split("&")
        if not (
            (key := unquote_plus(parameter.partition("=")[0]).lower()) in TRACKING_KEYS
            or key.startswith("utm_")
        )
    ]
    if parameters != query.split("&"):
        parameters = [parameter for parameter in parameters if parameter]
    return base + ("?" + "&".join(parameters) if parameters else "") + (
        fragment_separator + fragment
    )


def clean_text(text):
    return URL.sub(clean_url, text)


def self_test():
    assert clean_text("https://example.org/?si=123&v=42#part") == "https://example.org/?v=42#part"
    assert clean_text("https://example.org/?v=42&utm_custom=x&tag=abc") == "https://example.org/?v=42"
    assert clean_text("https://example.org/?fbclid=123#part") == "https://example.org/#part"
    assert clean_text("https://example.org/?si=123&") == "https://example.org/"
    assert clean_text("text?si=123 and https://example.org/?q=a%20b") == (
        "text?si=123 and https://example.org/?q=a%20b"
    )


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif os.environ.get("CLIPBOARD_STATE") != "sensitive":
        original = sys.stdin.buffer.read()
        try:
            cleaned = clean_text(original.decode("utf-8")).encode("utf-8")
        except UnicodeDecodeError:
            sys.exit(0)
        if cleaned != original:
            subprocess.run(["@wlCopy@", "--type", "text/plain;charset=utf-8"], input=cleaned, check=True)
