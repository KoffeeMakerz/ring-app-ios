# Create images with Apple Intelligence (Image Playground)

In the experience image picker, the **Your photos** tab has a **Create with Apple Intelligence**
button. It opens Apple's Image Playground sheet, prefilled with the vision's title and points.
The picture is made on the iPhone and saved as a private copy, like a picked photo
(`file:<uuid>.jpg`).

## Who sees it

- iPhones with Apple Intelligence switched on: iPhone 15 Pro and newer, on iOS 18.1 or later.
- Everyone else doesn't see the button (`supportsImagePlayground`), and the picker works as before.

## Why it's safe for App Review

| Risk | How it's handled |
|---|---|
| Sending personal data to a third-party AI (guideline 5.1.2(i) needs consent first) | The ChatGPT ("external provider") styles are left out. Only Apple's on-device styles are allowed: illustration, animation and sketch (`imagePlaygroundGenerationStyle`, iOS 18.4+). On iOS 18.1–18.3 there are no external styles. |
| Objectionable AI images (guideline 1.2, including the October 2026 additions) | Apple's own Image Playground filters what it makes. The images stay in the person's own private experiences: nothing is posted or shared with other users. |
| Hidden or undocumented features (2.5.19) | It's a visible, documented button. Mention it in the store description. |
| An API being removed | It uses the SwiftUI sheet. `ImageCreator` (programmatic generation) is retired in iOS 27, so it isn't used. |
| Privacy label | Nothing new is collected or sent off the phone. |

## Not possible

- Photo-realistic images: Image Playground makes stylised art only.
- Android: there's no free on-device image generation. It would need a paid cloud API.
