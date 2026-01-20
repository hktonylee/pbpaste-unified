/*
 * pbpaste_unified
 */

#import "pbpaste_unified.h"

void
usage ()
{
    fprintf(stderr,
        "Usage: %s [OPTIONS]\n"
        "\t--Prefer {txt|rtf|ps|png|jpeg|jpg}\t" "Prefer pasteboard type" "\n"
        "\t-- -Prefer {txt|rtf|ps|png|jpeg|jpg}\t" "Prefer pasteboard type" "\n"
        "\t\t\t\t" "If clipboard contains text, paste text directly" "\n"
        "\t-v\t" "Version" "\n"
        "\t-h,-?\t" "This usage" "\n",
        APP_NAME);
}

void
fatal (const char *msg)
{
    if (msg != NULL) {
        fprintf(stderr, "%s: %s\n", APP_NAME, msg);
    }
}

void
version ()
{
    fprintf(stderr, "%s %s\n", APP_NAME, APP_VERSION);
}

ImageType
extractImageType (NSImage *image)
{
    ImageType imageType = ImageTypeNone;
    if (image != nil) {
        NSArray *reps = [image representations];
        NSImageRep *rep = [reps lastObject];
        if ([rep isKindOfClass:[NSPDFImageRep class]]) {
            imageType = ImageTypePDF;
        } else if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
            imageType = ImageTypeBitmap;
        }
    }
    return imageType;
}

NSData *
renderImageData (NSImage *image, NSBitmapImageFileType bitmapImageFileType)
{
    ImageType imageType = extractImageType(image);
    switch (imageType) {
    case ImageTypeBitmap:
        return renderFromBitmap(image, bitmapImageFileType);
        break;
    case ImageTypePDF:
        return renderFromPDF(image, bitmapImageFileType);
        break;
    case ImageTypeNone:
    default:
        return nil;
        break;
    }
}

NSData *
renderFromBitmap (NSImage *image, NSBitmapImageFileType bitmapImageFileType)
{
    return [NSBitmapImageRep representationOfImageRepsInArray:[image representations]
                                                    usingType:bitmapImageFileType
                                                   properties:@{}];
}

NSData *
renderFromPDF (NSImage *image, NSBitmapImageFileType bitmapImageFileType)
{
    NSPDFImageRep *pdfImageRep =
        (NSPDFImageRep *)[[image representations] lastObject];
    CGFloat factor = PDF_SCALE_FACTOR;
    NSRect bounds = NSMakeRect(
        0, 0,
        pdfImageRep.bounds.size.width * factor,
        pdfImageRep.bounds.size.height * factor);

    NSImage *genImage = [[NSImage alloc] initWithSize:bounds.size];
    [genImage lockFocus];
    [[NSColor whiteColor] set];
    NSRectFill(bounds);
    [pdfImageRep drawInRect:bounds];
    [genImage unlockFocus];

    NSData *genImageData = [genImage TIFFRepresentation];
    return [[NSBitmapImageRep imageRepWithData:genImageData]
                       representationUsingType:bitmapImageFileType
                                    properties:@{}];
}

/*
 * Returns NSBitmapImageFileType based off of filename extension
 */
NSBitmapImageFileType
getBitmapImageFileTypeFromFilename (NSString *filename)
{
    static NSDictionary *lookup;
    if (lookup == nil) {
        lookup = @{
            @"gif": [NSNumber numberWithInt:NSBitmapImageFileTypeGIF],
            @"jpeg": [NSNumber numberWithInt:NSBitmapImageFileTypeJPEG],
            @"jpg": [NSNumber numberWithInt:NSBitmapImageFileTypeJPEG],
            @"png": [NSNumber numberWithInt:NSBitmapImageFileTypePNG],
            @"tif": [NSNumber numberWithInt:NSBitmapImageFileTypeTIFF],
            @"tiff": [NSNumber numberWithInt:NSBitmapImageFileTypeTIFF],
        };
    }
    NSBitmapImageFileType bitmapImageFileType = NSBitmapImageFileTypePNG;
    if (filename != nil) {
        NSArray *words = [filename componentsSeparatedByString:@"."];
        NSUInteger len = [words count];
        if (len > 1) {
            NSString *extension = (NSString *)[words objectAtIndex:(len - 1)];
            NSString *lowercaseExtension = [extension lowercaseString];
            NSNumber *value = lookup[lowercaseExtension];
            if (value != nil) {
                bitmapImageFileType = [value unsignedIntegerValue];
            }
        }
    }
    return bitmapImageFileType;
}

/*
 * Returns NSData from Pasteboard Image if available; otherwise nil
 */
NSData *
getPasteboardImageData (NSBitmapImageFileType bitmapImageFileType)
{
    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    NSImage *image = [[NSImage alloc] initWithPasteboard:pasteBoard];
    NSData *imageData = nil;

    if (image != nil) {
        imageData = renderImageData(image, bitmapImageFileType);
    }

    [image release];
    return imageData;
}

NSData *
getPasteboardTextData (OutputPreference preference)
{
    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    NSData *textData = nil;

    switch (preference) {
    case OutputPreferenceRTF:
        textData = [pasteBoard dataForType:NSPasteboardTypeRTF];
        break;
    case OutputPreferencePostScript:
        textData = [pasteBoard dataForType:NSPasteboardTypePostScript];
        break;
    case OutputPreferenceText:
    case OutputPreferencePNG:
    case OutputPreferenceJPEG:
    case OutputPreferenceNone:
    default: {
        NSString *text = [pasteBoard stringForType:NSPasteboardTypeString];
        if (text != nil) {
            textData = [text dataUsingEncoding:NSUTF8StringEncoding];
        }
        break;
    }
    }

    return textData;
}

Parameters
parseArguments (int argc, char* const argv[])
{
    Parameters params;

    params.outputFile = nil;
    params.wantsVersion = NO;
    params.wantsUsage = NO;
    params.outputPreference = OutputPreferenceNone;
    params.malformed = NO;

    int ch;
    while ((ch = getopt(argc, argv, "vh?")) != -1) {
        switch (ch) {
        case 'v':
            params.wantsVersion = YES;
            return params;
            break;
        case 'h':
        case '?':
            params.wantsUsage = YES;
            return params;
            break;
        default:
            params.malformed = YES;
            return params;
            break;
        }
    }

    int index = optind;
    const char *preferValue = NULL;
    if (index < argc && !strcmp(argv[index], "--")) {
        if (index + 2 >= argc || strcmp(argv[index + 1], "-Prefer") != 0) {
            params.malformed = YES;
            return params;
        }
        preferValue = argv[index + 2];
        index += 3;
    } else if (index < argc && (!strcmp(argv[index], "--Prefer")
                               || !strcmp(argv[index], "-Prefer"))) {
        if (index + 1 >= argc) {
            params.malformed = YES;
            return params;
        }
        preferValue = argv[index + 1];
        index += 2;
    }

    if (preferValue != NULL) {
        if (!strcmp(preferValue, "txt")) {
            params.outputPreference = OutputPreferenceText;
        } else if (!strcmp(preferValue, "rtf")) {
            params.outputPreference = OutputPreferenceRTF;
        } else if (!strcmp(preferValue, "ps")) {
            params.outputPreference = OutputPreferencePostScript;
        } else if (!strcmp(preferValue, "png")) {
            params.outputPreference = OutputPreferencePNG;
        } else if (!strcmp(preferValue, "jpeg")
                   || !strcmp(preferValue, "jpg")) {
            params.outputPreference = OutputPreferenceJPEG;
        } else {
            params.malformed = YES;
            return params;
        }
    }

    if (index + 1 < argc) {
        params.malformed = YES;
    } else {
        if (index < argc) {
            params.outputFile =
                [[NSString alloc] initWithCString:argv[index]
                                         encoding:NSUTF8StringEncoding];
        }
    }
    return params;
}

int
main (int argc, char * const argv[])
{
    Parameters params = parseArguments(argc, argv);
    if (params.malformed) {
        usage();
        return EXIT_FAILURE;
    } else if (params.wantsUsage) {
        usage();
        return EXIT_SUCCESS;
    } else if (params.wantsVersion) {
        version();
        return EXIT_SUCCESS;
    }

    NSBitmapImageFileType bitmapImageFileType;
    if (params.outputPreference == OutputPreferenceJPEG) {
        bitmapImageFileType = NSBitmapImageFileTypeJPEG;
    } else if (params.outputPreference == OutputPreferencePNG) {
        bitmapImageFileType = NSBitmapImageFileTypePNG;
    } else {
        bitmapImageFileType = getBitmapImageFileTypeFromFilename(params.outputFile);
    }
    NSData *imageData = getPasteboardImageData(bitmapImageFileType);
    NSData *textData = nil;
    int exitCode;
    NSFileHandle *stdoutHandle = nil;

    if (imageData != nil) {
        if (params.outputFile == nil) {
            if (stdoutHandle == nil) {
                stdoutHandle =
                    (NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput];
            }
            [stdoutHandle writeData:imageData];
            exitCode = EXIT_SUCCESS;
        } else {
            if ([imageData writeToFile:params.outputFile atomically:YES]) {
                exitCode = EXIT_SUCCESS;
            } else {
                fatal("Could not write to file!");
                exitCode = EXIT_FAILURE;
            }
        }
    } else {
        textData = getPasteboardTextData(params.outputPreference);
        if (textData != nil) {
            if (params.outputFile == nil) {
                if (stdoutHandle == nil) {
                    stdoutHandle =
                        (NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput];
                }
                [stdoutHandle writeData:textData];
                exitCode = EXIT_SUCCESS;
            } else {
                NSError *error = nil;
                if ([textData writeToFile:params.outputFile
                                  options:NSDataWritingAtomic
                                    error:&error]) {
                    exitCode = EXIT_SUCCESS;
                } else {
                    fatal("Could not write text to file!");
                    exitCode = EXIT_FAILURE;
                }
            }
        } else {
            fatal("No image or text data found on the clipboard!");
            exitCode = EXIT_FAILURE;
        }
    }

    return exitCode;
}
