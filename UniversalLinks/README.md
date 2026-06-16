# Universal Links

Deploy `apple-app-site-association` to:

```text
https://killingpart.com/.well-known/apple-app-site-association
```

Server requirements:

- Serve over HTTPS.
- Do not redirect this file.
- Do not add a `.json` extension.
- Use `application/json` or `application/pkcs7-mime` as the content type.

Fallback route:

- Route `/diaries/:diaryId` to a web fallback page.
- Redirect iOS user agents to the App Store URL configured in `APP_STORE_URL`.
- Redirect Android user agents to `PLAY_STORE_URL` when the Android app is ready.
- Show a desktop fallback page with store links for other user agents.
- For KakaoTalk and other in-app browsers, do not immediately redirect to the App Store. Show an intermediate page with an "앱에서 열기" button that opens `killingpart://diaries/:diaryId`, then fallback to the App Store if the app does not open.
- Make `HEAD /diaries/:diaryId` return a compatible status instead of `405` so link validators and crawlers do not report the route as broken.

Example in-app browser fallback logic:

```js
const APP_STORE_URL = process.env.APP_STORE_URL;

function isInAppBrowser(userAgent = "") {
  return /KAKAOTALK|Instagram|FBAN|FBAV|NAVER|Line/i.test(userAgent);
}

function appOpenFallbackPage(diaryId) {
  const appURL = `killingpart://diaries/${diaryId}`;

  return `<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>KillingPart</title>
  </head>
  <body>
    <main>
      <h1>킬링파트에서 다이어리 보기</h1>
      <button id="open-app" type="button">앱에서 열기</button>
      <a href="${APP_STORE_URL}">App Store로 이동</a>
    </main>
    <script>
      const appURL = ${JSON.stringify(appURL)};
      const storeURL = ${JSON.stringify(APP_STORE_URL)};
      document.getElementById("open-app").addEventListener("click", () => {
        window.location.href = appURL;
        window.setTimeout(() => {
          window.location.href = storeURL;
        }, 1500);
      });
    </script>
  </body>
</html>`;
}

export function handleDiaryRoute(req, res) {
  const diaryId = req.params.diaryId;
  if (!/^[1-9]\d*$/.test(diaryId)) {
    return res.status(404).send("Not Found");
  }

  const userAgent = req.headers["user-agent"] || "";
  const isIOS = /iPhone|iPad|iPod/i.test(userAgent);

  if (isIOS && isInAppBrowser(userAgent)) {
    return res.status(200).type("html").send(appOpenFallbackPage(diaryId));
  }

  if (isIOS) {
    return res.redirect(302, APP_STORE_URL);
  }

  return res.status(200).type("html").send(appOpenFallbackPage(diaryId));
}
```
