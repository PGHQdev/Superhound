#include "sh_match.h"
#include <stdbool.h>
SHMatch sh_match(SHText text, SHText term) {
 if (!term.length || term.length > text.length) return (SHMatch){9,0};
 bool prefix=true;
 for(size_t j=0;j<term.length;j++) if(text.points[j]!=term.points[j]) {prefix=false;break;}
 if(prefix) return (SHMatch){text.length==term.length?0:1,text.length-term.length};
 size_t j=0,first=0,last=0;
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
