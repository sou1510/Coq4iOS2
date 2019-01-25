//
//  CoqUtil.m
//  Coq4iOS
//
//  Created by 後藤宗一朗 on 2018/11/05.
//  Copyright © 2018年 後藤宗一朗. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CoqUtil.h"
#import "LZMASDK/LZMAExtractor.h"
#include <libgen.h> // dirname

#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/config.h>
#include <caml/misc.h>
#include <caml/mlvalues.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/callback.h>
#include <caml/threads.h>

static dispatch_queue_t camlQueue;


static NSString* coqRoot() {
    NSFileManager* sharedFM = [NSFileManager defaultManager];
    NSArray* possibleURLs = [sharedFM URLsForDirectory:NSCachesDirectory
                                             inDomains:NSUserDomainMask];
    if ([possibleURLs count] < 1) {
        @throw @"no cache directory found";
    }
    
    NSURL* cachesUrl = [possibleURLs objectAtIndex:0];
    NSString* appBundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    NSString* dir = [[cachesUrl URLByAppendingPathComponent:appBundleID] path];
    
    return [dir stringByAppendingPathComponent:@"coq-8.8.2"];
}

static void startCoqBody() {
    dispatch_async(camlQueue, ^{
        CAMLparam0();
        CAMLlocal1(res);
        NSString* coqroot = coqRoot();
        const char* path = [coqroot cStringUsingEncoding:NSASCIIStringEncoding];
        
        value* startFunc = caml_named_value("start");
        res = caml_callback(*startFunc, caml_copy_string(path));
        
        //BOOL result = Bool_val(res);
        CAMLreturn0;
    });
}

void startCoq() {
    camlQueue = dispatch_queue_create("jp.sou.Coq4iPad", NULL);
    
    dispatch_async(camlQueue, ^{
        NSLog(@"startRuntime");
        const char* argv[] = {
            "coqlib",
            0
        };
        caml_main((char**)argv);
        NSLog(@"startRuntime done");
    });
    
    dispatch_async(camlQueue, ^{
        NSString* archivePath =
            [[NSBundle mainBundle]
             pathForResource:@"coq-8.8.2-standard-libs-for-coq4ios.7z"
             ofType:nil
             inDirectory:@"."];
        
        NSString* coqRootPath = coqRoot();
        
        
        [LZMAExtractor
            extract7zArchive:archivePath
            dirName:coqRootPath
            preserveDir:TRUE];

    });

    startCoqBody();
}

void readStdout(void (^cb)(NSString*)) {
    dispatch_async(camlQueue, ^{
        CAMLparam0();
        CAMLlocal1(res);
        
        value* func = caml_named_value("read_stdout");
        res = caml_callback(*func, Val_unit);
        
        const char* cmsg = String_val(res);
        NSString* msg = [NSString stringWithUTF8String:cmsg];
        cb(msg);
        CAMLreturn0;
    });
}

void eval(NSString* str, void (^cb)(BOOL, NSString*)) {
    dispatch_async(camlQueue, ^{
        CAMLparam0();
        CAMLlocal1(result_);
        NSLog(@"eval:%@", str);
        const char* strln = [[str stringByAppendingString:@"\n"] UTF8String];
        result_ = caml_callback(*caml_named_value("eval"), caml_copy_string(strln));
        BOOL success = Int_val(Field(result_,0));
        NSString* msg = [NSString stringWithUTF8String:String_val(Field(result_, 1))];
        dispatch_async(dispatch_get_main_queue(), ^{
            cb(success, msg);
        });
        NSLog(@"eval done");
        CAMLreturn0;
    });
}