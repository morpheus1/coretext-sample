/*
*  Copyright 2016 Adobe Systems Incorporated. All rights reserved.
*  This file is licensed to you under the Apache License, Version 2.0 (the "License");
*  you may not use this file except in compliance with the License. You may obtain a copy
*  of the License at http://www.apache.org/licenses/LICENSE-2.0
*
*  Unless required by applicable law or agreed to in writing, software distributed under
*  the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
*  OF ANY KIND, either express or implied. See the License for the specific language
*  governing permissions and limitations under the License.
*
*/


#import "AppDelegate.h"
#include <string>

CGFloat Delegate_getWidth(void* refCon) {
    return 100.0f;
}

CTRunDelegateRef createDelegateRef() {
    static CTRunDelegateCallbacks callbacks{
        kCTRunDelegateVersion1,
        NULL,
        NULL,
        NULL,  // getDescent
        &Delegate_getWidth
    };

    return CTRunDelegateCreate(&callbacks, nullptr);
}

CGFloat SpacingDelegate_getWidth(void* voidRef) {
    return 0.0f;
}

CTRunDelegateRef createSpacingDelegateRef() {
    static CTRunDelegateCallbacks callbacks{
        kCTRunDelegateVersion1,
        NULL,
        NULL,  // getAscent
        NULL,  // getDescent
        &SpacingDelegate_getWidth
    };

    return CTRunDelegateCreate(&callbacks, nullptr);
}

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    // Zero Width Space used to control the line break.
    const std::basic_string<char16_t> wordBoundary = u"\u200B";

    // Non breaking space
    const std::basic_string<char16_t> spacingText = u"\u00A0";

    // Delegated external text object
    const std::basic_string<char16_t> externalText = u"\uFFFC";

    std::basic_string<char16_t> externalObject = wordBoundary + spacingText + externalText + spacingText + wordBoundary;

    // Two adjacent externalObjects and sapcingText that marks end of text
    auto sampleText = externalObject + externalObject + spacingText;

    CFMutableAttributedStringRef attributedString;
    CTFramesetterRef framesetter;

    attributedString = CFAttributedStringCreateMutable(nil, 0);

    CFAttributedStringBeginEditing(attributedString);

    auto string = CFStringCreateWithBytes(nil,
        reinterpret_cast<const UInt8*>(sampleText.c_str()), sampleText.size() * sizeof(char16_t), kCFStringEncodingUTF16LE, true);

    // Make sure that we match the size of the UTF16.
    assert(CFStringGetLength(string) == sampleText.size());

    auto previousLength = CFAttributedStringGetLength(attributedString);
    CFAttributedStringReplaceString(attributedString, CFRangeMake(0, previousLength), string);

    for (int i = 0; i < sampleText.size(); i++) {
        if (sampleText[i] == externalText[0]) {
            auto cfRange = CFRangeMake(i, 1);
            auto delegateRef = createDelegateRef();
            CFAttributedStringSetAttribute(attributedString, cfRange, kCTRunDelegateAttributeName, delegateRef);
        } else if (sampleText[i] == spacingText[0]) {
            auto cfRange = CFRangeMake(i, 1);
            auto delegateRef = createSpacingDelegateRef();
            CFAttributedStringSetAttribute(attributedString, cfRange, kCTRunDelegateAttributeName, delegateRef);
        }
    }

    CFAttributedStringEndEditing(attributedString);

    framesetter = CTFramesetterCreateWithAttributedString(attributedString);

    CFRange fitRange = CFRangeMake(0, 0);
    CGSize maxConstraint = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);

    // It calculates the max size that the text might need.
    auto maxSizeRect = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0),
        nullptr, maxConstraint, &fitRange);

    auto constraintSize = CGSizeMake(maxSizeRect.width, CGFLOAT_MAX);
    // /**** This pathSize is what is unexpected when the issue is reproduced. It breaks it into two lines
    // even when the size is expected to be sufficient to fit the text content in a single line.
    // It is expected to fit in a single line because these constrains are calculated using `getContentMaxWidth`
    // which uses `CTFramesetterSuggestFrameSizeWithConstraints` with max constraints. *******/
    auto pathSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0),
        nullptr, constraintSize, &fitRange);


    NSLog(@"Constraints Size: %@", NSStringFromSize(constraintSize));
    NSLog(@"Computed Path Size: %@", NSStringFromSize(pathSize));

    // This assert is what is expected to be true, which is what we want to investigate.
    assert(constraintSize.width == pathSize.width);
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
