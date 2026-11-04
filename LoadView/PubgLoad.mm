#import "PubgLoad.h"
#import <UIKit/UIKit.h>

#import "ImGuiDrawView.h"

static NSInteger const kOpenTouchesRequired  = 3;
static NSInteger const kCloseTouchesRequired = 4;
static NSInteger const kTapsRequired         = 2;

@interface PubgLoad () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) ImGuiDrawView *vna;
@property (nonatomic, weak) UIView *gameRenderViewCache;
@end

@implementation PubgLoad
{
    UITapGestureRecognizer *_openTap;
    UITapGestureRecognizer *_closeTap;
    __weak UIWindow *_attachedWindow;
}

#pragma mark - Singleton

+ (instancetype)shared
{
    static PubgLoad *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PubgLoad alloc] init];
    });
    return sharedInstance;
}

+ (void)load
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[PubgLoad shared] install];
    });
}

- (void)install
{
    [self attachMenuGestureToCurrentWindow];

    if (_vna == nil)
    {
        _vna = [[ImGuiDrawView alloc] init];
        (void)_vna.view;
    }

    static dispatch_once_t autoOpenOnce;
    dispatch_once(&autoOpenOnce, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showMenu];
        });
    });

    static dispatch_once_t observerOnce;
    dispatch_once(&observerOnce, ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self attachMenuGestureToCurrentWindow];
                [self reattachMenuViewIfNeeded];
            });
        }];
    });
}

#pragma mark - Window / gesture

- (UIWindow *)activeWindow
{
    UIWindow *candidate = nil;

    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
        {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState != UISceneActivationStateForegroundActive)
        {
            continue;
        }
        for (UIWindow *window in windowScene.windows)
        {
            if (window.isKeyWindow)
            {
                candidate = window;
                break;
            }
        }
        if (candidate == nil)
        {
            candidate = windowScene.windows.firstObject;
        }
        if (candidate != nil)
        {
            break;
        }
    }

    if (candidate == nil)
    {
        candidate = [UIApplication sharedApplication].windows.firstObject;
    }
    return candidate;
}

- (void)attachMenuGestureToCurrentWindow
{
    UIWindow *window = [self activeWindow];
    if (window == nil)
    {
        return;
    }

    if (_openTap != nil && _attachedWindow == window &&
        [window.gestureRecognizers containsObject:_openTap])
    {
        return;
    }

    if (_attachedWindow != nil)
    {
        if (_openTap != nil)  { [_attachedWindow removeGestureRecognizer:_openTap]; }
        if (_closeTap != nil) { [_attachedWindow removeGestureRecognizer:_closeTap]; }
    }

    _openTap  = [self makeTapWithTouches:kOpenTouchesRequired action:@selector(handleOpenTap:)];
    _closeTap = [self makeTapWithTouches:kCloseTouchesRequired action:@selector(handleCloseTap:)];

    if (_openTap != nil)  { [window addGestureRecognizer:_openTap]; }
    if (_closeTap != nil) { [window addGestureRecognizer:_closeTap]; }

    _attachedWindow = window;
}

- (UITapGestureRecognizer *)makeTapWithTouches:(NSInteger)touches action:(SEL)action
{
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:action];

    tap.numberOfTouchesRequired = touches;
    tap.numberOfTapsRequired    = kTapsRequired;

    tap.delaysTouchesBegan   = NO;
    tap.delaysTouchesEnded   = NO;
    tap.cancelsTouchesInView = NO;
    tap.delegate = self;

    return tap;
}

- (void)handleOpenTap:(UITapGestureRecognizer *)sender
{
    if ([NSThread isMainThread])
    {
        [self showMenu];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showMenu];
        });
    }
}

- (void)handleCloseTap:(UITapGestureRecognizer *)sender
{
    [ImGuiDrawView showChange:NO];
}

#pragma mark - Menu

- (void)showMenu
{
    UIWindow *window = [self activeWindow];
    if (window == nil)
    {
        return;
    }

    UIView *rootView = window.rootViewController.view;
    if (rootView == nil)
    {
        return;
    }

    if (_vna == nil)
    {
        _vna = [[ImGuiDrawView alloc] init];
    }

    UIView *menuView = _vna.view;
    if (menuView.superview != rootView)
    {
        [rootView addSubview:menuView];
        [self enableMultiTouchOnWindow:window rootView:rootView menuView:menuView];
    }

    [ImGuiDrawView showChange:YES];
}

- (void)reattachMenuViewIfNeeded
{
    if (_vna == nil || ![ImGuiDrawView isMenuOpen])
    {
        return;
    }

    UIWindow *window = [self activeWindow];
    UIView *rootView = window.rootViewController.view;
    if (rootView == nil)
    {
        return;
    }

    UIView *menuView = _vna.view;
    if (menuView.superview != rootView)
    {
        [rootView addSubview:menuView];
        [self enableMultiTouchOnWindow:window rootView:rootView menuView:menuView];
    }
}

#pragma mark - Multi touch

- (UIView *)findGameRenderViewIn:(UIView *)root excluding:(UIView *)excluded
{
    UIView *cached = self.gameRenderViewCache;
    if (cached != nil &&
        [cached isDescendantOfView:root] &&
        ![cached isDescendantOfView:excluded])
    {
        return cached;
    }

    static NSArray<NSString *> *classNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        classNames = @[@"MTKView", @"EAGLView", @"GLKView", @"UnityView", @"SCNView"];
    });

    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:root];
    while (stack.count > 0)
    {
        UIView *view = stack.lastObject;
        [stack removeLastObject];

        if (excluded != nil && [view isDescendantOfView:excluded])
        {
            continue;
        }

        for (NSString *name in classNames)
        {
            Class cls = NSClassFromString(name);
            if (cls != Nil && [view isKindOfClass:cls])
            {
                self.gameRenderViewCache = view;
                return view;
            }
        }
        for (UIView *sub in view.subviews)
        {
            [stack addObject:sub];
        }
    }
    return nil;
}

- (void)enableMultiTouchOnWindow:(UIWindow *)window rootView:(UIView *)rootView menuView:(UIView *)menuView
{
    window.multipleTouchEnabled = YES;
    rootView.multipleTouchEnabled = YES;

    UIView *gameView = [self findGameRenderViewIn:rootView excluding:menuView];
    if (gameView != nil)
    {
        gameView.multipleTouchEnabled = YES;
        gameView.exclusiveTouch = NO;
    }

    menuView.multipleTouchEnabled = YES;
    menuView.exclusiveTouch = NO;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

@end
