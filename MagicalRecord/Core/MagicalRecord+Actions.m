//
//  MagicalRecord+Actions.m
//
//  Created by Saul Mora on 2/24/11.
//  Copyright 2011 Magical Panda Software. All rights reserved.
//

#import "MagicalRecord+Actions.h"
#import "NSManagedObjectContext+MagicalRecord.h"
#import "NSManagedObjectContext+MagicalThreading.h"

@implementation MagicalRecord (Actions)

#pragma mark - Asynchronous saving

+ (void) saveWithBlock:(void(^)(NSManagedObjectContext *localContext))block;
{
    [self saveWithBlock:block completion:nil];
}

+ (void) saveWithBlock:(void(^)(NSManagedObjectContext *localContext))block completion:(MRSaveCompletionHandler)completion;
{
    NSManagedObjectContext *savingContext  = [NSManagedObjectContext MR_rootSavingContext];
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextWithParent:savingContext];

    [localContext performBlock:^{
        [localContext MR_setWorkingName:NSStringFromSelector(_cmd)];

        if (block) {
            block(localContext);
        }

        [localContext MR_saveWithOptions:MRSaveParentContexts completion:completion];
    }];
}

#pragma mark - Synchronous saving

+ (BOOL) saveWithBlockAndWait:(void(^)(NSManagedObjectContext *localContext))block;
{
    return [self saveWithBlockAndWait:block error:nil];
}

+ (BOOL) saveWithBlockAndWait:(void(^)(NSManagedObjectContext *localContext))block error:(NSError **)error;
{
    NSManagedObjectContext *savingContext  = [NSManagedObjectContext MR_rootSavingContext];
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextWithParent:savingContext];

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    __block BOOL contextDidSave;
    __block NSError *tmpError = nil;

    [localContext performBlockAndWait:^{
        [localContext MR_setWorkingName:NSStringFromSelector(_cmd)];

        if (block) {
            block(localContext);
        }

        [localContext MR_saveWithOptions:MRSaveParentContexts | MRSaveSynchronously completion:^(BOOL localContextDidSave, NSError *localError) {
            contextDidSave = localContextDidSave;
            tmpError = localError;
            dispatch_semaphore_signal(semaphore);
        }];
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (error != NULL) {
        *error = tmpError;
    }
    return contextDidSave;
}

@end

#pragma mark - Deprecated Methods — DO NOT USE
@implementation MagicalRecord (ActionsDeprecated)

+ (void) saveUsingCurrentThreadContextWithBlock:(void (^)(NSManagedObjectContext *localContext))block completion:(MRSaveCompletionHandler)completion;
{
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextForCurrentThread];

    [localContext performBlock:^{
        [localContext MR_setWorkingName:NSStringFromSelector(_cmd)];

        if (block) {
            block(localContext);
        }

        [localContext MR_saveWithOptions:MRSaveParentContexts completion:completion];
    }];
}

+ (void) saveUsingCurrentThreadContextWithBlockAndWait:(void (^)(NSManagedObjectContext *localContext))block;
{
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextForCurrentThread];

    [localContext performBlockAndWait:^{
        [localContext MR_setWorkingName:NSStringFromSelector(_cmd)];

        if (block) {
            block(localContext);
        }

        [localContext MR_saveWithOptions:MRSaveParentContexts|MRSaveSynchronously completion:nil];
    }];
}

+ (void) saveInBackgroundWithBlock:(void(^)(NSManagedObjectContext *localContext))block
{
    [[self class] saveWithBlock:block completion:nil];
}

+ (void) saveInBackgroundWithBlock:(void(^)(NSManagedObjectContext *localContext))block completion:(void(^)(void))completion
{
    NSManagedObjectContext *savingContext  = [NSManagedObjectContext MR_rootSavingContext];
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextWithParent:savingContext];

    [localContext performBlock:^{
        [localContext MR_setWorkingName:NSStringFromSelector(_cmd)];

        if (block)
        {
            block(localContext);
        }

        [localContext MR_saveToPersistentStoreAndWait];

        if (completion)
        {
            completion();
        }
    }];
}

+ (void) saveInBackgroundUsingCurrentContextWithBlock:(void (^)(NSManagedObjectContext *localContext))block completion:(void (^)(void))completion errorHandler:(void (^)(NSError *error))errorHandler;
{
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextForCurrentThread];

    [localContext performBlock:^{
        [localContext MR_setWorkingName:NSStringFromSelector(_cmd)];

        if (block) {
            block(localContext);
        }

        [localContext MR_saveToPersistentStoreWithCompletion:^(BOOL contextDidSave, NSError *error) {
            if (contextDidSave) {
                if (completion) {
                    completion();
                }
            }
            else {
                if (errorHandler) {
                    errorHandler(error);
                }
            }
        }];
    }];
}

@end
