//
//  IAMNoteWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMNoteEditorWC.h"

#import "IAMAppDelegate.h"
#import "Attachment.h"

@interface IAMNoteEditorWC () <NSWindowDelegate, NSCollectionViewDelegate>

@property (strong) IBOutlet NSArrayController *arrayController;
@property (weak) IBOutlet NSCollectionView *attachmentsCollectionView;

- (IBAction)save:(id)sender;
- (IBAction)addAttachment:(id)sender;

@end

@implementation IAMNoteEditorWC

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    // TODO: The NSManagedObjectContext instance should change for a local (to the controller instance) one.
    self.noteEditorMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
    [self.noteEditorMOC setPersistentStoreCoordinator:((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).persistentStoreCoordinator];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localContextSaved:) name:NSManagedObjectContextDidSaveNotification object:self.noteEditorMOC];
    // Prepare to receive drag & drops into CollectionView
    [self.attachmentsCollectionView registerForDraggedTypes:@[NSFilenamesPboardType]];
    [self.attachmentsCollectionView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    [self refreshAttachments];
    if(!self.editedNote) {
        // It seems that we're created without a note, that will mean that we're required to create a new one.
        Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.noteEditorMOC];
        self.editedNote = newNote;
    }
}

- (void)localContextSaved:(NSNotification *)notification {
    /* Merge the changes into the original managed object context */
    [((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
}

- (IBAction)save:(id)sender
{
    DLog(@"This is IAMNoteWindowController's save.");
    // save (if useful) and pop back
    if([self.editedNote.title isEqualToString:@""] || [[self.editedNote.attributedText string] isEqualToString:@""]) {
        DLog(@"Save refused because no text ('%@') or no title ('%@')", self.editedNote.title, [self.editedNote.attributedText string]);
        return;
    }
    self.editedNote.text = self.editedNote.attributedText.string;
    self.editedNote.timeStamp = [NSDate date];
    NSError *error;
    if(![self.noteEditorMOC save:&error])
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    // If called via action
    if(sender)
        [self.window performClose:sender];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)refreshAttachments {
    self.attachmentsArray = [self.editedNote.attachment allObjects];
    // TODO: hide collection view if no attachments?
}

-(void) attachAttachment:(NSURL *)url {
    Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.noteEditorMOC];
    
    CFStringRef fileExtension = (__bridge CFStringRef) [url pathExtension];
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
    DLog(@"FileUTI is: %@", fileUTI);
    if (UTTypeConformsTo(fileUTI, kUTTypeImage))
        newAttachment.type = @"Image";
    else if (UTTypeConformsTo(fileUTI, kUTTypeMovie))
        newAttachment.type = @"Movie";
    else if (UTTypeConformsTo(fileUTI, kUTTypeAudio))
        newAttachment.type = @"Audio";
    else if (UTTypeConformsTo(fileUTI, kUTTypeText))
        newAttachment.type = @"Text";
    else if (UTTypeConformsTo(fileUTI, kUTTypeFileURL))
        newAttachment.type = @"Link";
    else if (UTTypeConformsTo(fileUTI, kUTTypeURL))
        newAttachment.type = @"Link";
    else
        newAttachment.type = @"Other";
    newAttachment.uti = (__bridge NSString *)(fileUTI);
    CFRelease(fileUTI);
    newAttachment.extension = [url pathExtension];
    newAttachment.filename = [url lastPathComponent];
    newAttachment.data = [NSData dataWithContentsOfURL:url];
    // Now link attachment to the note
    newAttachment.note = self.editedNote;
    DLog(@"Adding attachment: %@", newAttachment);
    [self.editedNote addAttachmentObject:newAttachment];
    [self refreshAttachments];
}

- (NSURL *)writeAttachment:(Attachment *)attachment {
    NSError *error;
    NSURL *cacheDirectory = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    NSURL *cacheFile;
    if(attachment.filename)
        cacheFile = [cacheDirectory URLByAppendingPathComponent:attachment.filename];
    else
        cacheFile = [cacheDirectory URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    DLog(@"Filename will be: %@", cacheFile);
    if(![attachment.data writeToURL:cacheFile options:0 error:&error])
        NSLog(@"Error %@ writing attachment data to temporary file %@\nData: %@.", [error description], cacheFile, attachment);
    return cacheFile;
}

- (IBAction)addAttachment:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canChooseFiles = YES;
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelCancelButton) {
            DLog(@"User canceled");
        } else {
            DLog(@"User selected URL %@, now saving.", openPanel.URL);
            [self attachAttachment:openPanel.URL];
        }
    }];
}

// This event comes from the collection item view subclass
- (IBAction)collectionItemViewDoubleClick:(id)sender {
    if([[self.arrayController selectedObjects] count] != 0) {
        DLog(@"Double click detected in collection view, processing event.");
        DLog(@"Selected object array: %@", [self.arrayController selectedObjects]);
        Attachment *toBeOpened = [self.arrayController selectedObjects][0];
        NSURL *file = [self writeAttachment:toBeOpened];
        [[NSWorkspace sharedWorkspace] openURL:file];
    } else {
        NSLog(@"Double click detected in collection view, but no collection item is selected. This should not happen");
    }
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification
{
    // Rollback any unsaved change
    if([self.noteEditorMOC hasChanges])
        [self.noteEditorMOC rollback];
    // Notify delegate that we're closing ourselves
    DLog(@"Notifying delegate.");
    if(self.delegate)
        [self.delegate IAMNoteEditorWCDidCloseWindow:self];
}

#pragma mark - NSCollectionViewDelegate

- (NSDragOperation)collectionView:(NSCollectionView *)collectionView validateDrop:(id < NSDraggingInfo >)draggingInfo proposedIndex:(NSInteger *)proposedDropIndex dropOperation:(NSCollectionViewDropOperation *)proposedDropOperation {
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
    
    sourceDragMask = [draggingInfo draggingSourceOperationMask];
    pboard = [draggingInfo draggingPasteboard];
    NSDragOperation retValue = NSDragOperationNone;
    if ([[pboard types] containsObject:NSFilenamesPboardType]) {
        if (sourceDragMask & NSDragOperationCopy) {
            retValue = NSDragOperationCopy;
            // Set drop after the last element
        }
    }
    DLog(@"Dragging entered %@ position %ld for %@\nReturn value: %ld", (*proposedDropOperation == 0) ? @"on" : @"before", (long)*proposedDropIndex , [pboard types], retValue);
    return retValue;
}

- (BOOL)collectionView:(NSCollectionView *)collectionView acceptDrop:(id < NSDraggingInfo >)draggingInfo index:(NSInteger)index dropOperation:(NSCollectionViewDropOperation)dropOperation {
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
    
    sourceDragMask = [draggingInfo draggingSourceOperationMask];
    pboard = [draggingInfo draggingPasteboard];
    DLog(@"Should perform drag on %@", [pboard types]);
    
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        DLog(@"Files to be copied: %@", files);
        // Send file(s) to delegate for processing
        for (NSString *fileName in files) {
            NSURL *url = [[NSURL alloc] initFileURLWithPath:fileName];
            DLog(@"User dropped URL %@, now saving.", url);
            [self attachAttachment:url];
        }
    }

    return YES;
}

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    switch(context) {
        case NSDraggingContextOutsideApplication:
            DLog(@"Called for outside drag.");
            return NSDragOperationCopy;
            break;
            
        case NSDraggingContextWithinApplication:
        default:
            DLog(@"Called for drag inside the application.");
            return NSDragOperationNone;
            break;
    }
}

- (BOOL)collectionView:(NSCollectionView *)collectionView writeItemsAtIndexes:(NSIndexSet *)indexes toPasteboard:(NSPasteboard *)pasteboard {
    Attachment *toBeDragged = [self.arrayController arrangedObjects][indexes.firstIndex];
    DLog(@"Writing %@ to pasteboard for dragging.", toBeDragged);
    NSURL *file = [self writeAttachment:toBeDragged];
    if(file) {
        [pasteboard clearContents];
        return [pasteboard writeObjects:@[file]];
    }
    return NO;
}

#pragma mark - Bold and Italic management

- (IBAction) toggleBold:(id)sender
{
    // Should be CGEventCreateKeyboardEvent
    // Send Cmd-B Event
//    CGPostKeyboardEvent((CGCharCode)0,(CGKeyCode)55,true );
//    CGPostKeyboardEvent((CGCharCode)'B',(CGKeyCode)11,true );
//    CGPostKeyboardEvent((CGCharCode)'B',(CGKeyCode)11,false );
//    CGPostKeyboardEvent((CGCharCode)0,(CGKeyCode)55,false );
}

- (IBAction) toggleItalic:(id)sender
{
    // Send Cmd-I Event
//    CGPostKeyboardEvent((CGCharCode)0,(CGKeyCode)55,true );
//    CGPostKeyboardEvent((CGCharCode)'I',(CGKeyCode)34,true );
//    CGPostKeyboardEvent((CGCharCode)'I',(CGKeyCode)34,false );
//    CGPostKeyboardEvent((CGCharCode)0,(CGKeyCode)55,false );
}

@end
