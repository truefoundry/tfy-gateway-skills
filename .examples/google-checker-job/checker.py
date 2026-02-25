"""Google.com status checker job.

Sends an HTTP GET to google.com, measures response time,
and prints a status report. Exits 0 on success, 1 on failure.
"""

import sys
import time
from datetime import datetime, timezone

import requests


URL = "https://www.google.com"


def check_google():
    start = time.monotonic()
    response = requests.get(URL, timeout=30)
    elapsed_ms = int((time.monotonic() - start) * 1000)
    response.raise_for_status()
    return response, elapsed_ms


def main():
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    try:
        response, elapsed_ms = check_google()
        print(f"===== Google.com Status Check =====")
        print(f"Timestamp:      {timestamp}")
        print(f"URL:            {URL}")
        print(f"Status Code:    {response.status_code}")
        print(f"Response Time:  {elapsed_ms}ms")
        print(f"Status:         ONLINE")
        print(f"Content Length: {len(response.content)} bytes")
        print(f"===================================")
    except Exception as exc:
        print(f"===== Google.com Status Check =====")
        print(f"Timestamp:      {timestamp}")
        print(f"URL:            {URL}")
        print(f"Status:         OFFLINE")
        print(f"Error:          {exc}")
        print(f"===================================")
        sys.exit(1)


if __name__ == "__main__":
    main()
