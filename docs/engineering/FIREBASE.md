

---

# Cloud Functions

Source: `functions/`, registered in `firebase.json` under `functions`.

Deployed functions:

verifyNightPass — IAP receipt validation (v1)

finalizeEndedSeasons — scheduled season rollover (v1)

manualFinalizeSeason — operator escalation (v1)

onMatchCompleted — server-authoritative progression (v2)

## Version constraints

`firebase-functions` is pinned to `^6`. Version 7 removes `functions.config()`,
which the emulator's v1 runtime calls while loading any v1 trigger — under v7
the entire functions module fails to load and no trigger runs, including v2
ones. Until `verifyNightPass`, `finalizeEndedSeasons` and
`manualFinalizeSeason` are migrated to v2, the pin must stay.

New functions should be written against the v2 API.

## Admin SDK imports

Use the modular entry points (`firebase-admin/firestore`). With
`esModuleInterop`, `admin.firestore.FieldValue` resolves to `undefined` at
runtime under firebase-admin v13 and fails only once a write executes.

## Testing

```
npm --prefix functions test                       # pure reward logic
firebase emulators:exec --only firestore --project demo-bufon \
  "cd firestore-tests && npm test"                # security rules
firebase emulators:exec --only firestore,functions --project demo-bufon \
  "node --test functions/integration.test.mjs"    # progression end to end
```
