#import <UIKit/UIKit.h>
#import "interfaces.h"

#define NSLog(args...) NSLog(@"[MarkFavourites] "args)

static UIImage* heartImage(BOOL on)
{
    if (@available(iOS 14.0, *)) {
        return [UIImage systemImageNamed:(on ? @"heart.fill" : @"heart")];
    }
    else {
        NSString* name;
        if (on)
            name = @"PUFavoriteOn";
        else
            name = @"PUFavoriteOff";
        NSBundle* bundle = [NSBundle bundleWithPath:@"/System/Library/Frameworks/PhotosUI.framework"];
        return [UIImage imageNamed:name inBundle:bundle];
    }
}

static UIBarButtonItem* favButton;

%group iOS13
%hook UIToolbar
-(void)setItems:(NSArray*)items animated:(BOOL)arg2
{
    BOOL hasShare = NO;
    BOOL hasAdd = NO;
    BOOL hasTrash = NO;
    for (UIBarButtonItem* item in items)
    {
        if (sel_isEqual(item.action, @selector(_shareButtonPressed:)))
        {
            hasShare = YES;
            continue;
        }
        if (sel_isEqual(item.action, @selector(_addButtonPressed:)))
        {
            hasAdd = YES;
            continue;
        }
        if (sel_isEqual(item.action, @selector(_removeButtonPressed:)))
        {
            hasTrash = YES;
            continue;
        }
    }

    if (hasShare && hasAdd && hasTrash)
    {
        /* Add favourite button: */
        //remove old spaces:
        NSMutableArray<UIBarButtonItem*>* newItems = [items mutableCopy];
        for (int i = 0; i < newItems.count; i++)
        {
            if (newItems[i].systemItem == UIBarButtonSystemItemFlexibleSpace)
            {
                [newItems removeObjectAtIndex:i];
                i--;
            }
        }

        //add button:
        UINavigationController* navCont = [self _viewControllerForAncestor];
        PUPhotosGridViewController* target;
        for (id vc in navCont.childViewControllers)
        {
            if ([vc isKindOfClass:%c(PUPhotosGridViewController)])
            {
                target = vc;
                break;
            }
        }
        favButton = [[UIBarButtonItem alloc] initWithImage:heartImage(NO) style:UIBarButtonItemStylePlain target:nil action:@selector(_favouriteButtonPressed:)];
        favButton.enabled = NO;
        [newItems insertObject:favButton atIndex:2];

        //add new spaces:
        for (int i = 0; i < 3; i++)
        {
            UIBarButtonItem* space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            NSUInteger index = 2 * i + 1;
            [newItems insertObject:space atIndex:index];
        }

        items = [newItems copy];
    }
    %orig;
}
%end

%hook PUPhotosGridViewController
%new
-(void)_favouriteButtonPressed:(id)arg1
{
    NSMutableArray<PHAsset*>* assets = [self selectedAssets];
    __block BOOL newValue = NO;
    for (PHAsset* asset in assets)
    {
        if (!asset.favorite)
        {
            newValue = YES;
            break;
        }
    }
    [[%c(PHPhotoLibrary) sharedPhotoLibrary] performChanges:^{
        for (PHAsset* asset in assets)
        {
            PHAssetChangeRequest* request = [%c(PHAssetChangeRequest) changeRequestForAsset:asset];
            request.favorite = newValue;
        }
    } completionHandler:nil];
    [self setEditing:NO animated:YES];
}

-(void)setSelected:(BOOL)arg1 itemsAtIndexes:(id)arg2 inSection:(unsigned long long)arg3 animated:(BOOL)arg4
{
    %orig;
    if (!favButton.target)
        favButton.target = self;
    if ([self selectedAssets].count)
    {
        favButton.enabled = YES;
        BOOL on = YES;
        for (PHAsset* asset in [self selectedAssets])
        {
            if (!asset.favorite)
            {
                on = NO;
                break;
            }
        }
        favButton.image = heartImage(on);
    }
    else
    {
        favButton.enabled = NO;
        favButton.image = heartImage(NO);
    }
}
%end
%end

static NSArray *setToolbarItemsHook(UIViewController<PhotoViewController> *self, NSArray *items) {
    if (items.count == 5) {
        NSMutableArray *newItems = [items mutableCopy];
        PXEnumerator *enumerator = [[[self userActivityController] selectionSnapshot] allObjectsEnumerator];

        // Replace the "N Photos Selected" button if there are no selected photos
        if ([enumerator count] == 0) {
            UIBarButtonItem *selectAllButton = [[UIBarButtonItem alloc]
                initWithTitle:@"Select All"
                style:UIBarButtonItemStylePlain
                target:self
                action:@selector(markFavourites_didPressSelectAll:)
            ];
            newItems[2] = selectAllButton;
        }

        // Figure out if the heart should be filled or not
        BOOL fillHeart = YES;
        if ([enumerator count] == 0) {
            fillHeart = NO;
        }
        else {
            for (PHAsset *asset in enumerator) {
                if (!asset.favorite) {
                    fillHeart = NO;
                    break;
                }
            }
        }

        // Add the heart
        UIBarButtonItem *newItem = [[UIBarButtonItem alloc]
            initWithImage:heartImage(fillHeart)
            style:UIBarButtonItemStylePlain
            target:self
            action:@selector(markFavourites_didPressHeart:)
        ];
        if ([enumerator count] == 0) {
            newItem.enabled = NO;
        }
        [newItems insertObject:newItem atIndex:4];
        items = (NSArray *)newItems;
    }
    return items;
}

static void didPressSelectAll(UIViewController<PhotoViewController> *self) {
    [[[self userActivityController] selectionManager] _performSelectAll];
    [self setToolbarItems:[self toolbarItems]];
}

static void didPressHeart(UIViewController<PhotoViewController> *self) {
    PXEnumerator *enumerator = [[[self userActivityController] selectionSnapshot] allObjectsEnumerator];
    BOOL makeFavorite = NO;
    for (PHAsset *asset in enumerator) {
        if (!asset.favorite) {
            makeFavorite = YES;
            break;
        }
    }
    [[%c(PHPhotoLibrary) sharedPhotoLibrary] performChanges:^{
        for (PHAsset* asset in enumerator) {
            PHAssetChangeRequest *request = [%c(PHAssetChangeRequest) changeRequestForAsset:asset];
            request.favorite = makeFavorite;
        }
    } completionHandler:^(BOOL success, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setToolbarItems:[self toolbarItems]];
        });
    }];
}

// We don't need to hook the observer method. When the selection changes,
// -[PXBarsController updateBars] calls -[PXCuratedLibraryUIViewController
// setToolbarItems:] for us.

/* - (void)observable:(id)observable didChange:(NSUInteger)arg2 context:(void *)arg3 {
    if (arg2 == 8) {
        // 8 means "selection changed" (?)

    }
    %orig;
} */

%group iOS14
%hook PXPhotosUIViewController

%new
- (void)markFavourites_didPressSelectAll:(UIBarButtonItem *)sender {
    didPressSelectAll(self);
}

%new
- (void)markFavourites_didPressHeart:(UIBarButtonItem *)sender {
    didPressHeart(self);
}

- (void)setToolbarItems:(NSArray<UIBarButtonItem *> *)items {
    %orig(setToolbarItemsHook(self, items));
}

%end

%hook PXCuratedLibraryUIViewController

%new
- (void)markFavourites_didPressSelectAll:(UIBarButtonItem *)sender {
    didPressSelectAll(self);
}

%new
- (void)markFavourites_didPressHeart:(UIBarButtonItem *)sender {
    didPressHeart(self);
}

- (void)setToolbarItems:(NSArray<UIBarButtonItem *> *)items {
    %orig(setToolbarItemsHook(self, items));
}

%end
%end

%ctor {
    if (@available(iOS 14.0, *)) {
        %init(iOS14);
    }
    else {
        %init(iOS13);
    }
}