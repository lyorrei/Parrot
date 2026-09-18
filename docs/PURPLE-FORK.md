# Parrot — first prototype

This fork adds a Portuguese meeting-response profile to Parrot. It is an early prototype, not a benchmarked low-latency release. The original GPL-3.0 license and attribution remain in place.

## What changed

- Ollama for live suggestions and reports, local Whisper transcription in Portuguese, cloud polish off by default. Thinking is disabled on Ollama requests so the output budget goes to the response. Custom providers retain their own defaults.
- A new **Purple — resposta rápida** profile: one concise suggested response or clarification, grounded in the call brief and the documents attached to that profile. It does not assume stakeholder names, roles or commitments.
- Portuguese question triggers, including unpunctuated questions.
- Pause cancels queued/in-flight analysis and preserves pending speech for resume.
- Failed analysis receives at most two automatic retries when no new speech arrives (five- and ten-second backoffs at Fast pace). New speech starts a fresh retry budget.
- Echo rejected/retracted from the stored transcript is also excluded/retracted from future live analysis. Previously displayed insights are not retroactively recomputed.
- If Apple sentence embeddings are unavailable, documents remain searchable through normalized keyword overlap. This fallback is local and does not understand synonyms; semantic retrieval still needs evaluation in Portuguese.
- Reimporting documents preserves identity, notes and profile assignments.
- Separate application identity, audio/index folders and Keychain service; upstream automatic updates disabled. Dependencies are locked.

## Build

Install full Xcode and select its command-line tools; the standalone Command Line Tools installation may lack SwiftDataMacros. Build through the Makefile:

```sh
make app
open dist/Parrot.app
```

The binary inside the bundle remains named Parrot. The app bundle is Parrot.app with identifier com.purplemetrics.parrot. `project.yml` is the Xcode project source of truth; run `make xcode` if you need to regenerate the checked-in upstream project. The inherited release script is disabled until fork signing and update distribution are configured.

## Try it

1. Install/start Ollama and download a model through Settings → Copilot. The lightweight fallback is llama3.2:3b. On a 48 GB Mac, the catalog also offers gemma4:26b and qwen3.6:35b-a3b. Select the model explicitly after measuring quality and speed on your Mac. Ollama 0.34.2 was used for local checks; update older servers if a model or reasoning_effort=none is unsupported.
2. Let the app download its local Whisper model and grant the macOS microphone/system-audio permissions.
3. Select **Purple — resposta rápida**. Add the account context as a TXT/Markdown/PDF in Knowledge and assign it to this profile under Profiles. A duplicated profile per account keeps documents scoped to that account; attach the documents explicitly.
4. Fill in the call brief with the account and objective. Use the template in `docs/account-brief-template.md`; unknown facts stay unknown.
5. Start a test call. The suggestion and its short justification appear in the existing Copilot UI.

The app can still be deliberately switched to cloud providers in Settings. Local inference does not hide a normal application window from desktop sharing. System capture currently mixes audio from all applications. Remote participants remain “Them” during live analysis; speaker separation runs after the call.

## Validation

```sh
scripts/test-fork.sh
DYLD_FRAMEWORK_PATH="$PWD/.build/release" make test
```

The first command compiles actual production scheduler/retrieval services against domain doubles and deterministic embeddings. It tests pause/resume (including in-flight cancellation), retry recovery/bounds, transcript retraction, Portuguese question detection, brief forwarding, document reimport and account scoping. It does not measure real model accuracy or audio latency. The full application harness and a manual audio test remain necessary before use in a real meeting.

## Next increments

Measure p50/p95 question-end to usable-response latency on the target Mac. Then add a dedicated answer inference path, token budgeting, suggestion expiry, and a premeeting cache with read-only Notion/Linear/Purple Brain sync. No connector credentials or customer data are included in this public repository. Automatic connector synchronization and streaming speaker identification are not implemented in this prototype.

## Local signing

Ad-hoc builds have no Apple Team ID. The Makefile adds the library-validation exception only to the generated signing entitlements for `SIGN_IDENTITY=-`, allowing the bundled Sparkle framework to load. Certificate-signed builds retain library validation. Hardened runtime and the app sandbox remain enabled. CI runs the signed bundle without `DYLD_FRAMEWORK_PATH` before archiving it; checking its signature alone does not prove that it can launch.

## Silence and microphone noise

Local transcription now checks raw 16 kHz audio with FluidAudio's local Silero VAD before both preview and committed Whisper decodes. This distinguishes speech from energy-only noise without blacklisting Portuguese greetings or acknowledgements. The VAD model is downloaded/cache-loaded while preparing transcription; failure prevents the local model from being marked ready. A runtime VAD error surfaces a notice and skips unchecked decoding while the original audio continues recording. This does not identify the speaker or guarantee rejection of actual speech leaking from speakers into the microphone.

Run `dist/Parrot.app/Contents/MacOS/Parrot --speech-gate-test "$PWD/dist/Parrot.app/Contents/Resources/portuguese-speech.wav"` to test the real detector against synthetic silence, hiss, DC offset, clicks, Portuguese speech at normal/quiet volume, and state leakage after speech. The fixture was synthesized using the macOS Luciana voice; it contains no meeting audio.
