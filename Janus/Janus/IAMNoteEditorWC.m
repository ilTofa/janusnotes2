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
#import "NSManagedObjectContext+FetchedObjectFromURI.h"

#import "IAMFilesystemSyncController.h"

@interface IAMNoteEditorWC () <NSWindowDelegate, NSCollectionViewDelegate>

@property (strong) IBOutlet NSArrayController *arrayController;
@property (strong) IBOutlet NSCollectionView *attachmentsCollectionView;

- (IBAction)save:(id)sender;
- (IBAction)addAttachment:(id)sender;
- (IBAction)deleteAttachment:(id)sender;

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
    // The NSManagedObjectContext instance should change for a local (to the controller instance) one.
    // We need to migrate the passed object to the new moc.
    self.noteEditorMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
    [self.noteEditorMOC setParentContext:[IAMFilesystemSyncController sharedInstance].dataSyncThreadContext];
    // Prepare to receive drag & drops into CollectionView
    [self.attachmentsCollectionView registerForDraggedTypes:@[NSFilenamesPboardType]];
    [self.attachmentsCollectionView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    [self refreshAttachments];
    if(!self.editedNote) {
        // It seems that we're created without a note, that will mean that we're required to create a new one.
        Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.noteEditorMOC];
        self.editedNote = newNote;
    } else { // Get a copy of edited note into the local context.
        NSURL *uri = [[self.editedNote objectID] URIRepresentation];
        self.editedNote = (Note *)[self.noteEditorMOC objectWithURI:uri];
    }
}

- (IBAction)save:(id)sender
{
    DLog(@"This is IAMNoteWindowController's save.");
    // save (if useful) and pop back
    if([self.editedNote.title isEqualToString:@""] || [self.editedNote.text isEqualToString:@""]) {
        DLog(@"Save refused because no title ('%@') or no text ('%@')", self.editedNote.title, self.editedNote.text);
        return;
    }
    self.editedNote.timeStamp = [NSDate date];
    NSError *error;
    if(![self.noteEditorMOC save:&error])
        ALog(@"Unresolved error %@, %@", error, [error userInfo]);
    // Save on parent context
    [[IAMFilesystemSyncController sharedInstance].dataSyncThreadContext performBlock:^{
        NSError *localError;
        if(![[IAMFilesystemSyncController sharedInstance].dataSyncThreadContext save:&localError])
            ALog(@"Unresolved error saving parent context %@, %@", error, [error userInfo]);
    }];
    // If called via action
    if(sender)
        [self.window performClose:sender];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)refreshAttachments {
    self.attachmentsArray = [self.editedNote.attachment allObjects];
    [self.arrayController fetch:nil];
}

-(void) attachAttachment:(NSURL *)url {
    // Check if it is a normal file
    NSError *err;
    NSFileWrapper *fw = [[NSFileWrapper alloc] initWithURL:url options:NSFileWrapperReadingImmediate error:&err];
    if(!fw) {
        NSLog(@"Error creating file wrapper for %@: %@", url, [err description]);
        return;
    }
    // TODO: show a box to the user explaining the problem.
    if(![fw isRegularFile]) {
        NSAlert *alert = [[NSAlert alloc] init];
        NSString *message = [NSString stringWithFormat:@"The file at \"%@\" is not a \"regular\" file and cannot currently be attached to a note. Sorry for that. You can try to compress it and attach the compresssed file to the note", [url path]];
        [alert setInformativeText:message];
        [alert setMessageText:NSLocalizedString(@"Warning", @"")];
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
        return;
    }
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
    newAttachment.data = [fw regularFileContents];
//    newAttachment.data = [NSData dataWithContentsOfURL:url];
    // Now link attachment to the note
    newAttachment.note = self.editedNote;
    DLog(@"Adding attachment: %@", newAttachment);
    [self.editedNote addAttachmentObject:newAttachment];
    [self save:nil];
    [self refreshAttachments];
}

- (IBAction)deleteAttachment:(id)sender {
    if([[self.arrayController selectedObjects] count] != 0) {
        DLog(@"Delete requested for attachment: %@", [self.arrayController selectedObjects][0]);
        Attachment *toBeDeleted = [self.arrayController selectedObjects][0];
        [self.arrayController removeSelectedObjects:[self.arrayController selectedObjects]];
        [self.editedNote removeAttachmentObject:toBeDeleted];
        [self save:nil];
        [self refreshAttachments];
    }
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
        NSURL *file = [toBeOpened generateFile];
        if(![[NSWorkspace sharedWorkspace] openURL:file]) {
            NSAlert *alert = [[NSAlert alloc] init];
            NSString *message = [NSString stringWithFormat:@"No application is able to open the file \"%@\"", toBeOpened.filename];
            [alert setInformativeText:message];
            [alert setMessageText:NSLocalizedString(@"Warning", @"")];
            [alert addButtonWithTitle:@"OK"];
            [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
        }            
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
    NSURL *file = [toBeDragged generateFile];
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
