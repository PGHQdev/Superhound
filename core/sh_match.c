#include "sh_match.h"
#include <stdbool.h>
SHMatch sh_match(SHText text, SHText term) {
 if (!term.length || term.length > text.length) return (SHMatch){9,0};
 bool prefix=true;
 for(size_t j=0;j<term.length;j++) if(text.points[j]!=term.points[j]) {prefix=false;break;}
 if(prefix) return (SHMatch){text.length==term.length?0:1,text.length-term.length};
 size_t j=0,first=0,last=0;
 // A term that starts a later word ranks with word initials, above a match inside a word.
 for(size_t i=1;i<=text.length-term.length;i++) if(text.boundaries[i]) {
  for(j=0;j<term.length && text.points[i+j]==term.points[j];j++){}
  if(j==term.length) return (SHMatch){2,text.length-term.length};
 }
 j=0;
 for(size_t i=0;i<text.length && j<term.length;i++) {
  if(text.boundaries[i] && text.points[i]==term.points[j]) {if(!j)first=i;last=i;j++;}
 }
 if(j==term.length && term.length>1) return (SHMatch){2,last-first+1-term.length};
 for(size_t i=1;i<=text.length-term.length;i++) {
  for(j=0;j<term.length && text.points[i+j]==term.points[j];j++){}
  if(j==term.length) return (SHMatch){3,text.length-term.length};
 }
 return (SHMatch){9,0};
}
#define SH_TYPO_MAX 32
static unsigned min2(unsigned a,unsigned b){return a<b?a:b;}
SHMatch sh_match_typo(SHText text, SHText term) {
 size_t m=term.length;
 if(m<4 || m>SH_TYPO_MAX) return (SHMatch){9,0};
 unsigned allowed=m<8?1:2,best=allowed+1;
 for(size_t s=0;s<text.length;s++) {
  // A word must start with the first or second typed character; this rejects most words at once.
  if(!text.boundaries[s] || (text.points[s]!=term.points[0] && text.points[s]!=term.points[1])) continue;
  size_t n=text.length-s; if(n>m+allowed) n=m+allowed;
  if(n+allowed<m) continue;
  unsigned rows[3][SH_TYPO_MAX+3],*before=rows[0],*previous=rows[1],*current=rows[2];
  for(size_t j=0;j<=n;j++) previous[j]=(unsigned)j;
  bool alive=true;
  for(size_t i=1;i<=m && alive;i++) {
   current[0]=(unsigned)i; unsigned least=current[0];
   for(size_t j=1;j<=n;j++) {
    uint32_t a=term.points[i-1],b=text.points[s+j-1];
    unsigned v=min2(min2(previous[j],current[j-1])+1,previous[j-1]+(a!=b));
    if(i>1 && j>1 && a==text.points[s+j-2] && term.points[i-2]==b) v=min2(v,before[j-2]+1);
    current[j]=v; least=min2(least,v);
   }
   alive=least<=allowed;
   unsigned *swap=before; before=previous; previous=current; current=swap;
  }
  if(!alive) continue;
  for(size_t j=m>allowed?m-allowed:0;j<=n;j++) best=min2(best,previous[j]);
  if(best==1) break;
 }
 if(best>allowed) return (SHMatch){9,0};
 return (SHMatch){4+best,text.length>m?text.length-m:0};
}
