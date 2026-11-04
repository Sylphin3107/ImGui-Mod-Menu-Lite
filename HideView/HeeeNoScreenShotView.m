#import "HeeeNoScreenShotView.h"

@interface HeeeSecureTextField : UITextField
@end

@implementation HeeeSecureTextField
- (BOOL)canBecomeFirstResponder { return NO; }
- (BOOL)becomeFirstResponder { return NO; }
@end

@interface HeeeNoScreenShotView ()
@property (nonatomic, strong) HeeeSecureTextField *textField;
@property (nonatomic, strong) UIView *clearView;
@property (nonatomic, weak) UIView *contentHost;
@end

@implementation HeeeNoScreenShotView
{
  BOOL _maskContent;
}

- (instancetype)init
{
  self = [super init];
  if (self)
  {
    [self setupUI];
  }
  return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    [self setupUI];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
  self = [super initWithCoder:coder];
  if (self)
  {
    [self setupUI];
  }
  return self;
}

- (void)setupUI
{
  self.backgroundColor = [UIColor clearColor];
  self.opaque = NO;

  _maskContent = YES;

  self.textField.secureTextEntry = YES;
  self.textField.frame = self.bounds;
  [super addSubview:self.textField];

  [self attachContentHost];
  self.clearView.frame = self.bounds;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.textField.frame = self.bounds;
  [self attachContentHost];
  self.clearView.frame = self.bounds;
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];
  [self attachContentHost];
}

#pragma mark - Content host

- (UIView *)resolveContentHost
{
  UIView *host = self.contentHost;
  if (host != nil && host.superview == self.textField)
  {
    return host;
  }

  host = nil;
  for (UIView *sub in self.textField.subviews)
  {
    if ([NSStringFromClass([sub class]) rangeOfString:@"Canvas"].location != NSNotFound)
    {
      host = sub;
      break;
    }
  }
  if (host == nil)
  {
    host = self.textField.subviews.firstObject;
  }
  self.contentHost = host;
  return host;
}

- (void)attachContentHost {
  UIView *host = [self resolveContentHost];
  if (host == nil)
  {
    host = self;
  }
  host.userInteractionEnabled = YES;
  if (self.clearView.superview != host)
  {
    [host addSubview:self.clearView];
  }
  self.clearView.frame = self.bounds;
}

#pragma mark - Subviews

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  if (!self.userInteractionEnabled || self.hidden || self.alpha <= 0.01f)
  {
    return nil;
  }
  if (![self pointInside:point withEvent:event])
  {
    return nil;
  }
  CGPoint local = [self.clearView convertPoint:point fromView:self];
  return [self.clearView hitTest:local withEvent:event];
}

- (void)addSubview:(UIView *)view
{
  if (view == self.textField)
  {
    [super addSubview:view];
    return;
  }
  [self attachContentHost];
  [self.clearView addSubview:view];
}

#pragma mark - Mask

- (void)setMaskContent:(BOOL)maskContent
{
  if (_maskContent == maskContent)
  {
    return;
  }
  _maskContent = maskContent;

  if (self.textField.isSecureTextEntry != maskContent)
  {
    self.textField.secureTextEntry = maskContent;
    self.contentHost = nil;
    [self attachContentHost];
    [self setNeedsLayout];
  }
}

- (BOOL)maskContent
{
  return _maskContent;
}

#pragma mark - Lazy

- (HeeeSecureTextField *)textField
{
  if (!_textField)
  {
    _textField = [[HeeeSecureTextField alloc] init];
    _textField.secureTextEntry = YES;
    _textField.backgroundColor = [UIColor clearColor];
    _textField.borderStyle = UITextBorderStyleNone;
    _textField.userInteractionEnabled = NO;
  }
  return _textField;
}

- (UIView *)clearView
{
  if (!_clearView)
  {
    _clearView = [[UIView alloc] init];
    _clearView.backgroundColor = [UIColor clearColor];
    _clearView.userInteractionEnabled = YES;
  }
  return _clearView;
}

@end