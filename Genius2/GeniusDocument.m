//  GeniusDocument.m
//  Genius2
//
//  Created by John R Chang on 2005-07-02.
//  Copyright __MyCompanyName__ 2005 . All rights reserved.

#import "GeniusDocument.h"
#import "GeniusDocumentToolbar.h"

// View
#import "IconTextFieldCell.h"
#import "GeniusAtomView.h"
#import "ColorView.h"
#import "CollapsableSplitView.h"

// Model
#import "GeniusDocumentInfo.h"
#import "GeniusItem.h"	// actions
#import "GeniusAtom.h"	// -toggleColumnRichText:
#import "GeniusPreferences.h"

#import "GeniusInspectorController.h"

// Quiz
#import "QuizModel.h"
#import "QuizController.h"


@interface GeniusDocument (Private)
- (void) _handleUserDefaultsDidChange:(NSNotification *)aNotification;
- (BOOL) convertAllAtomsToRichText:(BOOL)value forAtomKey:(NSString *)atomKey;
@end


@implementation GeniusDocument

- (id)init 
{
    self = [super init];
    if (self != nil) {
        // initialization code
		_tableColumnDictionary = nil;
    }
	
    return self;
}

- (NSString *)windowNibName 
{
    return @"GeniusDocument";
}

/*
	Warning: "If you have a nib in which File's Owner is a subclass of
	NSWindowController or NSDocument, do not bind anything through file's owner."
	http://theobroma.treehouseideas.com/document.page/18
*/

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{	
    [super windowControllerDidLoadNib:windowController];
    // user interface preparation code

	/* Set up object controllers */
	[itemArrayController setManagedObjectContext:[self managedObjectContext]];
	[documentInfoController setContent:[self documentInfo]];
	
/* Window */
	// Set up window toolbar
	[self setupToolbarForWindow:[windowController window]];
	
	// Tweak window appearance
	[[windowController window] setBackgroundColor:[NSColor colorWithCalibratedWhite:(200.0/255.0) alpha:1.0]];
	NSView * bottomView = [[splitView subviews] objectAtIndex:1];
	[(ColorView *)bottomView setFrameColor:[NSColor colorWithCalibratedWhite:(170.0/255.0) alpha:1.0]];
//	[[searchField cell] setMenu:nil];
	
/* Table View */
	// Retain table columns
	_tableColumnDictionary = [NSMutableDictionary new];
	NSArray * tableColumns = [tableView tableColumns];
	NSEnumerator * tableColumnEnumerator = [tableColumns objectEnumerator];
	NSTableColumn * tableColumn;
	while ((tableColumn = [tableColumnEnumerator nextObject]))
	{
		NSString * columnTitle = [[tableColumn headerCell] stringValue];
		[(NSMutableDictionary *)_tableColumnDictionary setObject:tableColumn forKey:columnTitle];
	}

	// Remove non-default table columns
	NSArray * hiddenColumnIdentifiers = [[self documentInfo] hiddenColumnIdentifiers];
	NSEnumerator * hiddenColumnIdentifierEnumerator = [hiddenColumnIdentifiers objectEnumerator];
	NSString * identifier;
	while ((identifier = [hiddenColumnIdentifierEnumerator nextObject]))
	{
		tableColumn = [tableView tableColumnWithIdentifier:identifier];
		[tableView removeTableColumn:tableColumn];
	}

	// Set up line break mode for table columns
	tableColumn = [tableView tableColumnWithIdentifier:@"atomA"];
	[[tableColumn dataCell] setLineBreakMode:NSLineBreakByTruncatingTail];

	tableColumn = [tableView tableColumnWithIdentifier:@"atomB"];
	[[tableColumn dataCell] setLineBreakMode:NSLineBreakByTruncatingTail];
	
    // Set up icon text field cells for colored grade indication
    tableColumn = [tableView tableColumnWithIdentifier:@"grade"];
    IconTextFieldCell * cell = [IconTextFieldCell new];
    [tableColumn setDataCell:cell];
    //NSNumberFormatter * numberFormatter = [[tableColumn dataCell] formatter];
    //[cell setFormatter:numberFormatter];
	
	// Set up contextual menu on the table column headers
	[[tableView headerView] setMenu:tableColumnMenu];	

	// Set up double-click action to handle uneditable rich text cells
	[tableView setDoubleAction:@selector(_tableViewDoubleAction:)];

	// Configure list font size
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(_handleUserDefaultsDidChange:) name:NSUserDefaultsDidChangeNotification object:nil];
	[self _handleUserDefaultsDidChange:nil];

/* Split View */
	// Bind atom views
	[splitView collapseSubviewAt:1];

		// unregistered in -windowWillClose:
    [atomAView bindAtomToController:itemArrayController withKeyPath:@"selection.atomA"];	// XXX
	[atomAView addObserver:self forKeyPath:GeniusAtomViewUseRichTextAndGraphicsKey options:0L context:NULL];

    [atomBView bindAtomToController:itemArrayController withKeyPath:@"selection.atomB"];	// XXX
	[atomBView addObserver:self forKeyPath:GeniusAtomViewUseRichTextAndGraphicsKey options:0L context:NULL];

/* Misc. */
	// Set up handler to automatically make new item if user presses Return in last row
	[nc addObserver:self selector:@selector(_handleTextDidEndEditing:) name:NSTextDidEndEditingNotification object:nil];

	// -documentInfo created a new managed object, which sets the dirty bit
	[[self undoManager] removeAllActions];
}

- (void)dealloc
{
	//NSLog(@"-[GeniusDocument dealloc]");
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_tableColumnDictionary release];
	[super dealloc];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:GeniusAtomViewUseRichTextAndGraphicsKey])
	{
		if (object == atomAView)
			[self convertAllAtomsToRichText:[atomAView useRichTextAndGraphics] forAtomKey:@"atomA"];	// XXX
		else if (object == atomBView)
			[self convertAllAtomsToRichText:[atomBView useRichTextAndGraphics] forAtomKey:@"atomB"];	// XXX
	}
}


- (NSWindow *) _mainWindow
{
	NSArray * windowControllers = [self windowControllers];
	if ([windowControllers count] == 0)
		return nil;
	return [[windowControllers objectAtIndex:0] window];
}

- (void) _dismissFieldEditor
{
	NSWindow * window = [self _mainWindow];
	if ([window makeFirstResponder:window] == NO)
		[window endEditingFor:nil];
}

- (void) _handleTextDidEndEditing:(NSNotification *)aNotification
{
	NSView * textView = [aNotification object];
	if ([textView isDescendantOf:tableView])
	{
		if ([tableView selectedRow] == [tableView numberOfRows] - 1)
		{
			NSNumber * textMovement = [[aNotification userInfo] objectForKey:@"NSTextMovement"];
			int movementCode = [textMovement intValue];
			if (movementCode == NSReturnTextMovement)
			{
				[self newItem:nil];
			}
		}
	}
}

- (void) _handleUserDefaultsDidChange:(NSNotification *)aNotification
{
	[self _dismissFieldEditor];
	
	NSUserDefaults * ud = [NSUserDefaults standardUserDefaults];
	int index = [ud integerForKey:GeniusPreferencesListTextSizeModeKey];

	// IB: 11/14, 13/17  -- iTunes: 11/15, 13/18
	NSControlSize controlSize = NSMiniControlSize;
	float fontSize = [NSFont smallSystemFontSize];
	float rowHeight = fontSize + 4.0;
	if (index == 1)
	{
		controlSize = NSRegularControlSize;
		fontSize = [NSFont systemFontSize];
		rowHeight = fontSize + 5.0;
	}
	
	[tableView setRowHeight:rowHeight];

	NSEnumerator * tableColumnEnumerator = [_tableColumnDictionary objectEnumerator];
	NSTableColumn * tableColumn;
	while ((tableColumn = [tableColumnEnumerator nextObject]))
	{
		//[[tableColumn dataCell] setControlSize:controlSize];
		[[tableColumn dataCell] setFont:[NSFont systemFontOfSize:fontSize]];
	}
}

- (void) _tableViewDoubleAction:(id)sender
{
	if ([sender clickedRow] == -1)
		return;
	int clickedColumn = [sender clickedColumn];
	if ([sender clickedColumn] == -1)
		return;

	GeniusInspectorController * ic = [GeniusInspectorController sharedInspectorController];
	[ic window];	// load window

	NSTableColumn * column = [[sender tableColumns] objectAtIndex:clickedColumn];
	NSString * identifier = [column identifier];
	[[ic tabView] selectTabViewItemWithIdentifier:identifier];

	[ic showWindow:sender];
}


#if 1
- (NSError *)willPresentError:(NSError *)inError {
    // The error is a Core Data validation error if its domain is
    // NSCocoaErrorDomain and it is between the minimum and maximum
    // for Core Data validation error codes.
    if (!([[inError domain] isEqualToString:NSCocoaErrorDomain])) {
        return inError;
    }
    int errorCode = [inError code];
    if ((errorCode < NSValidationErrorMinimum) ||
                (errorCode > NSValidationErrorMaximum)) {
        return inError;
    }
    // If there are multiple validation errors, inError is an 
    // NSValidationMultipleErrorsError. If it's not, return it
    if (errorCode != NSValidationMultipleErrorsError) {
        return inError;
    }
    // For an NSValidationMultipleErrorsError, the original errors
    // are in an array in the userInfo dictionary for key NSDetailedErrorsKey
    NSArray *detailedErrors = [[inError userInfo] objectForKey:NSDetailedErrorsKey];
    // For this example, only present error messages for up to 3 validation errors at a time.
    unsigned numErrors = [detailedErrors count];
    NSMutableString *errorString = [NSMutableString stringWithFormat:@"%u validation errors have occurred", numErrors];
    if (numErrors > 3) {
        [errorString appendFormat:@".\nThe first 3 are:\n"];
    } else {
        [errorString appendFormat:@":\n"];
    }
    unsigned i, displayErrors = numErrors > 3 ? 3 : numErrors;
    for (i = 0; i < displayErrors; i++) {
        [errorString appendFormat:@"%@\n",
            [[detailedErrors objectAtIndex:i] localizedDescription]];
    }
    // Create a new error with the new userInfo
    NSMutableDictionary *newUserInfo = [NSMutableDictionary
                dictionaryWithDictionary:[inError userInfo]];
    [newUserInfo setObject:errorString forKey:NSLocalizedDescriptionKey];
    NSError *newError = [NSError errorWithDomain:[inError domain] code:[inError code] userInfo:newUserInfo];  
    return newError;
}
#endif


- (NSArrayController *) itemArrayController
{
	return itemArrayController;
}

- (GeniusDocumentInfo *) documentInfo
{
	GeniusDocumentInfo * documentInfo = nil;
		
	// Attempt to fetch pre-existing documentInfo
	NSFetchRequest * request = [[[NSFetchRequest alloc] init] autorelease];
	NSManagedObjectContext * context = [self managedObjectContext];
	NSEntityDescription * entity = [NSEntityDescription entityForName:@"GeniusDocumentInfo" inManagedObjectContext:context];
	[request setEntity:entity];
	NSError * error = nil;
	NSArray * array = [context executeFetchRequest:request error:&error];
	if (array)
	{
		int count = [array count]; // may be 0
		if (count == 1)
			documentInfo = [array objectAtIndex:0];
	}

	// Otherwise create new documentInfo
	if (documentInfo == nil)
		documentInfo = [NSEntityDescription insertNewObjectForEntityForName:@"GeniusDocumentInfo" inManagedObjectContext:context];
	
	return documentInfo;
}


- (BOOL) convertAllAtomsToRichText:(BOOL)value forAtomKey:(NSString *)atomKey
{
	// Fetch all atom objects for the specified column
	NSManagedObjectContext * context = [self managedObjectContext];
	NSFetchRequest * request = [[[NSFetchRequest alloc] init] autorelease];
	NSEntityDescription * entity = [NSEntityDescription entityForName:@"GeniusAtom" inManagedObjectContext:context];
	[request setEntity:entity];
	NSPredicate * predicate = [NSPredicate predicateWithFormat:@"key == %@", atomKey];
	[request setPredicate:predicate];
	NSError * error = nil;
	NSArray * array = [context executeFetchRequest:request error:&error];
	if (array == nil)
	{
		NSLog(@"%@", [error description]);
		return NO;
	}
		
/*	if ([array count] == 0)
		return YES;
	
	if (value == NO)
	{
		NSString * messageText = NSLocalizedString(@"Convert this column to plain text?", nil);
		NSString * informativeText = NSLocalizedString(@"If you convert this column, you will lose all text styles (such as fonts and colors) and attachments.", nil);
		NSString * defaultButton = NSLocalizedString(@"Convert", nil);
		NSString * alternateButton = NSLocalizedString(@"Cancel", nil);

		NSAlert * alert = [NSAlert alertWithMessageText:messageText defaultButton:defaultButton
			alternateButton:alternateButton otherButton:nil informativeTextWithFormat:informativeText];
		int returnCode = [alert runModal];
		if (returnCode == 0)	// No	// XXX: documentation says it's supposed to be NSAlertSecondButtonReturn
			return NO;
	}*/
	
	NSEnumerator * objectEnumerator = [array objectEnumerator];
	GeniusAtom * atom;
	while ((atom = [objectEnumerator nextObject]))
		[atom setUsesRTFDData:value];
	
	return YES;
}

@end


@implementation GeniusDocument (NSWindowDelegate)

- (void)windowWillClose:(NSNotification *)aNotification
{
	[atomAView removeObserver:self forKeyPath:GeniusAtomViewUseRichTextAndGraphicsKey];
	[atomBView removeObserver:self forKeyPath:GeniusAtomViewUseRichTextAndGraphicsKey];
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
	if ([[NSApp keyWindow] isKindOfClass:[NSPanel class]])
		[self _dismissFieldEditor];
}

@end


@implementation GeniusDocument (NSSplitViewDelegate)

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	if ([[sender subviews] indexOfObject:subview] == 1)
		return YES;
	return NO;
}

- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	return 0.0;
}

- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	return proposedMax - 100.0;
}

@end


@implementation GeniusDocument (NSTableViewDelegate)

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    NSString * identifier = [aTableColumn identifier];
    if ([identifier isEqualToString:@"grade"])
    {
        GeniusItem * item = [[itemArrayController arrangedObjects] objectAtIndex:rowIndex];		
        float grade = [[item valueForKey:@"grade"] floatValue];

        NSImage * image = nil;
        if (grade == -1)
            image = [NSImage imageNamed:@"status-red"];
        else if (grade < 0.9)
            image = [NSImage imageNamed:@"status-yellow"];
        else
            image = [NSImage imageNamed:@"status-green"];
		
        [aCell setImage:image];
    }
}


- (IBAction)delete:(id)sender
{
    NSArray * selectedObjects = [itemArrayController selectedObjects];
	if ([selectedObjects count] == 0)
	{
		NSBeep();
		return;
	}
	
    [itemArrayController removeObjects:selectedObjects];
}

@end


@implementation GeniusDocument (NSMenuValidation)

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
	// Edit menu
	if ([menuItem action] == @selector(delete:))
	{
		return [itemArrayController selectionIndex] != NSNotFound;
	}
	// Format menu
/*	else if ([menuItem action] == @selector(toggleColumnRichText:))
	{
		int tag = [menuItem tag];
		if (tag == 0)
			[menuItem setState:([[self documentInfo] isColumnARichText] ? NSOnState : NSOffState)];
		else if (tag == 1)
			[menuItem setState:([[self documentInfo] isColumnBRichText] ? NSOnState : NSOffState)];
	}*/
	// Study menu
	else if ([menuItem action] == @selector(setQuizDirectionModeAction:))
	{
		int tag = [menuItem tag];
		int quizDirectionMode = [[self documentInfo] quizDirectionMode];
		[menuItem setState:(tag == quizDirectionMode) ? NSOnState : NSOffState];
	}
	
	return [super validateMenuItem:menuItem];
}

@end


@implementation GeniusDocument (Actions)

// File menu

/*- (IBAction) exportFile:(id)sender
{
	// TO DO
}*/


// Edit menu

- (IBAction) selectSearchField:(id)sender
{
	[searchField selectText:sender];
}


// Item menu

- (IBAction) newItem:(id)sender
{
	id newObject = [itemArrayController newObject];
	[itemArrayController addObject:newObject];

	if ([[self _mainWindow] isKeyWindow] && [[self documentInfo] isColumnARichText] == NO)
	{
		int rowIndex = [[itemArrayController arrangedObjects] indexOfObject:newObject];
		[tableView editColumn:1 row:rowIndex withEvent:nil select:YES];
	}
}

- (IBAction) toggleInspector:(id)sender
{
//	[self _dismissFieldEditor];

	GeniusInspectorController * ic = [GeniusInspectorController sharedInspectorController];
	if ([[ic window] isVisible])
		[[ic window] performClose:sender];
	else
		[ic showWindow:sender];
}

- (IBAction) setItemRating:(NSMenuItem *)sender
{
	int newRating = [sender tag];
	NSNumber * newRatingValue = (newRating == 0) ? nil : [NSNumber numberWithInt:newRating];
	
	NSArray * selectedObjects = [itemArrayController selectedObjects];
	NSEnumerator * objectEnumerator = [selectedObjects objectEnumerator];
	GeniusItem * item;
	while ((item = [objectEnumerator nextObject]))
		[item setValue:newRatingValue forKey:@"myRating"];
}

/*- (IBAction) swapColumns:(id)sender
{
	// TO DO
}*/

- (IBAction) resetItemScore:(id)sender
{
	NSArray * selectedObjects = [itemArrayController selectedObjects];
	NSEnumerator * objectEnumerator = [selectedObjects objectEnumerator];
	GeniusItem * item;
	while ((item = [objectEnumerator nextObject]))
		[item resetAssociations];

	[tableView reloadData];
}


// Format menu

/*- (IBAction) toggleColumnRichText:(id)sender
{
	[self _dismissFieldEditor];
	
	BOOL value = NO;
	NSString * atomKey = nil;
	int columnIndex = [sender tag];
	if (columnIndex == 0)
	{
		value = [[self documentInfo] isColumnARichText];
		atomKey = @"atomA";	// XXX
	}
	else if (columnIndex == 1)
	{
		value = [[self documentInfo] isColumnBRichText];
		atomKey = @"atomB";	// XXX
	}

	BOOL result = [self convertAllAtomsToRichText:!value forAtomKey:atomKey];
	if (result == NO)
	{
		[sender setState:(value ? NSOnState : NSOffState)];
		return;
	}
	
	value = !value;
	if (columnIndex == 0)
		[[self documentInfo] setIsColumnARichText:value];
	else if (columnIndex == 1)
		[[self documentInfo] setIsColumnBRichText:value];
}*/


// Study menu

- (IBAction) setQuizDirectionModeAction:(NSMenuItem *)sender
{
	int tag = [sender tag];
	[[self documentInfo] setQuizDirectionMode:tag];
	
	NSArray * arrangedObjects = [itemArrayController arrangedObjects];
	NSEnumerator * objectEnumerator = [arrangedObjects objectEnumerator];
	GeniusItem * item;
	while ((item = [objectEnumerator nextObject]))
		[item flushCache];
	
	[tableView reloadData];
}

- (IBAction) runQuiz:(id)sender
{
	// XXX: let user choose number of items or time limit, initial set of associations

	QuizModel * model = [[QuizModel alloc] initWithDocument:self];
	GeniusAssociationEnumerator * associationEnumerator = [model associationEnumerator];
	[model release];

	if ([[associationEnumerator allObjects] count] == 0)
	{
		NSString * messageString = NSLocalizedString(@"There is nothing to study.", nil);
		NSString * informativeString = NSLocalizedString(@"Make sure the items you want to study are filled in and enabled, or add more items.", nil);

		NSAlert * alert = [NSAlert alertWithMessageText:messageString defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:informativeString];
		[alert beginSheetModalForWindow:[self _mainWindow] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
		return;
	}

	QuizController * quiz = [[QuizController alloc] initWithAssociationEnumerator:associationEnumerator];
	[quiz runQuiz];
	[quiz release];
}


- (IBAction) toggleFullScreen:(id)sender
{
	// do nothing - this handled by the NSUserDefaultsController in MainMenu.nib
	// defined only for automatic menu enabling
}


// table view pop-up menu

- (IBAction) toggleTableColumnShown:(NSMenuItem *)sender
{
	NSString * menuItemTitle = [sender title];
	NSTableColumn * tableColumn = [_tableColumnDictionary objectForKey:menuItemTitle];

	NSArray * hiddenColumnIdentifiers = [[self documentInfo] hiddenColumnIdentifiers];
	
	int state = [sender state];			
	if (state == NSOnState)
	{
		[tableView removeTableColumn:tableColumn];	// hide

		hiddenColumnIdentifiers = [hiddenColumnIdentifiers arrayByAddingObject:[tableColumn identifier]];
	}
	else
	{
		// TO DO: add in order
		[tableView addTableColumn:tableColumn];		// show

		hiddenColumnIdentifiers = [[hiddenColumnIdentifiers mutableCopy] autorelease];
		[(NSMutableArray *)hiddenColumnIdentifiers removeObject:[tableColumn identifier]];
	}
	
	[sender setState:(state == NSOffState ? NSOnState : NSOffState)];
	
	[[self documentInfo] setHiddenColumnIdentifiers:hiddenColumnIdentifiers];
}

@end
