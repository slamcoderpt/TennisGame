#!/usr/bin/env python3
"""kie.ai asset generator (stdlib only).

Reads the API key from secrets/kie_key.txt (never printed). Submits an async
generation task to the kie.ai jobs API, polls until it finishes, and downloads
the result(s) into the given output path.

Usage (image):
    py tools/kie_gen.py image --prompt "..." --out assets/generated/title.png \
        [--model nano-banana-pro] [--aspect 16:9] [--resolution 2K]

The kie.ai flow:
    POST https://api.kie.ai/api/v1/jobs/createTask   {"model","input":{...}}  -> data.taskId
    GET  https://api.kie.ai/api/v1/jobs/recordInfo?taskId=...                 -> data.state, data.resultJson
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error

BASE = "https://api.kie.ai/api/v1"
KEY_FILE = os.path.join("secrets", "kie_key.txt")


def load_key() -> str:
    if not os.path.exists(KEY_FILE):
        sys.exit("ERROR: %s not found. Put your kie.ai key there (see secrets/README.md)." % KEY_FILE)
    with open(KEY_FILE, "r", encoding="utf-8") as f:
        key = f.read().strip()
    if not key:
        sys.exit("ERROR: %s is empty." % KEY_FILE)
    return key


def _request(method: str, url: str, key: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + key)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        sys.exit("HTTP %s from %s\n%s" % (e.code, url, detail))
    except urllib.error.URLError as e:
        sys.exit("Network error calling %s: %s" % (url, e))


def create_task(key: str, model: str, input_obj: dict) -> str:
    out = _request("POST", BASE + "/jobs/createTask", key, {"model": model, "input": input_obj})
    if out.get("code") != 200:
        sys.exit("createTask failed: %s" % json.dumps(out))
    data = out.get("data") or {}
    task_id = data.get("taskId") or data.get("task_id")
    if not task_id:
        sys.exit("createTask returned no taskId: %s" % json.dumps(out))
    return task_id


def poll(key: str, task_id: str, timeout_s: int = 300) -> list[str]:
    deadline = time.time() + timeout_s
    last = ""
    while time.time() < deadline:
        out = _request("GET", BASE + "/jobs/recordInfo?taskId=" + task_id, key)
        data = out.get("data") or {}
        state = data.get("state", "")
        if state != last:
            print("  state: %s (progress %s)" % (state, data.get("progress", "-")))
            last = state
        if state == "success":
            result = json.loads(data.get("resultJson") or "{}")
            urls = result.get("resultUrls") or result.get("result_urls") or []
            if not urls:
                sys.exit("Task succeeded but no resultUrls: %s" % data.get("resultJson"))
            print("  credits consumed: %s" % data.get("creditsConsumed", "?"))
            return urls
        if state == "fail":
            sys.exit("Task failed: %s %s" % (data.get("failCode"), data.get("failMsg")))
        time.sleep(4)
    sys.exit("Timed out after %ss waiting for task %s" % (timeout_s, task_id))


def download(url: str, out_path: str) -> None:
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    # The result CDN 403s the default urllib UA, so send a browser-like one.
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=120) as resp, open(out_path, "wb") as f:
        f.write(resp.read())
    print("  saved -> %s" % out_path)


def cmd_image(args) -> None:
    key = load_key()
    input_obj = {"prompt": args.prompt, "aspect_ratio": args.aspect, "resolution": args.resolution}
    print("Submitting image task (model=%s)..." % args.model)
    task_id = create_task(key, args.model, input_obj)
    print("  taskId: %s" % task_id)
    urls = poll(key, task_id)
    if len(urls) == 1:
        download(urls[0], args.out)
    else:
        base, ext = os.path.splitext(args.out)
        for i, u in enumerate(urls):
            download(u, "%s_%d%s" % (base, i + 1, ext))


def cmd_fetch(args) -> None:
    # Download the result of an already-finished task (no new credits spent).
    key = load_key()
    print("Fetching task %s..." % args.task)
    urls = poll(key, args.task, timeout_s=120)
    if len(urls) == 1:
        download(urls[0], args.out)
    else:
        base, ext = os.path.splitext(args.out)
        for i, u in enumerate(urls):
            download(u, "%s_%d%s" % (base, i + 1, ext))


def main() -> None:
    ap = argparse.ArgumentParser(description="kie.ai asset generator")
    sub = ap.add_subparsers(dest="cmd", required=True)
    img = sub.add_parser("image", help="text-to-image")
    img.add_argument("--prompt", required=True)
    img.add_argument("--out", required=True)
    img.add_argument("--model", default="gpt-image-2-text-to-image")
    img.add_argument("--aspect", default="16:9")
    img.add_argument("--resolution", default="2K")
    img.set_defaults(func=cmd_image)
    fet = sub.add_parser("fetch", help="download an already-finished task by id")
    fet.add_argument("--task", required=True)
    fet.add_argument("--out", required=True)
    fet.set_defaults(func=cmd_fetch)
    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
