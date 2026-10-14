# CLAUDE.md

TifoXR CMS: a private, role-based React admin app (React 19, MUI 7, Tailwind 3, Create React App) for restricted staff. It configures what the Unity app shows. The app is in `gms-content-management-system/`. It talks to the TifoXR backend API and deploys as an Azure Static Web App.

## Commands (run inside `gms-content-management-system/`)

```
npm start          # dev server
npm test           # Jest
npm run build      # production build
```

Build-time settings (names only): `REACT_APP_API_BASE`, `REACT_APP_API_ROOT`, `REACT_APP_CIAM_AUTHORITY`, `REACT_APP_CIAM_CLIENT_ID`, `REACT_APP_CIAM_REDIRECT_URI`.

## Rules
- The API enforces access; the UI only hides things. Roles are in `src/auth/permissions.js`.
- Never write secrets or real settings into the repo.
- **Database changes** are not made here. They are migration files in the backend repo, written with the `sql-migration` skill. Never run the database refresh on your own; ask the user first.

## Knowledge
The TifoXR vault holds architecture notes for this app: `CMS Frontend`, `Approval Workflow`, `Authentication` and `Dynamic Pull Flow` (vault folder in `$TIFOXR_VAULT`, printed at the start of the session). They were written from the code and can be wrong; check the code first.

## Plugin
Install the TifoXR Claude Code plugin from the vault repo (`node tools/setup.js` in the vault does it). It adds the session index, the database skills and the guard hooks.
