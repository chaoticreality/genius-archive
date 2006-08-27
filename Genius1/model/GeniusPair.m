//  Genius
//
//  This code is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 2.5 License.
//  http://creativecommons.org/licenses/by-nc-sa/2.5/

#import "GeniusPair.h"


NSString * GeniusAssociationScoreNumberKey = @"scoreNumber";
NSString * GeniusAssociationDueDateKey = @"dueDate";

NSString * GeniusPairImportanceNumberKey = @"importanceNumber";
NSString * GeniusPairCustomTypeStringKey = @"customTypeString";
NSString * GeniusPairCustomGroupStringKey = @"customGroupString";
NSString * GeniusPairNotesStringKey = @"notesString";


@interface GeniusAssociation (Private)
- (id) _initWithCueItem:(GeniusItem *)cueItem answerItem:(GeniusItem *)answerItem parentPair:(GeniusPair *)parentPair performanceDict:(NSDictionary *)performanceDict;
@end

@implementation GeniusAssociation

+ (void)initialize
{
    [super initialize];
    [self setKeys:[NSArray arrayWithObjects:@"scoreNumber", @"dueDate", nil] triggerChangeNotificationsForDependentKey:@"dirty"];
}

/*+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey
{
    return NO;
}*/


- (id) _initWithCueItem:(GeniusItem *)cueItem answerItem:(GeniusItem *)answerItem parentPair:(GeniusPair *)parentPair performanceDict:(NSDictionary *)performanceDict
{
    self = [super init];
    _cueItem = [cueItem retain];
    _answerItem = [answerItem retain];
    _parentPair = [parentPair retain];
    
    if (performanceDict)
        _perfDict = [performanceDict mutableCopy];
    else
        _perfDict = [NSMutableDictionary new];
    return self;
}

- (void) dealloc
{
    [_cueItem release];
    [_answerItem release];
    [_parentPair release];
    
    [_perfDict release];
    [super dealloc];
}


- (GeniusItem *) cueItem
{
    return _cueItem;
}

- (GeniusItem *) answerItem
{
    return _answerItem;
}

- (GeniusPair *) parentPair
{
    return _parentPair;
}


- (NSDictionary *) performanceDictionary
{
    return _perfDict;
}

- (void) reset
{
    [self willChangeValueForKey:GeniusAssociationScoreNumberKey];
    [self willChangeValueForKey:GeniusAssociationDueDateKey];
    [_perfDict removeAllObjects];
    [self didChangeValueForKey:GeniusAssociationScoreNumberKey];
    [self didChangeValueForKey:GeniusAssociationDueDateKey];
}

// Resets the following fields
- (int) score
{
    NSNumber * scoreNumber = [self scoreNumber];
    if (scoreNumber == nil)
        return -1;
    else
        return [scoreNumber intValue];
}

- (void) setScore:(int)score
{
    NSNumber * scoreNumber;
    if (score == -1)
        scoreNumber = nil;
    else
        scoreNumber = [NSNumber numberWithInt:score];

    [self setScoreNumber:scoreNumber];
}

// Equivalent object-based methods used by key bindings
- (NSNumber *) scoreNumber
{
    id scoreNumber = [_perfDict objectForKey:GeniusAssociationScoreNumberKey];
    if ([scoreNumber isKindOfClass:[NSNumber class]])
        return scoreNumber;
    return nil;
}

- (void) setScoreNumber:(id)scoreObject
{
    // WORKAROUND: -initWithTabularText:order: passes us strings, so NSString -> NSNumber
    NSNumber * scoreNumber = scoreObject;
    if (scoreObject && [scoreObject isKindOfClass:[NSString class]] && [scoreObject isEqualToString:@""] == NO)
        scoreNumber = [NSNumber numberWithInt:[scoreObject intValue]];

    [_perfDict setValue:scoreNumber forKey:GeniusAssociationScoreNumberKey];
}

/*- (unsigned int) right
{
    NSNumber * rightNumber = [_perfDict objectForKey:@"right"];
    return (rightNumber ? [rightNumber unsignedIntValue] : 0);
}

- (void) setRight:(unsigned int)right
{
    [_perfDict setObject:[NSNumber numberWithUnsignedInt:right] forKey:@"right"];

    [self _setDirty];
}

- (unsigned int) wrong
{
    NSNumber * wrongNumber = [_perfDict objectForKey:@"wrong"];
    return (wrongNumber ? [wrongNumber unsignedIntValue] : 0);
}

- (void) setWrong:(unsigned int)wrong
{
    [_perfDict setObject:[NSNumber numberWithUnsignedInt:wrong] forKey:@"wrong"];

    [self _setDirty];
}*/

- (NSDate *) dueDate
{
    return [_perfDict objectForKey:GeniusAssociationDueDateKey];
}

- (void) setDueDate:(NSDate *)dueDate
{
    [_perfDict setValue:dueDate forKey:GeniusAssociationDueDateKey];
}


- (NSComparisonResult) compareByDate:(GeniusAssociation *)association
{
    NSDate * date1 = [self dueDate];
    NSDate * date2 = [association dueDate];
    if (date1 == nil)
        return NSOrderedAscending;  // 0 <
    if (date2 == nil)
        return NSOrderedDescending; // > 0
    return [date1 compare:date2];
}

- (NSComparisonResult) compareByScore:(GeniusAssociation *)association
{
    NSNumber * scoreNumber1 = [self scoreNumber];
    NSNumber * scoreNumber2 = [association scoreNumber];
    if (scoreNumber1 == nil)
        return NSOrderedAscending;  // 0 <
    if (scoreNumber2 == nil)
        return NSOrderedDescending; // > 0
    return [scoreNumber1 compare:scoreNumber2];
}

@end


const int kGeniusPairDisabledImportance = -1;
const int kGeniusPairMinimumImportance = 0;
const int kGeniusPairNormalImportance = 5;
const int kGeniusPairMaximumImportance = 10;

@interface GeniusPair (Private)
- (id) _initWithCueItem:(GeniusItem *)cueItem answerItem:(GeniusItem *)answerItem;
@end

@implementation GeniusPair

+ (void)initialize
{
    [super initialize];
    [self setKeys:[NSArray arrayWithObjects:@"disabled", nil] triggerChangeNotificationsForDependentKey:@"importance"];
    [self setKeys:[NSArray arrayWithObjects:@"importance", @"customGroupString", @"customTypeString", @"notesString", nil] triggerChangeNotificationsForDependentKey:@"dirty"];
}

/*+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey
{
    return NO;
    if ([theKey isEqualToString:@"itemA"])
        return NO;
    else if ([theKey isEqualToString:@"itemB"])
        return NO;
    else
        return [super automaticallyNotifiesObserversForKey:theKey];
}*/

+ (NSArray *) associationsForPairs:(NSArray *)pairs useAB:(BOOL)useAB useBA:(BOOL)useBA
{
    NSMutableArray * allPairs = [NSMutableArray array];
    NSEnumerator * pairEnumerator = [pairs objectEnumerator];
    GeniusPair * pair;
    while ((pair = [pairEnumerator nextObject]))
    {
        if ([pair disabled])
            continue;
            
        if (useAB)
            [allPairs addObject:[pair associationAB]];
        if (useBA)
            [allPairs addObject:[pair associationBA]];
    }
    return allPairs;
}


- (id) init
{
    self = [super init];

    GeniusItem * itemA = [GeniusItem new];
    GeniusItem * itemB = [GeniusItem new];
    _associationAB = [[GeniusAssociation alloc] _initWithCueItem:itemA answerItem:itemB parentPair:self performanceDict:nil];
    _associationBA = [[GeniusAssociation alloc] _initWithCueItem:itemB answerItem:itemA parentPair:self performanceDict:nil];
    [itemA release];
    [itemB release];
    _userDict = [NSMutableDictionary new];

    [itemA addObserver:self forKeyPath:@"dirty" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
    [itemB addObserver:self forKeyPath:@"dirty" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
    [_associationAB addObserver:self forKeyPath:@"dirty" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
    [_associationBA addObserver:self forKeyPath:@"dirty" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];

    return self;
}

- (void) dealloc
{
    [_associationAB release];
    [_associationBA release];
    [_userDict release];

    [[self itemA] removeObserver:self forKeyPath:@"dirty"];
    [[self itemB] removeObserver:self forKeyPath:@"dirty"];
    [_associationAB removeObserver:self forKeyPath:@"dirty"];
    [_associationBA removeObserver:self forKeyPath:@"dirty"];

    [super dealloc];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSAssert([coder allowsKeyedCoding], @"allowsKeyedCoding");
        
    self = [super init];
    GeniusItem * itemA = [coder decodeObjectForKey:@"itemA"];
    GeniusItem * itemB  = [coder decodeObjectForKey:@"itemB"];
    NSDictionary * performanceDictAB = [coder decodeObjectForKey:@"performanceDictAB"];
    NSDictionary * performanceDictBA = [coder decodeObjectForKey:@"performanceDictBA"];
    _associationAB = [[GeniusAssociation alloc] _initWithCueItem:itemA answerItem:itemB parentPair:self performanceDict:performanceDictAB];
    _associationBA = [[GeniusAssociation alloc] _initWithCueItem:itemB answerItem:itemA parentPair:self performanceDict:performanceDictBA];
    _userDict = [[coder decodeObjectForKey:@"userDict"] retain];

    [itemA addObserver:self forKeyPath:@"dirty" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
    [itemB addObserver:self forKeyPath:@"dirty" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
    [_associationAB addObserver:self forKeyPath:@"dirty" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
    [_associationBA addObserver:self forKeyPath:@"dirty" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSAssert([coder allowsKeyedCoding], @"allowsKeyedCoding");

    [coder encodeObject:[self itemA] forKey:@"itemA"];
    [coder encodeObject:[self itemB] forKey:@"itemB"];
    [coder encodeObject:[_associationAB performanceDictionary] forKey:@"performanceDictAB"];
    [coder encodeObject:[_associationBA performanceDictionary] forKey:@"performanceDictBA"];
    [coder encodeObject:_userDict forKey:@"userDict"];
}

- (id) _initWithItemA:(GeniusItem *)itemA itemB:(GeniusItem *)itemB userDict:(NSMutableDictionary *)userDict
{
    self = [super init];
    _associationAB = [[GeniusAssociation alloc] _initWithCueItem:itemA answerItem:itemB parentPair:self performanceDict:nil];
    _associationBA = [[GeniusAssociation alloc] _initWithCueItem:itemB answerItem:itemA parentPair:self performanceDict:nil];
    _userDict = [userDict retain];

    [itemA addObserver:self forKeyPath:@"dirty" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
    [itemB addObserver:self forKeyPath:@"dirty" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
    [_associationAB addObserver:self forKeyPath:@"dirty" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
    [_associationBA addObserver:self forKeyPath:@"dirty" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];

    return self;
}
- (id)copyWithZone:(NSZone *)zone
{
    GeniusItem * newItemA = [[[self itemA] copy] autorelease];
    GeniusItem * newItemB = [[[self itemB] copy] autorelease];
    NSMutableDictionary * newUserDict = [[_userDict mutableCopy] autorelease];
    return [[[self class] allocWithZone:zone] _initWithItemA:newItemA itemB:newItemB userDict:newUserDict];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    //NSLog(@"GeniusPair observeValueForKeyPath:%@", keyPath);
    [self setValue:[NSNumber numberWithBool:YES] forKey:@"dirty"];
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"(%@, %@)", [[self itemA] description], [[self itemB] description]];
}


- (GeniusItem *) itemA
{
    return [[self associationAB] cueItem];
}

- (GeniusItem *) itemB
{
    return [[self associationBA] cueItem];
}

- (GeniusAssociation *) associationAB
{
    return _associationAB;
}

- (GeniusAssociation *) associationBA
{
    return _associationBA;
}


- (int) importance
{
    NSNumber * importanceNumber = [_userDict objectForKey:GeniusPairImportanceNumberKey];
    if (importanceNumber == nil)
        return kGeniusPairNormalImportance;
    return [importanceNumber intValue];
}

- (void) setImportance:(int)importance
{
    NSNumber * importanceNumber = [NSNumber numberWithInt:importance];
    [_userDict setObject:importanceNumber forKey:GeniusPairImportanceNumberKey];

//    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
//    [nc postNotificationName:GeniusPairFieldHasChanged object:GeniusPairImportanceNumberKey];
}


// Optional user-defined tags
- (NSString *) customGroupString
{
    return [_userDict objectForKey:GeniusPairCustomGroupStringKey];
}

- (void) setCustomGroupString:(NSString *)customGroup
{
    if (customGroup)
        [_userDict setObject:customGroup forKey:GeniusPairCustomGroupStringKey];
    else
        [_userDict removeObjectForKey:GeniusPairCustomGroupStringKey];

//    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
//    [nc postNotificationName:GeniusPairFieldHasChanged object:GeniusPairCustomGroupStringKey];
}

- (NSString *) customTypeString
{
    return [_userDict objectForKey:GeniusPairCustomTypeStringKey];
}

- (void) setCustomTypeString:(NSString *)customType
{
    if (customType)
        [_userDict setObject:customType forKey:GeniusPairCustomTypeStringKey];
    else
        [_userDict removeObjectForKey:GeniusPairCustomTypeStringKey];

//    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
//    [nc postNotificationName:GeniusPairFieldHasChanged object:GeniusPairCustomTypeStringKey];
}

- (NSString *) notesString
{
    return [_userDict objectForKey:GeniusPairNotesStringKey];
}

- (void) setNotesString:(NSString *)notesString
{
    if (notesString)
        [_userDict setObject:notesString forKey:GeniusPairNotesStringKey];
    else
        [_userDict removeObjectForKey:GeniusPairNotesStringKey];

//    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
//    [nc postNotificationName:GeniusPairFieldHasChanged object:GeniusPairNotesStringKey];
}

@end


@implementation GeniusPair (GeniusDocumentAdditions)

- (BOOL) disabled
{
    return ([self importance] == kGeniusPairDisabledImportance);
}

- (void) setDisabled:(BOOL)disabled
{
    [self setImportance:(disabled ? kGeniusPairDisabledImportance : kGeniusPairNormalImportance)];
}

@end


@implementation GeniusPair (TextImportExport)

+ (NSString *) tabularTextFromPairs:(NSArray *)pairs order:(NSArray *)keyPaths
{
    NSMutableString * outputString = [NSMutableString string];    
    NSEnumerator * pairEnumerator = [pairs objectEnumerator];
    GeniusPair * pair;
    while ((pair = [pairEnumerator nextObject]))
        [outputString appendFormat:@"%@\n", [pair tabularTextByOrder:keyPaths]];
    return (NSString *)outputString;
}

- (NSString *) tabularTextByOrder:(NSArray *)keyPaths
{
    NSMutableString * outputString = [NSMutableString string];
    int i, count = [keyPaths count];
    for (i=0; i<count; i++)
    {
        NSString * keyPath = [keyPaths objectAtIndex:i];
        id value = [self valueForKeyPath:keyPath];
        if (value)
        {
            // Escape any embedded special characters
            NSMutableString * encodedString = [NSMutableString stringWithString:[value description]];
            [encodedString replaceOccurrencesOfString:@"\t" withString:@"\\t" options:NSLiteralSearch range:NSMakeRange(0, [encodedString length])];
            [encodedString replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSLiteralSearch range:NSMakeRange(0, [encodedString length])];
            [encodedString replaceOccurrencesOfString:@"\r" withString:@"\\n" options:NSLiteralSearch range:NSMakeRange(0, [encodedString length])];

            [outputString appendString:encodedString];
        }
        if (i<count-1)
            [outputString appendString:@"\t"];
    }

    return outputString;
}


+ (NSArray *) _linesFromString:(NSString *)string
{
    NSMutableArray * lines = [NSMutableArray array];
    unsigned int startIndex, lineEndIndex, contentsEndIndex = 0;
    unsigned int length = [string length];
    NSRange range = NSMakeRange(0, 0);
    while (contentsEndIndex < length)
    {
        [string getLineStart:&startIndex end:&lineEndIndex contentsEnd:&contentsEndIndex forRange:range];
        unsigned int rangeLength = contentsEndIndex - startIndex;
        if (rangeLength > 0)    // don't include empty lines
        {
            NSString * line = [string substringWithRange:NSMakeRange(startIndex, rangeLength)];
            [lines addObject:line];
        }
        range.location = lineEndIndex;
    }
    return lines;
}

+ (NSArray *) pairsFromTabularText:(NSString *)string order:(NSArray *)keyPaths;
{
    //Can't use lines = [string componentsSeparatedByString:@"\n"];
    // because it doesn't handle carriage returns.
    NSArray * lines = [self _linesFromString:string];

    NSMutableArray * pairs = [NSMutableArray array];
    NSEnumerator * lineEnumerator = [lines objectEnumerator];
    NSString * line;
    while ((line = [lineEnumerator nextObject]))
    {
        GeniusPair * pair = [[GeniusPair alloc] initWithTabularText:line order:keyPaths];
        [pairs addObject:pair];
        [pair release];
    }
    return (NSArray *)pairs;
}

- (id) initWithTabularText:(NSString *)line order:(NSArray *)keyPaths
{
    self = [self init];

    NSArray * fields = [line componentsSeparatedByString:@"\t"];
    int i, count=MIN([fields count], [keyPaths count]);
    for (i=0; i<count; i++)
    {
        NSString * field = [fields objectAtIndex:i];
        NSString * keyPath = [keyPaths objectAtIndex:i];

        // Unescape any embedded special characters
        NSMutableString * decodedString = [NSMutableString stringWithString:field];
        [decodedString replaceOccurrencesOfString:@"\\t" withString:@"\t" options:NSLiteralSearch range:NSMakeRange(0, [decodedString length])];
        [decodedString replaceOccurrencesOfString:@"\\n" withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, [decodedString length])];

        [self setValue:decodedString forKeyPath:keyPath];
    }
    
    return self;
}

@end
