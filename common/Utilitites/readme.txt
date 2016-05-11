Why Janus?
-
Janus Notes 2 is a note-taking program for iOS and OSX that seriously respect your right to privacy.
It is named after the Latin God *Janus*, depicted as having two faces since he looks to the future and to the past. Or maybe cloud storage and privacy. Or Macintoshes and iPhone/iPad. Or sharing and control.

What does it do?
-

Basics
-
To start simply add a note and begin writing. We're supporting plain text and markdown with preview (live preview on a Macintosh).

You can add attachments to the notes and they will live side by side with your notes. On Macintosh, press '+' (or drag and drop a file) to attach it. On iOS, you can attach a picture (from library or camera), a link, or you can make a voice note. Tap the attachment to see it on iOS. Double click or right click the icon on a Mac to open or edit it.

All your data will be seamlessly synced via iCloud to every iPhone/iPad and Macintosh you have. No longer will you forget the thing you were thinking about this morning when writing that clever post on your Mac in the evening.

Collect links directly from the browser using the bookmarklet available on the app main site.


Encryption
-
The text of your notes will be encrypted on your iCloud storage to avoid eavesdroppers. The Encryption Key is set up on the preference screen. Please choose a strong password and note it somewhere. Remember that your notes will *not* be readable once you have a password! Don't lose or forget it! You've been warned. :)

The encryption password is available in clear in the software and can be freely changed. It is saved in the System Keychain and is therefore secure when the device is locked (as it should always be when not in use). The cloud storage (the real reason for encryption) is always encrypted without storing the password in the cloud. We feel this is the right balance between usability and security.

*Please be aware that the note title and the attachments are not encrypted in any case: only the note text is encrypted.*

Text is encrypted with the Apple's CommonCrypto library using AES-256 with the help of the RNCryptor library. The relevant encrypting/decrypting code fragments are available on the app website.


Privacy
-
We understand that thoughts, notes, and similar things are very personal and we try very hard to keep your data as safe as possible. The Macintosh version is fully sandboxed and has no access to anything other than the attachments you added to the notes (a copy of them is stored with the notes). The iPhone/iPad versions can be locked with a PIN, which is requested every time the app starts up.

If you're privacy-conscious, you should lock your iPhone with a code (this will encrypt the notes' cache on your iPhone) and use FileVault on your Macintosh. Remember to lock your devices when you leave them. Because we have no copy of your data, we cannot decrypt your notes in case you lose the password. Really. So, again, don't lose your password!

Both iOS and Mac apps do not "phone home" nor access anything else. There is no analytics package nor ads for this reason. That means that we have no idea on how you use the app and what is happening. Please send your feedback and suggestions to gt@iltofa.com via email or @g2fano via twitter.

Ads are served by default on iOS using the Apple's network (iAd). No additional information will be gathered by any other third party.

Thank you and _happy note taking_!
