###Janus Notes 2

Janus Notes is the second version of a sync-capable notetaking app for iOS and OSX that **seriously** respects your right to privacy.

Janus Notes stores your data using strong encryption and synchronizes it across different devices using a CoreData db over iCloud. The name Janus is a reference to the ancient [Roman God Janus](https://en.wikipedia.org/wiki/Janus), depicted as having two faces since he looks to both future and past. Or perhaps, to cloud storage and privacy. Or Macs and iPhone/iPad devices. Or sharing and control.

The app is available for free in the
[Mac App Store](http://itunes.apple.com/app/id879393686) and the iOS [App Store](http://itunes.apple.com/app/id879143273). Usage notes, [FAQ](http://www.janusnotes.com/faq.html) and [screenshots](http://www.janusnotes.com/screenshots.html) are available at [janusnotes.com](http://www.janusnotes.com).

###The code

There are two Xcode 5 projects, one for iOS and the other for OS X, respectively in the IPhone and OSX subdirectories. Forks and pull requests are always welcome.

Both apps leverage the CoreData framework to store all notes and attachments. When the note texts are saved to the storage (and then synced) are encrypted with an user-defined passphrase. Encryption is performed by the [RNCryptor](https://github.com/rnapier/RNCryptor) third-party library developed by Rob Napier.

Release versions matching the binaries distributed in the Apple app stores may be built after checking out the correspondingly tagged commits in the repository. The application requires iCloud, so you'll have to wrestle with entitlements and certificate to have it really sync over iCloud.

###Credits

Janus Notes uses the following third-party frameworks and libraries:

[iRate](https://github.com/nicklockwood/iRate) Copyright 2011 Charcoal Design

[RNCryptor](https://github.com/rnapier/RNCryptor) Copyright (c) 2012 Rob Napier

[sundown](https://github.com/vmg/sundown) Copyright (c) 2009, Natacha Porté and Copyright (c) 2011, Vicent Marti

[MBProgressHUD](https://github.com/jdg/MBProgressHUD) Copyright (c) 2013 Matej Bukovinski

[AHAlertView](https://github.com/warrenm/AHAlertView) Copyright (C) 2012 Auerhaus Development, LLC

[THPinViewController](https://github.com/antiraum/THPinViewController) Copyright (c) 2014 Thomas Heß

####License

The code is available under the [MIT license](http://opensource.org/licenses/MIT).

Copyright (c) 2013 Giacomo Tufano

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
