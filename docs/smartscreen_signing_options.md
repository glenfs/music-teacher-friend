# Solving the "Unknown Publisher" Warning on Windows

The "Unknown publisher" warning is Windows SmartScreen flagging an unsigned
executable. There are five real solutions — none free except the workaround at
the bottom. Ranked by effectiveness vs cost.

---

## 1. Microsoft Store — $19 one-time, completely eliminates the warning ⭐ best ROI

- **Cost**: $19 individual developer account, **one-time**
- **Effect**: Store-distributed apps are pre-trusted. No SmartScreen warning,
  ever. Users see "Get" instead of "download .exe".
- **Catch**: 1-2 week app review the first time. You'd need to package the exe
  as an MSIX (Godot can do this via export tooling or Inno Setup → MSIX
  conversion).
- **Why pick this first**: cheapest one-time cost, professional distribution
  surface, no recurring fee, you keep listing on itch.io too.

## 2. itch.io desktop launcher — free, bypasses SmartScreen entirely

- **Cost**: Free
- **How**: itch.io has a desktop app (itch.io app at itch.io/app) that
  downloads and runs games inside its own process. Users who install Clefira
  through the itch.io app **never see SmartScreen** because they're not
  directly running your .exe — the itch.io app is.
- **Catch**: Only works for users who install the itch.io app first. Direct
  downloads from the browser still show the warning.
- **Effort**: Zero — itch.io handles it automatically once you upload your
  build with a butler manifest.

## 3. Steam — $100 one-time per app, no SmartScreen

- **Cost**: $100 one-time via Steamworks Direct (per app)
- **Effect**: Steam-launched apps never trigger SmartScreen — Steam's process
  is trusted.
- **Catch**: Steam Direct review ~2 weeks. Steam takes 30% revenue. Worth it
  if you want the distribution.
- **Best for**: Going commercial at scale.

## 4. EV code-signing certificate — $300-500/yr, instant trust

- **Cost**: ~$300-500/yr from Sectigo / SSL.com / DigiCert
- **Effect**: SmartScreen warning replaced with "Verified publisher: Clefira"
  (or your company name). **Instant** — no reputation-building period.
- **Catch**:
  - Requires verified business (need company registration documents)
  - Cert ships on a physical USB hardware token (mandatory since June 2023)
  - Signing takes a few extra seconds per build
- **Best for**: When you have a registered business and ongoing revenue.

## 5. Standard (OV) code-signing certificate — $150-300/yr, partial fix

- **Cost**: ~$150-300/yr
- **Effect**: Properties → Digital Signatures shows your cert. But SmartScreen
  still shows the warning until your signed exe accumulates **~3000+
  downloads over months**. It eventually flips to "trusted".
- **Catch**: The wait kills early conversion. By the time reputation builds,
  you'd be on v1.3.
- **Verdict**: Skip OV — pay the extra for EV or use Microsoft Store instead.

## 6. Workaround: document the "Run anyway" step

- **Cost**: Free
- **Effect**: A clear "First-time install" page in the download instructions:
  > Windows will say "Windows protected your PC". This is expected for new
  > apps. Click **More info** → **Run anyway**.
- **Conversion cost**: real — some % of users abandon at this step
- **Best for**: Beta / free release where you don't want to spend yet

---

## Specific recommendation for Clefira

### Today (free beta on itch.io)
- Ship on itch.io with a "First-time install" note explaining the SmartScreen
  click
- Suggest users install the itch.io desktop app for a smoother experience
- **Total cost: $0**

### When you decide to charge for it (next 1-2 months)
- Spend the **$19 on Microsoft Store individual dev account** — get a real
  "Verified publisher: Clefira" badge for one-time $19, never see SmartScreen
  again
- Keep itch.io listing for "pay-what-you-want" customers
- **Total cost: $19**

### If you go commercial at scale
- Add Steam ($100/app) — the largest piano-teacher reachable audience for
  paid software is on Steam
- **Total cost: $119**

You can skip both EV and OV certs entirely if you go store-based. Code signing
only matters if you're distributing the raw `.exe` from your own website.

---

## Other notes

- **Microsoft file submission portal**: If Defender actively flags your exe
  as malware (false positive), submit at
  https://www.microsoft.com/en-us/wdsi/filesubmission for review. Free but
  takes days and doesn't fix the "Unknown publisher" warning by itself.
- **SignPath.io free tier**: Free code signing service for open-source
  projects. Requires open-sourcing the code.
- **Re-signing resets reputation**: If you switch cert vendors or your cert
  expires and you renew with a new fingerprint, SmartScreen reputation
  resets. Long-term planning matters.
- **Godot specifics**: Godot exports a single .exe + .pck pair. Both should
  be packaged together (zip or installer). Sign only the .exe — the .pck
  doesn't need it.
