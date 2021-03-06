//
//  CQWrapper.m
//  Coq4iPad
//
//  Created by Keigo IMAI on 2/4/13.
//  Copyright (c) 2013 Keigo IMAI. All rights reserved.
//

#import "CQWrapper.h"

#import "CQUtil.h"
#import "CQ_convert.h"

static dispatch_queue_t camlQueue;
static id<CQWrapperDelegate> delegate;
static BOOL ready = NO;


@implementation CQWrapper

+(void)initialize
{
    camlQueue = dispatch_queue_create("jp.keigoimai.Coq4iPad", NULL);
}

+(void) setDelegate:(id<CQWrapperDelegate>)delegate_
{
    delegate = delegate_;
}

+(BOOL) isReady
{
    return ready;
}

// wrap async call with [delegate enterBusy] and [delegate exitBusy]
static void caml_dispatch(dispatch_block_t block)
{
    dispatch_async(camlQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if(delegate) {
                [delegate enterBusy];
            }
        });
        block();
        dispatch_async(dispatch_get_main_queue(), ^{
            if(delegate) {
                [delegate exitBusy];
            }
        });
    });
}

+(void) startRuntime
{
    caml_dispatch(^{
        NSLog(@"startRuntime");
        const char* argv[] = {
            "coqlib",
            0
        };
        caml_main((char**)argv);
        NSLog(@"startRuntime done");
    });
}

+(void) startCoq:(NSString*)coqroot callback:(void(^)(BOOL))callback
{
    caml_dispatch(^{
        CAMLparam0();
        CAMLlocal1(res);
        NSLog(@"startCoq:%@", coqroot);
        const char* path = [coqroot cStringUsingEncoding:NSASCIIStringEncoding];
        res = caml_callback(*caml_named_value("start"), caml_copy_string(path));
        ready = YES;

        BOOL result = Bool_val(res);
        dispatch_async(dispatch_get_main_queue(), ^{callback(result);});
        NSLog(@"startCoq done");
        
        [self resetInitial:^(){}];
        CAMLreturn0;
    });
}

+(void) compile:(NSString*)file callback:(void(^)())callback
{
    caml_dispatch(^{
        CAMLparam0();
        NSLog(@"compile: %@", file);
        caml_callback(*caml_named_value("compile"), caml_copy_string([file UTF8String]));
        dispatch_async(dispatch_get_main_queue(), callback);
        CAMLreturn0;
    });
}

static NSArray* camlArray(value v) {
    NSMutableArray* arr = [NSMutableArray array];
    int len = caml_array_length(v);
    for(int i=0; i<len; i++) {
        [arr addObject:[NSString stringWithUTF8String:String_val(Field(v, i))]];
    }
    return arr;
}

static id in_caml(id(^fun)(void)) {
    int registered = caml_c_thread_register();
    @try {
        caml_acquire_runtime_system();
        return fun();
    } @finally {
        caml_release_runtime_system();
        if(registered) {
            caml_c_thread_unregister();
        }
    }
}

+(void) parse:(const char*)str match:(void (^)(int, NSRange))match
{
    // FIXME put here CAMLparam0(), CAMLreturn0, etc.
    NSLog(@"parse:%s", str);
    caml_callback2(*caml_named_value("parse"), caml_copy_string(str), Val_ObjC_retain(match));
}

+(void) eval:(NSString*)str callback:(void(^)(BOOL, NSString*))callback
{    
    caml_dispatch(^{
        CAMLparam0();
        CAMLlocal1(result_);
        NSLog(@"eval:%@", str);
        const char* strln = [[str stringByAppendingString:@"\n"] UTF8String];
        result_ = caml_callback(*caml_named_value("eval"), caml_copy_string(strln));
        BOOL success = Int_val(Field(result_,0));
        NSString* msg = [NSString stringWithUTF8String:String_val(Field(result_, 1))];
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(success, msg);
        });
        NSLog(@"eval done");
        CAMLreturn0;
    });
}

+(NSRange) nextPhraseRange:(NSString*)text
{
    NSArray* retval = in_caml(^(){
        CAMLparam0();
        CAMLlocal1(retval_);
        __block const char* text_ = [text UTF8String];
       
        retval_ = caml_callback(*caml_named_value("next_phranse_range"), caml_copy_string(text_));
        int start = Int_val(Field(retval_, 0)),
            end = Int_val(Field(retval_, 1));
        
        id retval = [NSArray arrayWithObjects:@(start), @(end-start), nil];
        CAMLreturnT(id, retval);
    });
    
    NSRange range = {.location=[retval[0] intValue], .length=[retval[1] intValue]};
    return range;
}

+(void) runInQueue:(void(^)())callback
{
    caml_dispatch(^{
        dispatch_async(dispatch_get_main_queue(), callback);
    });
}

+(void) rewind:(void(^)(int extra))callback
{
    caml_dispatch(^{
        CAMLparam0();
        CAMLlocal1(ret_);
        ret_ = caml_callback(*caml_named_value("rewind"), Val_int(1));
        int ret = Int_val(ret_);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(ret);
        });
        CAMLreturn0;
    });
}

+(void) resetInitial:(void(^)())callback
{
    caml_dispatch(^{
        CAMLparam0();
        caml_callback(*caml_named_value("reset_initial"), Val_unit);
        dispatch_async(dispatch_get_main_queue(), callback);
        CAMLreturn0;
    });
}


@end
