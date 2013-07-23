typedef enum {
  XTRefTypeBranch,
  XTRefTypeActiveBranch,
  XTRefTypeRemoteBranch,
  XTRefTypeTag,
  XTRefTypeRemote,
  XTRefTypeUnknown
} XTRefType;

typedef enum {
  XTBranchesGroupIndex,
  XTRemotesGroupIndex,
  XTTagsGroupIndex,
  XTStashesGroupIndex
} XTSideBarRootItems;

typedef enum {
  XTErrorWriteLock = 1
} XTError;

extern NSString *XTErrorDomainXit, *XTErrorDomainGit;
