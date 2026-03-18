# Money Money — Privacy Policy

*Last updated: March 17, 2026*

## Summary

Money Money is a personal finance app that stores all data locally on your device. We do not operate servers, collect analytics, or sell data.

## Data Storage

All financial data (accounts, transactions, budgets, goals, categories) is stored in a local SQLite database on your device. No financial data is transmitted to us or any third party without your explicit action.

## Google Drive Backup

When you opt in to Google Drive backup, the app stores a copy of your local database in your Google Drive's app-specific folder. This folder is private to Money Money and cannot be accessed by other apps or users. Only you can see or delete these backups via your Google Account. The app requests only the `drive.appdata` scope, which limits access to this app-specific folder — it cannot read or modify any other files in your Google Drive.

## AI Assistant

The AI assistant sends a snapshot of your financial data (account names and balances, recent transactions, category totals, budgets, and goals) to the LLM provider you configure. This only happens when you initiate a chat message or request AI-generated insights. The app uses a Bring Your Own Key (BYOK) model — you provide your own API key for your chosen provider (Google Gemini, Anthropic Claude, OpenAI, or a self-hosted Ollama instance). No API keys are bundled with the app. Chat history is stored locally and is never sent to us.

## SimpleFIN Bank Sync

If you connect bank accounts via SimpleFIN, the app communicates directly with the SimpleFIN API using credentials you provide. Your SimpleFIN access token is stored in your device's secure storage (Android Keystore). Transaction data retrieved from SimpleFIN is stored only in your local database.

## Data We Do Not Collect

- No analytics or telemetry (Sentry crash reporting is opt-in via build flag and sends only crash stack traces, not financial data)
- No advertising identifiers
- No location data
- No contacts or phone data
- No account numbers, routing numbers, or bank credentials are ever transmitted beyond their respective services

## Data We Do Not Share

We do not sell, rent, or share any user data with third parties. The app has no server-side component and no mechanism to collect data from your device.

## Security

- PIN authentication uses PBKDF2-HMAC-SHA256 with 256,000 iterations
- API keys and sensitive credentials are stored in Android Keystore / platform secure storage
- Release builds use code obfuscation and R8 shrinking
- All network communication uses HTTPS

## Your Control

You can delete all app data at any time by clearing the app's storage in Android Settings or uninstalling the app. Google Drive backups can be managed through your Google Account at [myaccount.google.com](https://myaccount.google.com/permissions).

## Contact

For questions about this privacy policy, open an issue at [github.com/bloknayrb/money-money](https://github.com/bloknayrb/money-money/issues).
