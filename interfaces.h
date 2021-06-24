@interface PHPhotoLibrary : NSObject
+(id)sharedPhotoLibrary;
-(void)performChanges:(/*^block*/id)arg1 completionHandler:(/*^block*/id)arg2;
@end

@interface PHAsset : NSObject
@property (getter=isFavorite,nonatomic,readonly) BOOL favorite;
@end

@interface PHAssetChangeRequest : NSObject
@property (assign,nonatomic) BOOL favorite;
+(id)changeRequestForAsset:(id)arg1;
@end

@interface UIBarButtonItem (MarkFavourites)
@property (nonatomic,readonly) long long systemItem;
@end

@interface UIImage (Internal)
+(id)imageNamed:(id)arg1 inBundle:(id)arg2;
@end

@interface PUPhotosGridViewController : UIViewController
-(NSMutableArray*)selectedAssets;
-(void)setEditing:(BOOL)editing animated:(BOOL)arg2;
@end

@interface UIView (Internal)
-(id)_viewControllerForAncestor;
@end

@protocol PXFastEnumeration<NSFastEnumeration>
@end

@interface PXEnumerator : NSObject<PXFastEnumeration>
- (PHAsset *)nextObject;
- (void)reset;
- (NSInteger)count;
@end

@interface PXSelectionSnapshot : NSObject
- (PXEnumerator *)allObjectsEnumerator;
@end

@interface PXSectionedSelectionManager : NSObject
- (void)_performSelectAll;
@end

@interface PXAssetSelectionUserActivityController : NSObject
- (PXSectionedSelectionManager *)selectionManager;
- (PXSelectionSnapshot *)selectionSnapshot;
@end

// Not an actual protocol
@protocol PhotoViewController
- (PXAssetSelectionUserActivityController *)userActivityController;
@end

@interface PXCuratedLibraryUIViewController : UIViewController<PhotoViewController>
@end

@interface PXPhotosUIViewController : UIViewController<PhotoViewController>
@end