# Shared posts and group changes

Deploy the backend and rebuilt website together with the new Android app.

- Group creation now saves an active creator membership; creator ownership is the group admin authority. Legacy creators are reported as active without a data migration.
- Pending group join requests notify the group creator, with approval/rejection restricted to that creator. Auto-approved requests do not notify for approval.
- Shares use https://highlanders.app/post/<postId>. The Android app queues the destination until login/signup finishes. The browser fallback opens Google Play for package com.highlander, carrying the post in the install referrer. The app stores that destination until the post screen opens.

## Domain verification

The supplied Play signing SHA-256 is configured in `../public/.well-known/assetlinks.json` for package `com.highlander`:

`56:49:0A:90:7E:68:7A:DF:08:5E:EA:7C:5F:3F:5F:83:12:3D:A6:EE:31:63:95:6D:70:BB:54:AC:64:86:72:82`

The backend serves this generated file by default. ANDROID_APP_LINK_SHA256 can override it; multiple fingerprints can be separated by commas. Future certificate updates must use Play Console > App integrity > App signing key certificate (not only the upload certificate).

The public URL https://highlanders.app/.well-known/assetlinks.json must return the generated JSON directly, without login or redirects. The website build copies the configured file into dist/.well-known/assetlinks.json; deploy that directory too. To regenerate it, run scripts/generate-assetlinks.cjs with ANDROID_APP_LINK_SHA256 set before the website build. The server also exposes that endpoint.

Set PUBLIC_WEB_URL=https://highlanders.app in the backend if an older value is configured. Publish the new app to Google Play under com.highlander; referrer recovery requires a Google Play install via the shared store link.

## Device acceptance checks

1. Create a group as user A. It appears joined, with settings/admin access and one member. User B requests to join; only A gets the request notification and can approve/reject it.
2. With the app installed, tap a shared HTTPS post link from WhatsApp while signed in, signed out, and during signup. The exact post opens after authentication; Back returns to the app.
3. Without the app, tap the link, install via its Google Play fallback, then sign in/signup. Confirm the original post opens. Relaunch after consuming it; it must not reopen again.
4. Check Android domain verification with adb shell pm get-app-links com.highlander. Repeat the install test using a Play internal/closed testing release signed with the Play app signing key.
