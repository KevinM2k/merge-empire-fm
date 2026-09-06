#!/usr/bin/env python3
"""Reads the Console's achievement ids back into `lib/data/pgs_achievements.dart`.

    python3 tool/pgs/sync_ids.py path/to/service-account.json
    python3 tool/pgs/sync_ids.py                 # uses $GOOGLE_PLAY_SERVICE_ACCOUNT_JSON

Run it AFTER the import zip has been uploaded and the achievements published.
The import mints a `CgkI...` id for every achievement and there is no way to
choose or predict one, so the mapping in the port can only be filled in by
asking the Console what it created -- which is the one job the Publishing API
does well.

Matching is by NAME, because the Console has no idea what a local id is: the
English name in `AchievementsMetadata.csv` is the same string that comes back as
`draft.name`, and `pgs_import_test.dart` is what guarantees those names are
unique. A name edited in the Console by hand stops matching, and the run says so
rather than guessing.

Nothing is written unless every achievement the Console knows about matched
something local. `--check` reports and writes nothing, which is what CI would
run if this ever went into CI.

Auth is a service account with the `androidpublisher` scope -- the same account
`docs/RELEASE.md` already names as `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` -- and its
JWT is signed by shelling out to openssl, so this needs no pip install either.
"""

import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_import import sanitise  # noqa: E402  (same directory, no package)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAP = os.path.join(ROOT, "lib", "data", "pgs_achievements.dart")
DUMP = os.path.join(ROOT, "build", "pgs", "achievements.json")

TOKEN_URL = "https://oauth2.googleapis.com/token"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
API = "https://www.googleapis.com/games/v1configuration"


def b64(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=")


def access_token(account):
    """A service-account JWT, signed with openssl, exchanged for a token."""
    now = int(time.time())
    header = b64(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = b64(
        json.dumps(
            {
                "iss": account["client_email"],
                "scope": SCOPE,
                "aud": TOKEN_URL,
                "iat": now,
                "exp": now + 3600,
            }
        ).encode()
    )
    signing_input = header + b"." + claims
    with tempfile.NamedTemporaryFile("w", suffix=".pem", delete=False) as key:
        key.write(account["private_key"])
        key_path = key.name
    try:
        signature = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key_path],
            input=signing_input,
            capture_output=True,
            check=True,
        ).stdout
    finally:
        os.unlink(key_path)
    assertion = (signing_input + b"." + b64(signature)).decode()
    body = urllib.parse.urlencode(
        {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}
    ).encode()
    with urllib.request.urlopen(urllib.request.Request(TOKEN_URL, data=body)) as response:
        return json.load(response)["access_token"]


def application_id():
    """The PGS project number, read from the Dart pin rather than retyped."""
    source = open(os.path.join(ROOT, "lib", "data", "pgs_app_id.dart"), encoding="utf-8").read()
    return re.search(r"pgsAppIdAndroid\s*=\s*'(\d+)'", source).group(1)


def configurations(token, app_id):
    """Every achievement configuration in the application, paged."""
    items, page = [], None
    while True:
        query = {"maxResults": 200}
        if page:
            query["pageToken"] = page
        url = f"{API}/applications/{app_id}/achievements?" + urllib.parse.urlencode(query)
        request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        with urllib.request.urlopen(request) as response:
            body = json.load(response)
        items += body.get("items", [])
        page = body.get("nextPageToken")
        if not page:
            return items


def console_name(config):
    """The default-locale name, which is the key the import was built on.

    `published` is what a live achievement reads back as and `draft` is what an
    unpublished edit reads as; a freshly imported list has both, an imported but
    unpublished one has only the draft.
    """
    for half in ("published", "draft"):
        name = (config.get(half) or {}).get("name") or {}
        for translation in name.get("translations", []):
            if translation.get("locale", "").startswith("en"):
                return translation.get("value")
    return None


def main():
    check = "--check" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    path = args[0] if args else os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")
    if not path or not os.path.exists(path):
        sys.exit(
            "need the Play service-account JSON: pass its path, or set "
            "$GOOGLE_PLAY_SERVICE_ACCOUNT_JSON. It must have the "
            "androidpublisher scope and access to this game's Play Console."
        )
    if not os.path.exists(DUMP):
        sys.exit(
            f"{DUMP} is missing -- it is what maps a Console NAME back to a local "
            "id. Run: dart run tool/pgs/dump_achievements.dart > build/pgs/achievements.json"
        )

    local = {}
    for row in json.load(open(DUMP, encoding="utf-8")):
        local[sanitise(row["title"])] = row["id"]

    account = json.load(open(path, encoding="utf-8"))
    app_id = application_id()
    print(f"reading achievements for application {app_id}")
    found = configurations(access_token(account), app_id)
    print(f"  the Console has {len(found)}")

    resolved, unmatched = {}, []
    for config in found:
        name = console_name(config)
        local_id = local.get(sanitise(name)) if name else None
        if local_id is None:
            unmatched.append(name)
            continue
        resolved[local_id] = config["id"]

    if unmatched:
        print()
        print("  these Console achievements match no local achievement by name:")
        for name in unmatched:
            print(f"    {name!r}")
        print("  (renamed in the Console by hand? then rename it back, or fix the")
        print("   catalogue -- this script will not guess which is which)")

    source = open(MAP, encoding="utf-8").read()
    changed = []
    for local_id, console_id in sorted(resolved.items()):
        pattern = re.compile(r"^(  '%s': )(null|'[^']*')(,)" % re.escape(local_id), re.M)
        match = pattern.search(source)
        if not match:
            print(f"  ! {local_id} has no row in pgs_achievements.dart")
            continue
        if match.group(2) == f"'{console_id}'":
            continue
        source = pattern.sub(lambda m: f"{m.group(1)}'{console_id}'{m.group(3)}", source, count=1)
        changed.append((local_id, match.group(2), console_id))

    print()
    if not changed:
        print("  every id already matches; nothing to write")
        return
    for local_id, before, console_id in changed:
        print(f"  {local_id}: {before} -> '{console_id}'")
    if check:
        print()
        print(f"  --check: {len(changed)} rows would change; nothing written")
        sys.exit(1)
    open(MAP, "w", encoding="utf-8").write(source)
    print()
    print(f"  wrote {len(changed)} ids into {os.path.relpath(MAP, ROOT)}")
    print("  run `flutter test test/data/pgs_import_test.dart` before committing")


if __name__ == "__main__":
    main()
