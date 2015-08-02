//
// Created by Kevin Wojniak on 9/5/08.
// Copyright 2008-2014 Kevin Wojniak. All rights reserved.
//

#import "BOTaskAdditions.h"

static int die(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);

static int die(NSString *format, ...) {
    va_list ap;
    va_start(ap, format);
    NSString *str = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    fprintf(stdout, "%s\n", str.UTF8String);
    exit(EXIT_FAILURE);
    return EXIT_FAILURE;
}

static int run() {
    if (geteuid() != 0) {
        return die(@"Must be run as root.");
    }
    
    NSMutableArray *argv = [[[NSProcessInfo processInfo] arguments] mutableCopy];
    if ([[argv objectAtIndex:1] isEqualToString:@"diskutil"]) {
        [argv removeObjectAtIndex:0]; // pop argv[0]
        [argv removeObjectAtIndex:0]; // pop argv[1]
        
        NSArray *white_list = @[@"info", @"mount", @"unmount"];
        if( ![white_list containsObject:[argv objectAtIndex:0]]){
            return die(@"Verb not allowed.");
        }

        NSString *output = nil;
        int status = [NSTask launchTaskAtPath:@"/usr/sbin/diskutil" arguments:argv output:&output];
        if (output) {
            output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        if (status != 0) {
            return die(@"Can't mount EFI partition.");
        }
        [[NSFileHandle fileHandleWithStandardOutput] writeData: [output dataUsingEncoding: NSNEXTSTEPStringEncoding]];
        /*
        if (launchTask(diskutil, @[@"info", @"-plist", diskID], &output) != 0) {
            BOLog(@"%s: can't get info for %@: %@", __FUNCTION__, diskID, output);
            return die(@"Can't mount EFI partition.");;
        }
         */
        return EXIT_SUCCESS;
    }
    else if (argv.count % 2 != 1) {
        for( NSProcessInfo *a in argv ) {
            NSLog( @"Args = %@", a);
        }
        return die( @"Invalid number of arguments. %lu",  argv.count);
    }
    [argv removeObjectAtIndex:0]; // pop argv[0]
    NSString *mode = nil;
    NSString *media = nil;
    NSString *legacy = nil;
    NSString *nextonly = nil;
    while (argv.count > 0) {
        NSString *option = [argv objectAtIndex:0];
        NSString *value = [argv objectAtIndex:1];
        if ([option hasPrefix:@"-"]) {
            option = [option substringFromIndex:1];
        }
        if ([option isEqualToString:@"mode"]) {
            mode = value;
        } else if ([option isEqualToString:@"media"]) {
            media = value;
        } else if ([option isEqualToString:@"legacy"]) {
            legacy = value;
        } else if ([option isEqualToString:@"nextonly"]) {
            nextonly = value;
        } else {
            die(@"Invalid arg %@", option);
        }
        [argv removeObjectAtIndex:0];
        [argv removeObjectAtIndex:0];
    }
    if (!mode || (![mode isEqualToString:@"device"] && ![mode isEqualToString:@"mount"])) {
        return die(@"Missing or invalid mode arg.");
    }
    if (!media) {
        return die(@"Missing media arg.");
    }
    if (legacy && (![legacy isEqualToString:@"yes"] && ![legacy isEqualToString:@"no"])) {
        return die(@"Invalid nextonly arg.");
    }
    
    NSMutableArray *taskArgs = [NSMutableArray array];
    if ([mode isEqualToString:@"device"]) {
        [taskArgs addObject:@"--device"];
    } else {
        [taskArgs addObject:@"--mount"];
    }
    [taskArgs addObject:media];
    if ([legacy isEqualToString:@"yes"]) {
        [taskArgs addObject:@"--legacy"];
    }
    [taskArgs addObject:@"--setBoot"];
    if ([nextonly isEqualToString:@"yes"]) {
        [taskArgs addObject:@"--nextonly"];
    }
    [taskArgs addObject:@"--verbose"];
    
    NSString *output = nil;
    int status = [NSTask launchTaskAtPath:@"/usr/sbin/bless" arguments:taskArgs output:&output];
    if (output) {
        output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (status != 0) {
        return die(@"%@", [@"Bless failed:\n\n" stringByAppendingString:output]);
    }
    
    return EXIT_SUCCESS;
}

int main() {
    @autoreleasepool {
        return run();
    }
}
