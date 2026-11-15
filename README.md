# zavi iOS 0.4.1 / build 11

Apple-only source/build kit for the existing zavi app. Run either manual GitHub
workflow (device IPA or simulator tests), or the corresponding Codemagic workflow.
No provider credentials, Apple signing materials or backend secrets are included.

The user's Android 0.4.1/build 11 APK survives, but its original source was deleted.
The supplied Android source ZIP is 0.3.0/build 9. This Apple build uses the remaining
Apple source with the same canonical contract/catalog, versioned 0.4.1/build 11.
It is not a reconstruction of all Android build 11 functionality.

Includes text/paste, per-request cloud consent and evidence results, local URL
checks, manual website sandbox checks, local image OCR/review, Action Extension
and Safari selection checks. Android notification listening, conversation
buffering and background message analysis are not implemented on iOS.

Download the device IPA after a successful device workflow and sign/install with
iLoader on Windows using your own Apple ID, keeping both extensions. A simulator
app ZIP cannot be installed on an iPhone. CI success does not prove physical
iPhone runtime, signing or Safari permissions. See apple/README.md and README_IOS.md.
