//
//  KLSwitch.m
//  KLSwitch
//
//  Created by Kieran Lafferty on 2013-06-15.
//  Copyright (c) 2013 Kieran Lafferty. All rights reserved.
//
// https://github.com/KieranLafferty/KLSwitch

#import "KLSwitch.h"

#define kConstrainsFrameToProportions YES
#define kHeightWidthRatio                       1.6451612903f  //Magic number as a result of dividing the height by the width on the default UISwitch size (51/31)

//NSCoding Keys
#define kCodingOnKey                            @"on"
#define kCodingLockedKey                        @"off"
#define kCodingOnTintColorKey                   @"onColor"
#define kCodingOnColorKey                       @"onTintColor"    //Not implemented
#define kCodingTintColorKey                     @"tintColor"
#define kCodingThumbTintColorKey                @"thumbTintColor"
#define kCodingOnImageKey                       @"onImage"
#define kCodingOffImageKey                      @"offImage"
#define kCodingConstrainFrameKey                @"constrainFrame"

//Appearance Defaults - Colors
//Track Colors
#define kDefaultTrackOnColor                    [UIColor colorWithRed:83.0f/255.0f green: 214.0f/255.0f blue: 105.0f/255.0f alpha: 1.0f]
#define kDefaultTrackOffColor                   [UIColor colorWithWhite: 0.9f alpha:1.0f]
#define kDefaultTrackContrastColor              [UIColor whiteColor]

//Thumb Colors
#define kDefaultThumbTintColor                  [UIColor whiteColor]
#define kDefaultThumbBorderColor                [UIColor colorWithWhite: 0.9f alpha:1.0f]
#define kDefaultThumbShadowColor                [UIColor lightGrayColor]

//Appearance - Layout

//Size of knob with respect to the control - Must be a multiple of 2
#define kThumbOffset                            1.0f
#define kThumbTrackingGrowthRatio               1.2f    //Amount to grow the thumb on press down

#define kDefaultPanActivationThreshold          0.7f    //Number between 0.0 - 1.0 describing how far user must drag before initiating the switch

//Appearance - Animations
#define kDefaultAnimationSlideDuration          0.25f   //Length of time to slide the thumb from left/right to right/left
#define kDefaultAnimationScaleDuration          0.15f   //Length of time for the thumb to grow on press down
#define kDefaultAnimationContrastResizeDuration 0.25f   //Length of time for the thumb to grow on press down

#define kSwitchTrackContrastViewShrinkFactor    0.0001f //Must be very low but not 0 or else causes iOS 5 issues

typedef enum {
    KLSwitchThumbJustifyLeft,
    KLSwitchThumbJustifyRight
} KLSwitchThumbJustify;

@interface KLSwitchThumb : UIView
@property (nonatomic, assign) BOOL isTracking;
@property (nonatomic, assign) CGSize normalSize;
@property (nonatomic, assign) CGRect trackBounds;
-(void) growThumbWithJustification:(KLSwitchThumbJustify) justification;
-(void) shrinkThumbWithJustification:(KLSwitchThumbJustify) justification;
@end

@interface KLSwitchTrack : UIView
@property(nonatomic, getter=isOn) BOOL on;
@property (nonatomic, strong) UIColor* contrastColor;
@property (nonatomic, strong) UIColor* onTintColor;
@property (nonatomic, strong) UIColor* tintColor;

@property (nonatomic, assign) CGFloat thumbOffset;

-(id) initWithFrame:(CGRect)frame
            onColor:(UIColor*) onColor
           offColor:(UIColor*) offColor
      contrastColor:(UIColor*) contrastColor
        thumbOffset:(CGFloat) thumbOffset;
-(void) growContrastView;
-(void) shrinkContrastView;
-(void) setOn:(BOOL)on animated:(BOOL)animated;
@end


@interface KLSwitch () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) KLSwitchTrack* track;
@property (nonatomic, strong) KLSwitchThumb* thumb;

//Gesture Recognizers
@property (nonatomic, strong) UIPanGestureRecognizer* panGesture;
@property (nonatomic, strong) UITapGestureRecognizer* tapGesture;

-(void) configureSwitch;
-(void) initializeDefaults;
-(void) toggleState;
-(void) setThumbOn:(BOOL)on animated:(BOOL)animated completion:(void (^)(BOOL finished))completion;

@property (readonly) CGRect trackFrame;
@property (readonly) CGRect thumbFrame;

@end

@implementation KLSwitch

#pragma mark - Initializers

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder: aCoder];
    
    [aCoder encodeBool: _on
                forKey: kCodingOnKey];
    
    [aCoder encodeObject: _onTintColor
                  forKey: kCodingOnTintColorKey];
    
    [aCoder encodeObject: _tintColor
                  forKey: kCodingTintColorKey];
    
    [aCoder encodeObject: _thumbTintColor
                  forKey: kCodingThumbTintColorKey];
    
    [aCoder encodeObject: _onImage
                  forKey: kCodingOnImageKey];
    
    [aCoder encodeObject: _offImage
                  forKey: kCodingOffImageKey];
    
    [aCoder encodeBool: _shouldConstrainFrame
                forKey: kCodingConstrainFrameKey];
    
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    [self initializeDefaults];
    if (self = [super initWithCoder: aDecoder]) {
        
        _on = [aDecoder decodeBoolForKey:kCodingOnKey];
        _locked = [aDecoder decodeBoolForKey:kCodingLockedKey];
        _onTintColor = [aDecoder decodeObjectForKey: kCodingOnTintColorKey];
        _tintColor = [aDecoder decodeObjectForKey: kCodingTintColorKey];
        _thumbTintColor = [aDecoder decodeObjectForKey: kCodingThumbTintColorKey];
        _onImage = [aDecoder decodeObjectForKey: kCodingOnImageKey];
        _offImage = [aDecoder decodeObjectForKey: kCodingOffImageKey];
        _onTintColor = [aDecoder decodeObjectForKey: kCodingOnTintColorKey];
        _shouldConstrainFrame = [aDecoder decodeBoolForKey: kCodingConstrainFrameKey];
        
        [self configureSwitch];

    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self configureSwitch];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame didChangeHandler:(KLSwitchChangeHandler) didChangeHandler
{
    self = [self initWithFrame: frame];
    if (self) {
        _didChangeHandler = didChangeHandler;
    }
    return self;
}

-(CGRect)trackFrame
{
    CGRect frame = self.bounds;
    if (self.shouldConstrainFrame) {
        frame = CGRectMake(frame.origin.x, frame.origin.y, floor(frame.size.height*kHeightWidthRatio), frame.size.height);
    }
    return frame;
}

-(CGRect)thumbFrame
{
    CGRect frame = [self trackFrame];
    CGFloat size = floor(frame.size.height - 2.0f * _thumbOffset);
    frame = CGRectMake(frame.origin.x + _thumbOffset, frame.origin.y + _thumbOffset, size, size);
    return frame;
}

#pragma mark - Defaults and layout/appearance

-(void) initializeDefaults
{
    _thumbOffset = kThumbOffset;
    _thumbShadowColor = kDefaultThumbShadowColor;
    _onTintColor = kDefaultTrackOnColor;
    _tintColor = kDefaultTrackOffColor;
    _thumbTintColor = kDefaultThumbTintColor;
    _thumbBorderColor = kDefaultThumbBorderColor;
    _contrastColor = kDefaultThumbTintColor;
    _panActivationThreshold = kDefaultPanActivationThreshold;
    _shouldConstrainFrame = kConstrainsFrameToProportions;
}

-(void) configureSwitch
{
    [self initializeDefaults];
 
    //Configure visual properties of self
    [self setBackgroundColor: [UIColor clearColor]];
    
    
    // tap gesture for toggling the switch
	self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                              action:@selector(didTap:)];
	[self.tapGesture setDelegate:self];
	[self addGestureRecognizer:self.tapGesture];
    
    
	// pan gesture for moving the switch knob manually
	self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                              action:@selector(didDrag:)];
	[self.panGesture setDelegate:self];
	[self addGestureRecognizer:self.panGesture];
    
    /*
     Subview layering as follows :
     
     TOP
         thumb
         track
     BOTTOM
     */
    // Initialization code
    if (!_track) {
        _track = [[KLSwitchTrack alloc] initWithFrame: self.trackFrame
                                              onColor: self.onTintColor
                                             offColor: self.tintColor
                                        contrastColor: self.contrastColor
                                          thumbOffset: self.thumbOffset];
        [_track setOn: self.isOn
             animated: NO];
        [self addSubview: self.track];
    }
    if (!_thumb) {
        _thumb = [[KLSwitchThumb alloc] initWithFrame:self.thumbFrame];
        [self addSubview: _thumb];
    }
}

-(void) setOnTintColor:(UIColor *)onTintColor
{
    _onTintColor = onTintColor;
    [self.track setOnTintColor: _onTintColor];
}

-(void) setTintColor:(UIColor *)tintColor
{
    _tintColor = tintColor;
    [self.track setTintColor: _tintColor];
}

-(void) setContrastColor:(UIColor *)contrastColor
{
    _contrastColor = contrastColor;
    [self.track setContrastColor: _contrastColor];
}

-(void) setThumbBorderColor:(UIColor *)thumbBorderColor
{
    _thumbBorderColor = thumbBorderColor;
    [self.thumb.layer setBorderColor: [_thumbBorderColor CGColor]];
}

-(void) setThumbShadowColor:(UIColor *)thumbShadowColor
{
    _thumbShadowColor = thumbShadowColor;
    [self.thumb.layer setShadowColor: [_thumbShadowColor CGColor]];
}

-(void)setThumbOffset:(CGFloat)thumbOffset
{
    if (_thumbOffset != thumbOffset) {
        _thumbOffset = thumbOffset;
        self.track.thumbOffset = thumbOffset;
        [self setNeedsLayout];
    }
}

-(void) setShouldConstrainFrame:(BOOL)shouldConstrainFrame
{
    _shouldConstrainFrame = shouldConstrainFrame;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    KLSwitchThumb *thumb = self.thumb;
    KLSwitchTrack *track = self.track;
    
    thumb.frame = self.thumbFrame;
    track.frame = self.trackFrame;
    
    thumb.normalSize = thumb.frame.size;
    thumb.trackBounds = CGRectInset(track.frame, _thumbOffset, _thumbOffset);
    
    // Drawing code
    //[self.trackingKnob setTintColor: self.thumbTintColor];
    [thumb setBackgroundColor: self.thumbTintColor];
    
    //Make the knob a circle and add a shadow
    CGFloat roundedCornerRadius = thumb.frame.size.height/2.0f;
    [thumb.layer setBorderWidth: 0.5];
    [thumb.layer setBorderColor: [self.thumbBorderColor CGColor]];
    [thumb.layer setCornerRadius: roundedCornerRadius];
    [thumb.layer setShadowColor: [_thumbShadowColor CGColor]];
    [thumb.layer setShadowOffset: CGSizeMake(0, 3)];
    [thumb.layer setShadowOpacity: 0.40f];
    [thumb.layer setShadowRadius: 0.8];
    
    //Following lines needed to solve laggy scroll performance on older devices (such as iPod Touch 4th Gen)
    //when using KLSwitch in UITableViewCells.
    //Reason of laggy performance is setting cornerRadius property.
    thumb.layer.shouldRasterize = YES;
    thumb.layer.rasterizationScale = [[UIScreen mainScreen] scale];
    thumb.layer.masksToBounds = NO;
    
    [self setThumbOn:self.on animated:NO completion:nil];
}

#pragma mark - UIGestureRecognizer implementations
-(void) didTap:(UITapGestureRecognizer*) gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [self toggleState];
    }
}

-(void) didDrag:(UIPanGestureRecognizer*) gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan) {
        //Grow the thumb horizontally towards center by defined ratio
        [self setThumbIsTracking:YES animated:YES];
        
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        //If touch crosses the threshold then toggle the state
        CGPoint locationInThumb = [gesture locationInView: self.track];
        
        CGRect trackFrame = self.trackFrame;
        
        //Toggle the switch if the user pans left or right past the switch thumb bounds
        if ((self.isOn && locationInThumb.x <= 0)
            || (!self.isOn && locationInThumb.x >= trackFrame.size.width)) {
            [self toggleState];
        }
        
        CGPoint locationOfTouch = [gesture locationInView:self];
        if (CGRectContainsPoint(trackFrame, locationOfTouch)) {
            [self sendActionsForControlEvents:UIControlEventTouchDragInside];
        } else {
            [self sendActionsForControlEvents:UIControlEventTouchDragOutside];
        }
        
    } else  if (gesture.state == UIGestureRecognizerStateEnded) {
        [self setThumbIsTracking:NO animated:YES];
    }
}

#pragma mark - Event Handlers

-(void) toggleState
{
    //Alternate between on/off
    [self setOn:!(self.isOn) animated:YES notify:YES];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated notify:(BOOL)notify
{
    //Cancel notification to parent if attempting to set to current state
    if (_on == on) {
        return;
    }
    
    KLSwitchChangeHandler completionHandler = nil;
    
    // only send notifications if specified
    if (notify) {
        
        __weak KLSwitch *weakSelf = self;
        
        // notifications should be sent after the animation has completed
        completionHandler = ^(BOOL finished) {
            
            if (weakSelf) {
                __strong KLSwitch *strongSelf = weakSelf;
                
                //Trigger the completion block if exists
                if (strongSelf.didChangeHandler) {
                    strongSelf.didChangeHandler(_on);
                }
                // send actions for the Value Changed event
                [strongSelf sendActionsForControlEvents:UIControlEventValueChanged];
            }
        };
    }
    
    //Move the thumb to the new position
    [self setThumbOn:on animated:animated completion:completionHandler];
    
    //Animate the contrast view of the track
    [self.track setOn:on animated:animated];
    
    _on = on;
}

- (void)setOn:(BOOL)on animated:(BOOL)animated
{
    [self setOn:on animated:animated notify:NO];
}

- (void) setOn:(BOOL)on
{
    [self setOn:on animated:NO notify:NO];
}

- (void) setLocked:(BOOL)locked
{
    //Cancel notification to parent if attempting to set to current state
    if (_locked == locked) {
        return;
    }
    _locked = locked;

    UIImageView *lockImageView = (UIImageView *)[_track viewWithTag:LOCK_IMAGE_SUBVIEW];
    
    if (!locked && (lockImageView != nil)) {
        
        [lockImageView removeFromSuperview];
        lockImageView = nil;
        
    } else if (locked && (lockImageView == nil)) {
        
        UIImage *lockImage = [UIImage imageNamed:@"lock-icon.png"];
        
        lockImageView = [[UIImageView alloc] initWithImage:lockImage];
        
        lockImageView.frame = CGRectMake(7, 8, lockImage.size.width, lockImage.size.height);
        lockImageView.tag = LOCK_IMAGE_SUBVIEW;
        
        [_track addSubview:lockImageView];
        [_track bringSubviewToFront:lockImageView];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event];
    [self sendActionsForControlEvents:UIControlEventTouchDown];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];
	[self sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesCancelled:touches withEvent:event];
	[self sendActionsForControlEvents:UIControlEventTouchUpOutside];
}

-(void) setThumbIsTracking:(BOOL)isTracking
{
    if (isTracking) {
        //Grow
        [self.thumb growThumbWithJustification: self.isOn ? KLSwitchThumbJustifyRight : KLSwitchThumbJustifyLeft];
    } else {
        //Shrink
        [self.thumb shrinkThumbWithJustification: self.isOn ? KLSwitchThumbJustifyRight : KLSwitchThumbJustifyLeft];
    }
    [self.thumb setIsTracking: isTracking];
}

-(void) setThumbIsTracking:(BOOL)isTracking animated:(BOOL) animated
{
    __weak id weakSelf = self;
    [UIView animateWithDuration: kDefaultAnimationScaleDuration
                          delay: fabs(kDefaultAnimationSlideDuration - kDefaultAnimationScaleDuration)
                        options: UIViewAnimationOptionCurveEaseOut
                     animations: ^{
                         [weakSelf setThumbIsTracking: isTracking];
                     }
                     completion:nil];
}

-(void) setThumbOn:(BOOL)on animated:(BOOL)animated completion:(KLSwitchChangeHandler)completionHandler
{
    if (animated) {
        __weak id weakSelf = self;
        [UIView animateWithDuration:kDefaultAnimationSlideDuration
                         animations:^{
                             [weakSelf setThumbOn:on animated:NO completion:nil];
                         }
                         completion:completionHandler];
    } else {
        CGRect thumbFrame = self.thumbFrame;
        if (on) {
            thumbFrame.origin.x = CGRectGetMaxX(self.trackFrame) - (thumbFrame.size.width + _thumbOffset);
        } else {
            thumbFrame.origin.x = _thumbOffset;
        }
        [self.thumb setFrame: thumbFrame];
        if (completionHandler) {
            completionHandler(YES);
        }
    }
}

@end

@implementation KLSwitchThumb

-(void) growThumbWithJustification:(KLSwitchThumbJustify) justification
{
    if (self.isTracking) return;

    CGRect thumbFrame = self.frame;
    
    thumbFrame.size.width = floor(self.normalSize.width * kThumbTrackingGrowthRatio);
    if (justification == KLSwitchThumbJustifyRight) {
        thumbFrame.origin.x = CGRectGetMaxX(self.trackBounds) - thumbFrame.size.width;
    } else {
        thumbFrame.origin.x = self.trackBounds.origin.x;
    }
    [self setFrame: thumbFrame];
}

-(void) shrinkThumbWithJustification:(KLSwitchThumbJustify) justification
{
    if (!self.isTracking) return;

    CGRect thumbFrame = self.frame;
    
    thumbFrame.size.width = self.normalSize.width;
    if (justification == KLSwitchThumbJustifyRight) {
        thumbFrame.origin.x = CGRectGetMaxX(self.trackBounds) - thumbFrame.size.width;
    } else {
        thumbFrame.origin.x = self.trackBounds.origin.x;
    }
    [self setFrame: thumbFrame];
}

@end

@interface KLSwitchTrack ()
@property (nonatomic, strong) UIView* contrastView;
@property (nonatomic, strong) UIView* onView;

@property (readonly) CGRect contrastRect;

@end

@implementation KLSwitchTrack

-(id) initWithFrame:(CGRect)frame
            onColor:(UIColor*) onColor
           offColor:(UIColor*) offColor
      contrastColor:(UIColor*) contrastColor
        thumbOffset:(CGFloat) thumbOffset
{
    self = [super initWithFrame: frame];
    if (self) {
        _onTintColor = onColor;
        _tintColor = offColor;
        _thumbOffset = thumbOffset;
        
        CGFloat cornerRadius = frame.size.height/2.0f;
        [self.layer setCornerRadius: cornerRadius];
        self.backgroundColor = _tintColor;
        self.clipsToBounds = YES;
        
        //Following lines needed to solve laggy scroll performance on older devices (such as iPod Touch 4th Gen)
        //when using KLSwitch in UITableViewCells.
        //Reason of laggy performance is setting cornerRadius property.
        self.layer.shouldRasterize = YES;
        self.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        self.layer.masksToBounds = NO;
        
        CGRect contrastRect = self.contrastRect;
        CGFloat contrastRadius = contrastRect.size.height/2.0f;
        _contrastView = [[UIView alloc] initWithFrame:contrastRect];
        [_contrastView setBackgroundColor: contrastColor];
        [_contrastView.layer setCornerRadius: contrastRadius];
        //Following lines needed to solve laggy scroll performance on older devices (such as iPod Touch 4th Gen)
        //when using KLSwitch in UITableViewCells.
        //Reason of laggy performance is setting cornerRadius property.
        _contrastView.layer.shouldRasterize = YES;
        _contrastView.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        _contrastView.layer.masksToBounds = NO;
        
        [self addSubview: _contrastView];

        _onView = [[UIView alloc] initWithFrame:frame];
        [_onView setBackgroundColor: _onTintColor];
        [_onView setCenter: self.center];
        [_onView.layer setCornerRadius: cornerRadius];
        //Following lines needed to solve laggy scroll performance on older devices (such as iPod Touch 4th Gen)
        //when using KLSwitch in UITableViewCells.
        //Reason of laggy performance is setting cornerRadius property.
        _onView.layer.shouldRasterize = YES;
        _onView.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        _onView.layer.masksToBounds = NO;
        
        [self addSubview: _onView];

    }
    return self;
}

-(CGRect)contrastRect
{
    CGRect contrastRect = self.bounds;
    contrastRect = CGRectMake(_thumbOffset, _thumbOffset, contrastRect.size.width - 2.0f*_thumbOffset, contrastRect.size.height - 2.0f*_thumbOffset);
    return contrastRect;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    self.contrastView.frame = self.contrastRect;
    self.onView.frame = self.bounds;
}

-(void) setOn:(BOOL)on
{
    _on = on;
    if (on) {
        [self.onView setAlpha: 1.0f];
        [self shrinkContrastView];
    } else {
        [self.onView setAlpha: 0.0f];
        [self growContrastView];
    }
    [self updateTintColor];
}

-(void) setOn:(BOOL)on animated:(BOOL)animated
{
    if (animated) {
        __weak id weakSelf = self;
            //First animate the color switch
        [UIView animateWithDuration: kDefaultAnimationContrastResizeDuration
                              delay: 0.0f
                            options: UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             [weakSelf setOn: on
                                animated: NO];
                         }
                         completion:nil];
    } else {
        [self setOn: on];
    }
}

-(void)updateTintColor
{
    if (_on) {
        self.backgroundColor = [UIColor clearColor];
    } else {
        self.backgroundColor = _tintColor;
    }
}

-(void) setOnTintColor:(UIColor *)onTintColor
{
    _onTintColor = onTintColor;
    [self.onView setBackgroundColor: _onTintColor];
}

-(void) setTintColor:(UIColor *)tintColor
{
    _tintColor = tintColor;
    [self updateTintColor];
}

-(void) setContrastColor:(UIColor *)contrastColor
{
    _contrastColor = contrastColor;
    [self.contrastView setBackgroundColor: _contrastColor];
}

-(void)setThumbOffset:(CGFloat)thumbOffset
{
    if (_thumbOffset != thumbOffset) {
        _thumbOffset = thumbOffset;
        [self setNeedsLayout];
    }
}

-(void) growContrastView
{
    //Start out with contrast view small and centered
    [self.contrastView setTransform: CGAffineTransformMakeScale(kSwitchTrackContrastViewShrinkFactor, kSwitchTrackContrastViewShrinkFactor)];
    [self.contrastView setTransform: CGAffineTransformMakeScale(1.0f, 1.0f)];
}

-(void) shrinkContrastView
{
    //Start out with contrast view the size of the track
    [self.contrastView setTransform: CGAffineTransformMakeScale(1.0f, 1.0f)];
    [self.contrastView setTransform: CGAffineTransformMakeScale(kSwitchTrackContrastViewShrinkFactor, kSwitchTrackContrastViewShrinkFactor)];
}

@end
