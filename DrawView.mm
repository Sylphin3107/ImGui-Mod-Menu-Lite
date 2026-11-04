//Libraries
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

//Required Files
#import "LoadView/ImGuiDrawView.h"

//ImGui Files
#include "ImGui/imgui.h"
#include "ImGui/imgui_impl_metal.h"

//Fonts
#import "fonts/zzz.h"
#import "fonts/notosan.h"

// Chống quay / chụp màn hình
#import "HideView/HeeeNoScreenShotView.h"

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale [UIScreen mainScreen].nativeScale

@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) HeeeNoScreenShotView *secureContainer;
@property (nonatomic, assign) CFTimeInterval lastFrameTime;
@property (nonatomic, assign) NSInteger appliedFrameRate;
@property (nonatomic, weak) UIScreen *appliedScreen;
@property (nonatomic, assign) CGFloat cachedPixelScale;
@property (nonatomic, assign) CGPoint cachedMenuOrigin;
@property (nonatomic, assign) BOOL cachedMenuOriginValid;
@end

@implementation ImGuiDrawView


static bool MenDeal = false;
static bool StreamerMode = true;
static HeeeNoScreenShotView *gSecureContainer = nil;
static __weak ImGuiDrawView *gActiveDrawView = nil;

static void ApplyMenuState(void)
{
    ImGuiDrawView *view = gActiveDrawView;
    if (view == nil)
    {
        return;
    }
    view.view.userInteractionEnabled = MenDeal ? YES : NO;
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];

    if (!self.device) abort();

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;

    ImGui::StyleColorsClassic();
    
    ImFont *font = io.Fonts->AddFontFromMemoryCompressedTTF((void*)zzz_compressed_data, zzz_compressed_size, 45.0f, NULL, io.Fonts->GetGlyphRangesVietnamese());
    
    if (!font)
    {
        font = io.Fonts->AddFontDefault();
    }

    if (font)
    {
        ImFontConfig mergeCfg;
        mergeCfg.MergeMode = true;
        mergeCfg.PixelSnapH = true;
        mergeCfg.DstFont = font;

        io.Fonts->AddFontFromMemoryCompressedTTF((void*)notosan_compressed_data, notosan_compressed_size, 45.0f, &mergeCfg, io.Fonts->GetGlyphRangesChineseFull());

        font->LegacySize = 45.0f;

        static dispatch_once_t fontScaleOnce;
        dispatch_once(&fontScaleOnce, ^{
            const float targetFontSize = 15.0f;
            float s = targetFontSize / font->LegacySize;
            font->Scale = s;
        });
    }
    
    io.FontDefault = font;

    ImGui_ImplMetal_Init(_device);
    
    return self;
}

+ (void)showChange:(BOOL)open
{
    MenDeal = open;
    ApplyMenuState();
}

+ (BOOL)isMenuOpen
{
    return MenDeal ? YES : NO;
}

- (MTKView *)mtkView
{
    return _mtkView;
}

- (void)loadView
{
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    CGRect frame = window.rootViewController.view ? window.rootViewController.view.frame: CGRectMake(0, 0, kWidth, kHeight);

    HeeeNoScreenShotView *container = [[HeeeNoScreenShotView alloc] initWithFrame:frame];
    container.backgroundColor = [UIColor clearColor];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    container.maskContent = StreamerMode ? YES : NO;

    MTKView *mtk = [[MTKView alloc] initWithFrame:container.bounds];
    mtk.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [container addSubview:mtk];

    gSecureContainer = container;
    self.secureContainer = container;
    self.mtkView = mtk;
    self.view = container;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.mtkView.device = self.device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    self.mtkView.clipsToBounds = YES;

    self.lastFrameTime = CACurrentMediaTime();
    gActiveDrawView = self;
    [self applyFrameRateIfNeeded];

    ApplyMenuState();
}

#pragma mark - Frame rate

static bool g_overlayHasDrawContent = false;

static NSInteger ImGuiDesiredFrameRate(UIScreen *screen)
{
    NSInteger maxFPS = screen.maximumFramesPerSecond;
    if (maxFPS <= 0) maxFPS = 60;
    const bool needHighRate = MenDeal || g_overlayHasDrawContent;
    NSInteger wantFPS = needHighRate ? ((maxFPS >= 120) ? 120 : 60) : 60;
    return (wantFPS > maxFPS) ? maxFPS : wantFPS;
}

- (void)applyFrameRateIfNeeded
{
    UIScreen *screen = self.view.window.screen ?: UIScreen.mainScreen;
    NSInteger wantFPS = ImGuiDesiredFrameRate(screen);

    if (screen == self.appliedScreen && wantFPS == self.appliedFrameRate)
    {
        return;
    }

    if (screen != self.appliedScreen)
    {
        self.cachedPixelScale = 0.0f;
        self.cachedMenuOriginValid = NO;
    }

    self.appliedScreen = screen;
    self.appliedFrameRate = wantFPS;
    self.mtkView.preferredFramesPerSecond = wantFPS;
}



#pragma mark - Interaction

- (void)updateIOWithTouchEvent:(UIEvent *)event
{
    UITouch *anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.mtkView];
    ImGuiIO &io = ImGui::GetIO();
    io.MousePos = ImVec2(touchLocation.x, touchLocation.y);

    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches)
    {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled)
        {
            hasActiveTouch = YES;
            break;
        }
    }
    io.MouseDown[0] = hasActiveTouch;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

#pragma mark - MTKViewDelegate

- (void)drawInMTKView:(MTKView*)view
{
    @autoreleasepool
    {
        [self applyFrameRateIfNeeded];

        ImGuiIO& io = ImGui::GetIO();
        io.DisplaySize.x = view.bounds.size.width;
        io.DisplaySize.y = view.bounds.size.height;

        CFTimeInterval now = CACurrentMediaTime();
        float deltaTime = (float)(now - self.lastFrameTime);
        self.lastFrameTime = now;

        const NSInteger appliedFPS = self.appliedFrameRate > 0 ? self.appliedFrameRate : 60;
        const float nominalDelta = 1.0f / (float)appliedFPS;

        if (!(deltaTime > 0.0f) || deltaTime > 0.1f)
        {
            deltaTime = nominalDelta;
        }
        io.DeltaTime = deltaTime;

        if (self.cachedPixelScale <= 0.0f)
        {
            self.cachedPixelScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
        }
        io.DisplayFramebufferScale = ImVec2(self.cachedPixelScale, self.cachedPixelScale);

        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
        if (commandBuffer == nil)
        {
            return;
        }

        id<CAMetalDrawable> drawable = view.currentDrawable;
        MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
        if (renderPassDescriptor == nil || drawable == nil)
        {
            return;
        }

        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        if (renderEncoder == nil)
        {
            return;
        }
        [renderEncoder pushDebugGroup:@"ImGui Jane"];

        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();

        if (!self.cachedMenuOriginValid)
        {
            UIWindow *hostWindow = [UIApplication sharedApplication].windows.firstObject;
            CGRect hostFrame = hostWindow.rootViewController.view ? hostWindow.rootViewController.view.frame
                                                                : CGRectMake(0, 0, kWidth, kHeight);
            self.cachedMenuOrigin = CGPointMake((hostFrame.size.width - 360.0f) * 0.5f, (hostFrame.size.height - 300.0f) * 0.5f);
            self.cachedMenuOriginValid = YES;
        }

        ImGui::SetNextWindowPos(ImVec2(self.cachedMenuOrigin.x, self.cachedMenuOrigin.y), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(400, 300), ImGuiCond_FirstUseEver);

        if (MenDeal == true)
        {
            ImGui::Begin("Sylphin3107 AoV Mod Menu", &MenDeal);

            if (ImGui::Checkbox("Ẩn khi quay / chụp màn hình", &StreamerMode))
            {
                BOOL mask = StreamerMode ? YES : NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    gSecureContainer.maskContent = mask;
                });
            }

            ImGui::End();
        }

        static bool s_lastAppliedMenDeal = false;
        if (s_lastAppliedMenDeal != MenDeal)
        {
            s_lastAppliedMenDeal = MenDeal;
            ApplyMenuState();
        }

        ImGui::Render();
        ImDrawData* draw_data = ImGui::GetDrawData();

        g_overlayHasDrawContent = (draw_data != NULL && draw_data->TotalVtxCount > 0);

        ImGui_ImplMetal_RenderDrawData(draw_data, commandBuffer, renderEncoder);

        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];

        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size
{
    
}

@end

