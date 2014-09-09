//
//  IAMTableUIWindowController.m
// Janus Notes 2
//
//  Created by Giacomo Tufano on 22/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMTableUIWindowController.h"

#import "IAMNoteEditorWC.h"
#import "IAMAppDelegate.h"
#import "NSManagedObjectContext+FetchedObjectFromURI.h"
#import "NSManagedObject+Serialization.h"
#import "Attachment.h"
#import "Books.h"
#import "INAppStoreWindow.h"

@interface IAMTableUIWindowController () <IAMNoteEditorWCDelegate, NSWindowDelegate>

@property (weak) IBOutlet NSSearchFieldCell *searchField;
@property (copy) NSArray *sortDescriptors;
@property NSPredicate *filterPredicate;
@property (copy) NSString *bookQueryPredicate;

@property (strong) IBOutlet NSArrayController *booksArrayController;

@property NSTimer *syncStatusTimer;

@property (strong) IBOutlet NSView *freeRiderView;
@property (weak) IBOutlet NSButton *freeRiderButton;

@end

@implementation IAMTableUIWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        _noteWindowControllers = [[NSMutableArray alloc] initWithCapacity:1];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self addTagWindowIfNeeded];
    [self.window setExcludedFromWindowsMenu:YES];
    [self.notesWindowMenuItem setState:NSOnState];
    [self.theTable setTarget:self];
    [self.theTable setDoubleAction:@selector(tableItemDoubleClick:)];
    self.noteEditorIsShown = @(NO);
    self.sharedManagedObjectContext = ((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).managedObjectContext;
    [self.arrayController setSortDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO]]];
}

- (void)addTagWindowIfNeeded {
    INAppStoreWindow *aWindow = (INAppStoreWindow *)[self window];
    aWindow.showsTitle = YES;
    if ([(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] skipAds]) {
        return;
    }
    // Free rider window init
    self.freeRiderView.frame = CGRectMake(NSWidth(aWindow.titleBarView.bounds) - NSWidth(self.freeRiderView.frame),
                                          (NSHeight(aWindow.titleBarView.bounds) - NSHeight(self.freeRiderView.frame)) / 2,
                                          NSWidth(self.freeRiderView.frame),
                                          NSHeight(self.freeRiderView.frame));
    NSMutableParagraphStyle *paragrapStyle = [[NSMutableParagraphStyle alloc] init];
    paragrapStyle.alignment = kCTTextAlignmentCenter;
    self.freeRiderView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    NSDictionary *attrsDictionary = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:12.0],
                                      NSForegroundColorAttributeName: [NSColor redColor],
                                      NSParagraphStyleAttributeName: paragrapStyle};
    NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] initWithString:@"Free Ride Version" attributes:attrsDictionary];
    [self.freeRiderButton setAttributedTitle:attrTitle];
    [aWindow.titleBarView addSubview:self.freeRiderView];
    DLog(@"bounds: %@\ncoords: %@", NSStringFromRect(aWindow.titleBarView.bounds), NSStringFromRect(self.freeRiderView.frame));
}

- (IBAction)showUIWindow:(id)sender {
    DLog(@"called.");
    [self.window makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
    [self.notesWindowMenuItem setState:NSOnState];
}

- (BOOL)windowShouldClose:(id)sender {
    DLog(@"Hiding main UI");
    [self.window orderOut:self];
    return NO;
}

- (void)windowWillClose:(NSNotification *)notification {
    DLog(@"Main UI closing");
    [self.notesWindowMenuItem setState:NSOffState];
}

#pragma mark - Notes Editing management

- (void)openNoteAtURI:(NSURL *)uri {
    Note *aprenda = (Note *)[self.sharedManagedObjectContext objectWithURI:uri];
    if(!aprenda) {
        ALog(@"*** Note is nil while trying to open it!");
        return;
    }
    IAMNoteEditorWC *noteEditor = [[IAMNoteEditorWC alloc] initWithWindowNibName:@"IAMNoteEditorWC"];
    [noteEditor setDelegate:self];
    [noteEditor setIdForTheNoteToBeEdited:[aprenda objectID]];
    // Preserve a reference to the controller to keep ARC happy
    [self.noteWindowControllers addObject:noteEditor];
    self.noteEditorIsShown = @(YES);
    [noteEditor showWindow:self];
}

// This event comes from the collection item view subclass
- (IBAction)tableItemDoubleClick:(id)sender {
    if([[self.arrayController selectedObjects] count] != 0) {
        DLog(@"Double click detected in table view, sending event to editNote:");
        [self editNote:sender];
    } else {
        ALog(@"Double click detected in table view, but no row is selected. This should not happen");
    }
}

- (IBAction)addNote:(id)sender {
    DLog(@"This is addNote handler in MainWindowController");
    if([(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] nagUser]) {
        return;
    }
    IAMNoteEditorWC *noteEditor = [[IAMNoteEditorWC alloc] initWithWindowNibName:@"IAMNoteEditorWC"];
    [noteEditor setDelegate:self];
    // Preserve a reference to the controller to keep ARC happy
    [self.noteWindowControllers addObject:noteEditor];
    self.noteEditorIsShown = @(YES);
    [noteEditor showWindow:self];
}

- (IBAction)editNote:(id)sender {
//    DLog(@"Selected note for editing is: %@", [self.arrayController selectedObjects][0]);
    if([(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] nagUser]) {
        return;
    }
    IAMNoteEditorWC *noteEditor = [[IAMNoteEditorWC alloc] initWithWindowNibName:@"IAMNoteEditorWC"];
    [noteEditor setDelegate:self];
    [noteEditor setIdForTheNoteToBeEdited:[[self.arrayController selectedObjects][0] objectID]];
    // Preserve a reference to the controller to keep ARC happy
    [self.noteWindowControllers addObject:noteEditor];
    self.noteEditorIsShown = @(YES);
    [noteEditor showWindow:self];
}

- (void)addNoteFromUrlWithTitle:(NSString *)title andURL:(NSString *)URL andText:(NSString *)text {
    DLog(@"Called to add a note for: %@", URL);
    IAMNoteEditorWC *noteEditor = [[IAMNoteEditorWC alloc] initWithWindowNibName:@"IAMNoteEditorWC"];
    [noteEditor setDelegate:self];
    [noteEditor setCalledFromUrl:YES];
    [noteEditor setCalledTitle:title];
    [noteEditor setCalledURL:URL];
    [noteEditor setCalledText:text];
    // Preserve a reference to the controller to keep ARC happy
    [self.noteWindowControllers addObject:noteEditor];
    self.noteEditorIsShown = @(YES);
    [noteEditor showWindow:self];
}

- (NSUInteger)countOfOpenedNotes {
    return [self.noteWindowControllers count];
}

- (void)saveAllOpenNotes {
    for (IAMNoteEditorWC *editor in self.noteWindowControllers) {
        [editor saveAndContinue:self];
    }
}

#pragma mark - Book Management

- (IBAction)showBooksAction:(id)sender {
    [self.theBookController showWindow:self];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    DLog(@"Book table changed selection");
    NSTableView *bookTable = aNotification.object;
    DLog(@"Selected row indexes: %@", bookTable.selectedRowIndexes);
    NSString __block *queryString = nil;
    NSMutableString __block *windowTitle = nil;
    [bookTable.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop){
        Books *selectedBook = self.booksArrayController.arrangedObjects[idx];
        if(queryString == nil) {
            queryString = [NSString stringWithFormat:@"book.name = \"%@\"", selectedBook.name];
            windowTitle = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"Janus Notes 2: entries in %@", selectedBook.name]];
        } else {
            queryString = [queryString stringByAppendingFormat:@" OR book.name = \"%@\"", selectedBook.name];
            [windowTitle appendFormat:@" and %@", selectedBook.name];
        }
    }];
    if (windowTitle) {
        [self.window setTitle:windowTitle];
    } else {
        [self.window setTitle:@"Janus Notes 2"];
    }
    self.bookQueryPredicate = queryString;
    DLog(@"Book query string is: %@", queryString);
    [self searched:self];
}

#pragma mark - Actions

- (IBAction)exportText:(id)sender {
    NSAssert([[self.arrayController selectedObjects] firstObject], @"No note is selected in IAMTableUIWindowController:exportHTML:. This should never happen.");
    Note *currentNote = [self.arrayController selectedObjects][0];
    NSSavePanel* panel = [NSSavePanel savePanel];
    [panel setCanCreateDirectories:YES];
    [panel setNameFieldLabel:@"Export Text To"];
    [panel setPrompt:@"Export"];
    [panel setAllowedFileTypes:@[(NSString *)kUTTypeText]];
    [panel setAllowsOtherFileTypes:YES];
    [panel setExtensionHidden:NO];
    [panel setCanSelectHiddenExtension:YES];
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        NSURL* url = [panel URL];
        DLog(@"User selected URL %@, now we should export to it.", url);
        NSError *error;
        if (![currentNote exportAsTextToURL:url error:&error]) {
            ALog(@"Error exporting file: %@", error);
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert runModal];
        }
    }];
}

- (IBAction)exportHTML:(id)sender {
    NSAssert([[self.arrayController selectedObjects] firstObject], @"No note is selected in IAMTableUIWindowController:exportHTML:. This should never happen.");
    Note *currentNote = [self.arrayController selectedObjects][0];
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanCreateDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setNameFieldLabel:@"Export HTML To"];
    [panel setPrompt:@"Export"];
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        NSURL* url = [panel URL];
        NSURL *outURL = [url URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.html", currentNote.title]];
        DLog(@"User selected URL %@, now we should export to it (%@).", url, outURL);
        NSError *error;
        if (![currentNote exportAsHTMLToURL:outURL error:&error]) {
            ALog(@"Error exporting file: %@", error);
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert runModal];
        }
    }];
}

- (IBAction)exportMarkdownForPelican:(id)sender {
    NSAssert([[self.arrayController selectedObjects] firstObject], @"No note is selected in exportMarkdownForPelican:. This should never happen.");
    Note *currentNote = [self.arrayController selectedObjects][0];
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanCreateDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setNameFieldLabel:@"Export Markdown To"];
    [panel setPrompt:@"Export"];
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        NSURL* url = [panel URL];
        DLog(@"User selected URL %@, now we should export to it.", url);
        NSError *error;
        if (![currentNote exportAsMarkdownForPelican:url error:&error]) {
            ALog(@"Error exporting markdown: %@", error);
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert runModal];
        }
    }];
}

- (IBAction)deleteNote:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setInformativeText:NSLocalizedString(@"Are you sure you want to delete the note?", nil)];
    [alert setMessageText:NSLocalizedString(@"Warning", @"")];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Delete"];
    [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)actionPreferences:(id)sender {
    [(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] preferencesAction:sender];
}

- (void) alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSAlertSecondButtonReturn)
    {
        // Delete on main moc
        NSError *error;
        DLog(@"User confirmed delete, now really deleting note: %@", ((Note *)([self.arrayController selectedObjects][0])).title);
        [self.sharedManagedObjectContext deleteObject:[self.arrayController selectedObjects][0]];
        if(![self.sharedManagedObjectContext save:&error])
            ALog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
}

- (IBAction)searched:(id)sender {
    NSString *queryString = nil;
    if(![[self.searchField stringValue] isEqualToString:@""])
    {
        // Complex NSPredicate needed to match any word in the search string
        NSArray *terms = [[self.searchField stringValue] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        for(NSString *term in terms)
        {
            if([term length] == 0)
                continue;
            if(queryString == nil)
                queryString = [NSString stringWithFormat:@"(text contains[cd] \"%@\" OR title contains[cd] \"%@\")", term, term];
            else
                queryString = [queryString stringByAppendingFormat:@" AND (text contains[cd] \"%@\" OR title contains[cd] \"%@\")", term, term];
        }
    }
    else {
        queryString = @"text  like[c] \"*\"";
    }
    if (self.bookQueryPredicate) {
        queryString = [queryString stringByAppendingFormat:@" AND (%@)", self.bookQueryPredicate];
    }
    DLog(@"Filtering on: '%@'", queryString);
    [self.arrayController setFilterPredicate:[NSPredicate predicateWithFormat:queryString]];
}

-(void)IAMNoteEditorWCDidCloseWindow:(IAMNoteEditorWC *)windowController
{
    // Note editor closed, now find and delete it from our controller array (so to allow ARC dealloc it)
    for (IAMNoteEditorWC *storedController in self.noteWindowControllers) {
        if(storedController == windowController) {
            [self.noteWindowControllers removeObject:storedController];
        }
    }
    if([self.noteWindowControllers count])
        self.noteEditorIsShown = @(YES);
    else
        self.noteEditorIsShown = @(NO);
}

// Note editor actions

- (IAMNoteEditorWC *)keyNoteEditor {
    IAMNoteEditorWC *foundController = nil;
    for (IAMNoteEditorWC *noteEditorController in self.noteWindowControllers) {
        if([noteEditorController.window isKeyWindow]) {
            foundController = noteEditorController;
            break;
        }
    }
    return foundController;
}

- (IBAction)buyFullVersion:(id)sender {
    DLog(@"Do something to buy full version!");
}

#pragma mark - Archives Management

- (IBAction)backupNotesArchive:(id)sender {
    DLog(@"called.");
    NSArray *notes = [self.arrayController arrangedObjects];
    NSMutableArray *notesToBeSerialized = [[NSMutableArray alloc] initWithCapacity:[notes count]];
    for (Note *note in notes) {
        NSDictionary *noteDict = [note toDictionary];
        [notesToBeSerialized addObject:noteDict];
    }
    NSUInteger savedNotesCount = [notesToBeSerialized count];
    if (savedNotesCount == 0) {
        return;
    }
    NSData *data=[NSKeyedArchiver archivedDataWithRootObject:notesToBeSerialized];
    DLog(@"Should save to a file %lu bytes of data", (unsigned long)[data length]);
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:@[@"it.iltofa.turms.archive"]];
    savePanel.allowsOtherFileTypes = NO;
    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelCancelButton) {
            DLog(@"User canceled");
        } else {
            DLog(@"User selected URL %@, now saving.", savePanel.URL);
            NSAlert *alert = [[NSAlert alloc] init];
            NSString *message;
            NSError *error;
            if (![data writeToURL:savePanel.URL options:NSDataWritingAtomic error:&error]) {
                message = [NSString stringWithFormat:@"Error saving data: %@", [error description]];
            } else {
                message = [NSString stringWithFormat:@"%lu notes saved in the archive. Archive is unencrypted, please store it in a secure place.", savedNotesCount];
            }
            [alert setInformativeText:message];
            [alert setMessageText:NSLocalizedString(@"Backup Operation", @"")];
            [alert addButtonWithTitle:@"OK"];
            [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
        }
    }];
}

- (void)saveNoteFromDictionary:(NSDictionary *)potentialNote {
    NSError *error;
    [NSManagedObject createManagedObjectFromDictionary:potentialNote inContext:self.sharedManagedObjectContext];
    if(![self.sharedManagedObjectContext save:&error]) {
        ALog(@"Unresolved error %@, %@", error, [error userInfo]);
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
    }
}

- (IBAction)restoreNotesArchive:(id)sender {
    DLog(@"called.");
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canChooseFiles = YES;
    [openPanel setAllowedFileTypes:@[@"it.iltofa.turms.archive", @"it.iltofa.janusarchive"]];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelCancelButton) {
            DLog(@"User canceled");
        } else {
            DLog(@"User selected URL %@, now loading.", openPanel.URL);
            NSData *data = [NSData dataWithContentsOfURL:openPanel.URL];
            NSArray *notesRead = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            NSUInteger notesInArchive, skippedNotes, savedNotes;
            notesInArchive = skippedNotes = savedNotes = 0;
            notesInArchive = [notesRead count];
            DLog(@"Read %lu objects.", (unsigned long)notesInArchive);
            NSError *error;
            NSFetchRequest *request = [[NSFetchRequest alloc] init];
            [request setEntity:[NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.sharedManagedObjectContext]];
            for (NSDictionary *potentialNote in notesRead) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uuid == %@", potentialNote[@"uuid"]];
                [request setPredicate:predicate];
                NSArray *results = [self.sharedManagedObjectContext executeFetchRequest:request error:&error];
                if (results && [results count] > 0) {
                    NSDate *potentialNoteTimestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:[potentialNote[@"dAtEaTtr:timeStamp"] doubleValue]];
                    if ([potentialNoteTimestamp compare:((Note *)results[0]).timeStamp] == NSOrderedDescending) {
                        DLog(@"%@ should be saved %@ > %@.", ((Note *)results[0]).title, potentialNoteTimestamp, ((Note *)results[0]).timeStamp);
                        [self saveNoteFromDictionary:potentialNote];
                        savedNotes++;
                    } else {
                        skippedNotes++;
                    }
                } else {
                    DLog(@"%@ should be saved because not existing on current db.", potentialNote[@"title"]);
                    [self saveNoteFromDictionary:potentialNote];
                    savedNotes++;
                }
            }
            NSAlert *alert = [[NSAlert alloc] init];
            NSString *message = [NSString stringWithFormat:@"%lu notes in archive. %lu notes imported. %lu notes skipped because already existing in an identical or newer version.", notesInArchive, savedNotes, skippedNotes];
            [alert setInformativeText:message];
            [alert setMessageText:NSLocalizedString(@"Restore Operation", @"")];
            [alert addButtonWithTitle:@"OK"];
            [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
        }
    }];
}

- (IBAction)importNotesFromJanus:(id)sender {
    DLog(@"called.");
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canChooseFiles = YES;
    [openPanel setAllowedFileTypes:@[@"it.iltofa.janusarchive"]];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelCancelButton) {
            DLog(@"User canceled");
        } else {
            DLog(@"User selected URL %@, now loading.", openPanel.URL);
            NSData *data = [NSData dataWithContentsOfURL:openPanel.URL];
            NSArray *notesRead = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            NSUInteger notesInArchive, skippedNotes, savedNotes;
            notesInArchive = skippedNotes = savedNotes = 0;
            notesInArchive = [notesRead count];
            DLog(@"Read %lu objects.", (unsigned long)notesInArchive);
            NSError *error;
            NSFetchRequest *request = [[NSFetchRequest alloc] init];
            [request setEntity:[NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.sharedManagedObjectContext]];
            for (NSDictionary *potentialNote in notesRead) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uuid == %@", potentialNote[@"uuid"]];
                [request setPredicate:predicate];
                NSArray *results = [self.sharedManagedObjectContext executeFetchRequest:request error:&error];
                if (results && [results count] > 0) {
                    NSDate *potentialNoteTimestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:[potentialNote[@"dAtEaTtr:timeStamp"] doubleValue]];
                    if ([potentialNoteTimestamp compare:((Note *)results[0]).timeStamp] == NSOrderedDescending) {
                        DLog(@"%@ should be saved %@ > %@.", ((Note *)results[0]).title, potentialNoteTimestamp, ((Note *)results[0]).timeStamp);
                        [self saveNoteFromDictionary:potentialNote];
                        savedNotes++;
                    } else {
                        skippedNotes++;
                    }
                } else {
                    DLog(@"%@ should be saved because not existing on current db.", ((Note *)results[0]).title);
                    [self saveNoteFromDictionary:potentialNote];
                    savedNotes++;
                }
            }
            NSAlert *alert = [[NSAlert alloc] init];
            NSString *message = [NSString stringWithFormat:@"%lu notes in archive. %lu notes imported. %lu notes skipped because already existing in an identical or newer version.", notesInArchive, savedNotes, skippedNotes];
            [alert setInformativeText:message];
            [alert setMessageText:NSLocalizedString(@"Restore Operation", @"")];
            [alert addButtonWithTitle:@"OK"];
            [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
        }
    }];
}

@end
