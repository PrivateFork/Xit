#import "XTTest.h"
#include "XTQueueUtils.h"
#import "Xit-Swift.h"

@implementation XTTest

- (void)setUp
{
  [super setUp];

  // /tmp is actually a link to /private/tmp, which APIs like
  // NSTemporaryDirectory and -[NSString stringByResolvingSymlinksInPath]
  // deliberately ignore, but -[NSFileManager enumeratorAtURL] doesn't.
  self.repoPath = [@"/private" stringByAppendingPathComponent:
      [NSString stringWithFormat:@"%@testrepo", NSTemporaryDirectory()]];
  self.repository = [self createRepo:self.repoPath];

  [self addInitialRepoContent];
}

- (void)tearDown
{
  [self waitForRepoQueue];

  NSFileManager *defaultManager = [NSFileManager defaultManager];
  NSError *error = nil;
  
  XCTAssertTrue([defaultManager removeItemAtPath:self.repoPath error:&error]);
  [defaultManager removeItemAtPath:self.remoteRepoPath error:&error];
  if ([defaultManager fileExistsAtPath:self.remoteRepoPath]) {
    XCTFail(@"tearDown %@ FAIL!!", self.remoteRepoPath);
  }

  [super tearDown];
}

- (NSString*)file1Name
{
  return @"file1.txt";
}

- (NSString*)file1Path
{
  return [self.repoPath stringByAppendingPathComponent:self.file1Name];
}

- (NSString*)addedName
{
  return @"added.txt";
}

- (NSString*)untrackedName
{
  return @"untracked.txt";
}

- (void)makeRemoteRepo
{
  NSString *parentPath = self.repoPath.stringByDeletingLastPathComponent;
  
  self.remoteRepoPath =
      [parentPath stringByAppendingPathComponent:@"remotetestrepo"];
  self.remoteRepository = [self createRepo:self.remoteRepoPath];
}

- (void)addInitialRepoContent
{
  XCTAssertTrue([self commitNewTextFile:self.file1Name content:@"some text"]);
}

- (void)makeStash
{
  NSError *error = nil;

  [self writeTextToFile1:@"stashy"];
  [self writeText:@"new" toFile:self.untrackedName];
  [self writeText:@"add" toFile:self.addedName];
  [self.repository stageFile:self.addedName error:&error];
  XCTAssertNil(error);
  [self.repository saveStash:@"" includeUntracked:YES error:&error];
}

- (BOOL)commitNewTextFile:(NSString *)name content:(NSString *)content
{
  return [self commitNewTextFile:name
                         content:content
                    inRepository:self.repository];
}

- (BOOL)commitNewTextFile:(NSString*)name
                  content:(NSString*)content
             inRepository:(XTRepository*)repo
{
  NSString *basePath = repo.repoURL.path;
  NSString *filePath = [basePath stringByAppendingPathComponent:name];

  [content writeToFile:filePath
            atomically:YES
              encoding:NSASCIIStringEncoding
                 error:nil];

  if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
    return NO;
  
  __block BOOL success = false;
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  
  [repo.queue executeOffMainThread:^{
    success = [repo stageFile:name error:NULL] &&
              [repo commitWithMessage:[NSString stringWithFormat:@"new %@", name]
                                  amend:NO
                            outputBlock:NULL
                                  error:NULL];
    dispatch_semaphore_signal(semaphore);
  }];
  dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
  
  return success;
}

- (XTRepository *)createRepo:(NSString *)repoName
{
  NSLog(@"[createRepo] repoName=%@", repoName);
  NSFileManager *fileManager = [NSFileManager defaultManager];

  if ([fileManager fileExistsAtPath:repoName]) {
    if (![fileManager removeItemAtPath:repoName error:nil]) {
      XCTFail(@"Couldn't make way for repository: %@", repoName);
      return nil;
    }
  }
  
  BOOL created = [fileManager createDirectoryAtPath:repoName
                        withIntermediateDirectories:YES
                                         attributes:nil
                                              error:nil];
  if (!created)
    return nil;


  NSURL *repoURL = [NSURL fileURLWithPath:repoName];

  XTRepository *repo = [[XTRepository alloc] initEmptyWithURL:repoURL];

  if (repo == nil) {
    XCTFail(@"initializeRepository '%@' FAIL!!", repoName);
  }

  if (![fileManager
          fileExistsAtPath:[NSString stringWithFormat:@"%@/.git", repoName]]) {
    XCTFail(@"%@/.git NOT Found!!", repoName);
  }

  return repo;
}

- (void)waitForRepoQueue
{
  [self waitForRepository: self.repository];
}

- (void)waitForRepository:(XTRepository*)repo
{
  [repo.queue wait];
  WaitForQueue(dispatch_get_main_queue());
}

- (BOOL)writeText:(NSString *)text toFile:(NSString *)path
{
  return [text writeToFile:[self.repoPath stringByAppendingPathComponent:path]
                atomically:YES
                  encoding:NSUTF8StringEncoding
                     error:nil];
}

- (BOOL)writeTextToFile1:(NSString *)text
{
  NSError *error;

  [text writeToFile:self.file1Path
         atomically:YES
           encoding:NSUTF8StringEncoding
              error:&error];
  return error == nil;
}

@end
