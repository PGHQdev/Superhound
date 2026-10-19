#import "SHCatalog.h"
#import <sqlite3.h>
@implementation SHCatalog {sqlite3 *_db;}
- (NSError *)failure {return [NSError errorWithDomain:@"SuperhoundCatalog" code:sqlite3_errcode(_db) userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(_db))}];}
- (BOOL)sql:(const char *)sql {return sqlite3_exec(_db,sql,NULL,NULL,NULL)==SQLITE_OK;}
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error {
 if(!(self=[super init]))return nil;
 BOOL existed=[NSFileManager.defaultManager fileExistsAtPath:url.path];
 if(sqlite3_open(url.fileSystemRepresentation,&_db)!=SQLITE_OK){if(error)*error=[self failure];return nil;}
 sqlite3_busy_timeout(_db,2000);
 sqlite3_stmt *s=NULL;int version=-1;BOOL healthy=NO;
 if(sqlite3_prepare_v2(_db,"PRAGMA user_version",-1,&s,NULL)==SQLITE_OK && sqlite3_step(s)==SQLITE_ROW)version=sqlite3_column_int(s,0);sqlite3_finalize(s);s=NULL;
 if(sqlite3_prepare_v2(_db,"PRAGMA quick_check",-1,&s,NULL)==SQLITE_OK && sqlite3_step(s)==SQLITE_ROW)healthy=strcmp((const char *)sqlite3_column_text(s,0),"ok")==0;sqlite3_finalize(s);
 if(existed && (!healthy || version!=1)) {
  sqlite3_close(_db);_db=NULL;
  NSURL *saved=[NSURL fileURLWithPath:[url.path stringByAppendingFormat:@".diagnostic-%@",NSUUID.UUID.UUIDString]];
  if(![NSFileManager.defaultManager moveItemAtURL:url toURL:saved error:error])return nil;
  // DELETE journal mode is used; preserve any crash journal with its diagnostic database.
  NSString *journal=[url.path stringByAppendingString:@"-journal"];
  if([NSFileManager.defaultManager fileExistsAtPath:journal])
   [NSFileManager.defaultManager moveItemAtPath:journal toPath:[saved.path stringByAppendingString:@"-journal"] error:nil];
  if(sqlite3_open(url.fileSystemRepresentation,&_db)!=SQLITE_OK){if(error)*error=[self failure];return nil;}_rebuilt=YES;
 }
 if(![self sql:"PRAGMA journal_mode=DELETE; PRAGMA synchronous=FULL; CREATE TABLE IF NOT EXISTS roots (id TEXT PRIMARY KEY,last_scan REAL,state TEXT); CREATE TABLE IF NOT EXISTS entries (id INTEGER PRIMARY KEY AUTOINCREMENT,root TEXT NOT NULL,relative TEXT NOT NULL,name TEXT NOT NULL,path TEXT NOT NULL,type TEXT NOT NULL,alias TEXT NOT NULL,UNIQUE(root,relative)); PRAGMA user_version=1;"]){if(error)*error=[self failure];return nil;}
 return self;
}
- (void)dealloc {if(_db)sqlite3_close(_db);}
static void Bind(sqlite3_stmt *s,int col,NSString *v){sqlite3_bind_text(s,col,v.UTF8String,-1,SQLITE_TRANSIENT);}
// Rows go straight into entries; a temporary staging table kept its pages, 11 MB for 43,000 rows, until the connection closed.
// The relative paths of one write as a JSON array for json_each, or nil when one is missing or repeated.
static NSData *Relatives(NSArray<NSDictionary *> *entries){
 NSMutableArray *list=[NSMutableArray arrayWithCapacity:entries.count];for(NSDictionary *e in entries){if(![e[@"relative"] isKindOfClass:NSString.class])return nil;[list addObject:e[@"relative"]];}
 return [NSSet setWithArray:list].count==list.count?[NSJSONSerialization dataWithJSONObject:list options:0 error:nil]:nil;
}
static NSError *Rejected(void){return [NSError errorWithDomain:@"SuperhoundCatalog" code:SQLITE_CONSTRAINT userInfo:@{NSLocalizedDescriptionKey:@"An entry has a missing or repeated relative path."}];}
// Identical rows are left alone so an unchanged row counts as no change.
static const char *Upsert="INSERT INTO entries(root,relative,name,path,type,alias) VALUES (?,?,?,?,?,?) ON CONFLICT(root,relative) DO UPDATE SET name=excluded.name,path=excluded.path,type=excluded.type,alias=excluded.alias WHERE name IS NOT excluded.name OR path IS NOT excluded.path OR type IS NOT excluded.type OR alias IS NOT excluded.alias";
// Inserts or updates each row; changed adds the rows that differ.
- (BOOL)upsert:(NSArray<NSDictionary *> *)entries root:(NSString *)root sql:(const char *)sql changed:(NSUInteger *)changed {
 sqlite3_stmt *s=NULL;BOOL ok=sqlite3_prepare_v2(_db,sql,-1,&s,NULL)==SQLITE_OK;
 for(NSDictionary *e in entries){if(!ok)break;sqlite3_reset(s);sqlite3_clear_bindings(s);Bind(s,1,root);Bind(s,2,e[@"relative"]);Bind(s,3,e[@"name"]);Bind(s,4,e[@"path"]);Bind(s,5,e[@"type"]);Bind(s,6,e[@"alias"]?:@"");ok=sqlite3_step(s)==SQLITE_DONE;if(changed)*changed+=(NSUInteger)sqlite3_changes(_db);}
 sqlite3_finalize(s);return ok;
}
- (BOOL)replaceRoot:(NSString *)root entries:(NSArray<NSDictionary *> *)entries changed:(NSUInteger *)changed error:(NSError **)error {
 if(changed)*changed=0;NSData *relatives=Relatives(entries);if(!relatives){if(error)*error=Rejected();return NO;}
 if(![self sql:"BEGIN IMMEDIATE"]){if(error)*error=[self failure];return NO;}
 NSUInteger total=0;BOOL ok=[self upsert:entries root:root sql:Upsert changed:&total];sqlite3_stmt *s=NULL;
 if(ok){ok=sqlite3_prepare_v2(_db,"DELETE FROM entries WHERE root=? AND relative NOT IN (SELECT value FROM json_each(?))",-1,&s,NULL)==SQLITE_OK;if(ok){Bind(s,1,root);sqlite3_bind_text(s,2,relatives.bytes,(int)relatives.length,SQLITE_STATIC);ok=sqlite3_step(s)==SQLITE_DONE;total+=sqlite3_changes(_db);}sqlite3_finalize(s);s=NULL;}
 if(ok){ok=sqlite3_prepare_v2(_db,"INSERT INTO roots VALUES (?,strftime('%s','now'),'ready') ON CONFLICT(id) DO UPDATE SET last_scan=excluded.last_scan,state='ready'",-1,&s,NULL)==SQLITE_OK;if(ok){Bind(s,1,root);ok=sqlite3_step(s)==SQLITE_DONE;}sqlite3_finalize(s);}
 if(ok)ok=[self sql:"COMMIT"];
 if(!ok){if(error)*error=[self failure];[self sql:"ROLLBACK"];}
 if(changed)*changed=ok?total:0;
 return ok;
}
- (BOOL)updateRoot:(NSString *)root directories:(NSArray<NSDictionary *> *)directories changed:(NSUInteger *)changed error:(NSError **)error {
 NSUInteger total=0;NSMutableArray *relatives=NSMutableArray.array;
 for(NSDictionary *d in directories){NSData *list=Relatives(d[@"entries"]);if(!list){if(error)*error=Rejected();if(changed)*changed=0;return NO;}[relatives addObject:list];}
 if(![self sql:"BEGIN IMMEDIATE"]){if(error)*error=[self failure];if(changed)*changed=0;return NO;}
 BOOL ok=YES;
 for(NSUInteger i=0;i<directories.count && ok;i++){NSDictionary *d=directories[i];
  ok=[self upsert:d[@"entries"] root:root sql:Upsert changed:&total];
  NSString *prefix=[d[@"relative"] length]?[d[@"relative"] stringByAppendingString:@"/"]:@"";sqlite3_stmt *s=NULL;
  if(ok){ok=sqlite3_prepare_v2(_db,"DELETE FROM entries WHERE root=?1 AND substr(relative,1,length(?2))=?2 AND (?3 OR instr(substr(relative,length(?2)+1),'/')=0) AND relative NOT IN (SELECT value FROM json_each(?4))",-1,&s,NULL)==SQLITE_OK;if(ok){Bind(s,1,root);Bind(s,2,prefix);sqlite3_bind_int(s,3,[d[@"deep"] boolValue]);sqlite3_bind_text(s,4,[relatives[i] bytes],(int)[relatives[i] length],SQLITE_STATIC);ok=sqlite3_step(s)==SQLITE_DONE;total+=sqlite3_changes(_db);}sqlite3_finalize(s);}
 }
 if(ok)ok=[self sql:"COMMIT"];
 if(!ok){if(error)*error=[self failure];[self sql:"ROLLBACK"];}
 if(changed)*changed=ok?total:0;
 return ok;
}
- (NSArray<NSDictionary *> *)entriesForRoot:(NSString *)root {
 sqlite3_stmt *s=NULL;NSMutableArray *rows=NSMutableArray.array;
 if(sqlite3_prepare_v2(_db,"SELECT id,relative,name,path,type,alias FROM entries WHERE root=? ORDER BY id",-1,&s,NULL)==SQLITE_OK){Bind(s,1,root);while(sqlite3_step(s)==SQLITE_ROW){NSMutableDictionary *r=[@{@"id":@(sqlite3_column_int64(s,0)),@"root":root} mutableCopy];NSArray *keys=@[@"relative",@"name",@"path",@"type",@"alias"];for(int i=0;i<5;i++){const char *p=(const char *)sqlite3_column_text(s,i+1);r[keys[i]]=p?@(p):@"";}[rows addObject:r];}}sqlite3_finalize(s);return rows;
}
- (void)removeRoot:(NSString *)root {
 for(NSString *sql in @[@"DELETE FROM entries WHERE root=?",@"DELETE FROM roots WHERE id=?"]){sqlite3_stmt *s=NULL;if(sqlite3_prepare_v2(_db,sql.UTF8String,-1,&s,NULL)==SQLITE_OK){Bind(s,1,root);sqlite3_step(s);}sqlite3_finalize(s);}
}
@end
